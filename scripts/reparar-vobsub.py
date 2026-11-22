#!/usr/bin/env python3
"""
Repara subtitulos VobSub (dvd_subtitle) que declaran un tamano invalido (0x0)
y hacen que ffprobe / Jellyfin no puedan leer el archivo MKV.

Como funciona, por cada pista VobSub danada:
  1. La extrae con mkvextract (.idx + .sub).
  2. Corrige la linea "size:" del .idx (720x480 NTSC o 720x576 PAL).
  3. Arma un MKV nuevo con mkvmerge: todo el original menos esa pista,
     mas la pista corregida (conserva idioma, nombre y banderas).
  4. Verifica el MKV nuevo con ffprobe.
  5. Solo si todo salio bien, renombra el original a .bak y pone el nuevo en su lugar.

Uso:
  python3 reparar-vobsub.py RUTA [RUTA ...]           # solo revisa y muestra que haria
  python3 reparar-vobsub.py --aplicar RUTA [RUTA ...] # repara de verdad
  python3 reparar-vobsub.py --lista danados.txt       # solo los archivos de una lista
                                                      # (copiada desde Panel > Archivos danados)
Opciones:
  --borrar-bak     borra el original despues de verificar (por defecto se conserva .bak)
  --contenedor N   contenedor de Jellyfin para usar su ffprobe si no hay ffprobe local (jellyfin)
RUTA puede ser un archivo .mkv o una carpeta (se busca recursivamente).
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

SIZE_RE = re.compile(r'^size:\s*(\d+)x(\d+)\s*$', re.MULTILINE)


def run(cmd, **kw):
    return subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, **kw)


def identify(path):
    r = run(['mkvmerge', '-J', path])
    if r.returncode not in (0, 1):
        raise RuntimeError(r.stdout or r.stderr)
    return json.loads(r.stdout)


def broken_vobsubs(info):
    """Devuelve las pistas VobSub cuyo tamano falta o es 0x0."""
    out = []
    for t in info.get('tracks', []):
        if t.get('codec') != 'VobSub' and t.get('properties', {}).get('codec_id') != 'S_VOBSUB':
            continue
        hexdata = t.get('properties', {}).get('codec_private_data') or ''
        try:
            private = bytes.fromhex(hexdata).decode('latin-1')
        except ValueError:
            private = ''
        m = SIZE_RE.search(private)
        if not m or int(m.group(1)) == 0 or int(m.group(2)) == 0:
            out.append(t)
    return out


def guess_size(info):
    """720x576 para fuentes PAL (25 fps), 720x480 para NTSC."""
    for t in info.get('tracks', []):
        if t.get('type') != 'video':
            continue
        p = t.get('properties', {})
        dims = p.get('pixel_dimensions', '')
        if dims in ('720x480', '720x576'):
            return dims
        dur = p.get('default_duration') or 0  # nanosegundos por cuadro
        if dur and abs(1e9 / dur - 25) < 0.5:
            return '720x576'
    return '720x480'


def ffprobe_ok(path, container):
    cmd = ['ffprobe', '-v', 'error', '-print_format', 'json', '-show_streams', '-show_format', path]
    if not shutil.which('ffprobe'):
        cmd = ['docker', 'exec', container] + cmd
    r = run(cmd)
    if r.returncode != 0:
        return False, (r.stderr or '').strip().splitlines()[-1:] or ['error']
    try:
        data = json.loads(r.stdout)
        return bool(data.get('streams')), []
    except json.JSONDecodeError:
        return False, ['JSON invalido']


def bool_flag(v):
    return 'yes' if v else 'no'


def repair(path, info, tracks, size, args):
    folder = os.path.dirname(path)
    tmp = tempfile.mkdtemp(prefix='.vobsubfix-', dir=folder)
    try:
        # 1. Extraer las pistas danadas
        extract = ['mkvextract', path, 'tracks']
        for t in tracks:
            idx_path = os.path.join(tmp, 'track%d.idx' % t['id'])
            extract.append('%d:%s' % (t['id'], idx_path))
        r = run(extract)
        if r.returncode != 0:
            raise RuntimeError('mkvextract fallo: ' + (r.stdout + r.stderr).strip()[-300:])

        # 2. Corregir el tamano en cada .idx
        for t in tracks:
            idx = os.path.join(tmp, f"track{t['id']}.idx")
            with open(idx, encoding='latin-1') as fh:
                text = fh.read()
            if SIZE_RE.search(text):
                text = SIZE_RE.sub(f'size: {size}', text, count=1)
            else:
                text = f'size: {size}\n' + text
            with open(idx, 'w', encoding='latin-1') as fh:
                fh.write(text)

        # 3. Armar el MKV nuevo
        out = os.path.join(tmp, 'reparado.mkv')
        skip = ','.join(str(t['id']) for t in tracks)
        cmd = ['mkvmerge', '-q', '-o', out, '--subtitle-tracks', '!' + skip, path]
        for t in tracks:
            p = t.get('properties', {})
            cmd += ['--language', f"0:{p.get('language_ietf') or p.get('language') or 'und'}"]
            if p.get('track_name'):
                cmd += ['--track-name', f"0:{p['track_name']}"]
            cmd += ['--default-track-flag', f"0:{bool_flag(p.get('default_track'))}",
                    '--forced-display-flag', f"0:{bool_flag(p.get('forced_track'))}",
                    os.path.join(tmp, f"track{t['id']}.idx")]
        r = run(cmd)
        if r.returncode not in (0, 1):  # 1 = advertencias
            raise RuntimeError('mkvmerge fallo: ' + (r.stdout + r.stderr).strip()[-300:])

        # 4. Verificar
        new_info = identify(out)
        if len(new_info.get('tracks', [])) != len(info.get('tracks', [])):
            raise RuntimeError('el archivo nuevo no tiene las mismas pistas')
        ok, err = ffprobe_ok(out, args.contenedor)
        if not ok:
            raise RuntimeError('ffprobe sigue sin poder leerlo: ' + ' '.join(err))

        # 5. Reemplazar
        bak = path + '.bak'
        os.replace(path, bak)
        shutil.move(out, path)
        try:
            shutil.copymode(bak, path)
        except OSError:
            pass
        if args.borrar_bak:
            os.remove(bak)
        return bak if not args.borrar_bak else None
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def collect(paths):
    for p in paths:
        if os.path.isdir(p):
            for root, _, files in os.walk(p):
                for f in sorted(files):
                    if f.lower().endswith('.mkv') and not f.startswith('.'):
                        yield os.path.join(root, f)
        elif p.lower().endswith('.mkv'):
            yield p


def read_list(list_path):
    """Lee rutas de un archivo de texto (una por linea, se ignoran vacias y #comentarios)."""
    with open(list_path, encoding='utf-8') as fh:
        return [line.strip() for line in fh if line.strip() and not line.strip().startswith('#')]


def main():
    ap = argparse.ArgumentParser(description='Repara subtitulos VobSub con tamano 0x0 en archivos MKV.')
    ap.add_argument('rutas', nargs='*')
    ap.add_argument('--lista', help='archivo de texto con una ruta por linea (copiada desde Archivos danados)')
    ap.add_argument('--aplicar', action='store_true', help='repara de verdad (sin esto solo revisa)')
    ap.add_argument('--borrar-bak', action='store_true', help='borra el original tras verificar')
    ap.add_argument('--contenedor', default='jellyfin', help='contenedor de Jellyfin para su ffprobe')
    args = ap.parse_args()

    for tool in ('mkvmerge', 'mkvextract'):
        if not shutil.which(tool):
            sys.exit(f'Falta {tool}. Instala mkvtoolnix: sudo apt install mkvtoolnix')

    rutas = list(args.rutas)
    if args.lista:
        rutas += read_list(args.lista)
    if not rutas:
        sys.exit('Indica al menos una carpeta, un archivo .mkv o --lista archivo.txt')

    print('Buscando archivos .mkv...', flush=True)
    files = list(collect(rutas))
    total = len(files)
    print(f'{total} archivos para revisar.\n', flush=True)
    show_progress = sys.stderr.isatty()

    def say(*a, **kw):
        """Imprime una linea borrando antes el contador de avance."""
        if show_progress:
            sys.stderr.write(chr(13) + " " * 40 + chr(13))
        kw.pop("flush", None)
        print(*a, flush=True, **kw)

    revisados = danados = reparados = fallidos = 0
    for path in files:
        revisados += 1
        if show_progress:
            sys.stderr.write(f'\r  revisando {revisados}/{total}...')
            sys.stderr.flush()
        if not os.path.exists(path):
            say(f'[NO EXISTE] {path}')
            fallidos += 1
            continue
        try:
            info = identify(path)
        except Exception as ex:  # noqa: BLE001
            say(f'[ERROR]   {path}\n          no se pudo leer con mkvmerge: {ex}')
            fallidos += 1
            continue
        tracks = broken_vobsubs(info)
        if not tracks:
            continue
        danados += 1
        size = guess_size(info)
        ids = ', '.join(f"#{t['id']} ({t.get('properties', {}).get('language', '?')})" for t in tracks)
        if not args.aplicar:
            say(f'[DANADO]  {path}\n          pistas VobSub sin tamano: {ids} -> se pondria {size}')
            continue
        say(f'[REPARA]  {path}\n          pistas {ids} -> {size} ...', flush=True)
        try:
            bak = repair(path, info, tracks, size, args)
            reparados += 1
            say('          OK' + (f' (original guardado como {os.path.basename(bak)})' if bak else ''))
        except Exception as ex:  # noqa: BLE001
            fallidos += 1
            say(f'          FALLO: {ex}\n          El original no se toco.')

    say(f'\nRevisados: {revisados} | Con VobSub danado: {danados} | Reparados: {reparados} | Fallidos: {fallidos}')
    if danados and not args.aplicar:
        print('Para repararlos ejecuta lo mismo agregando --aplicar')


if __name__ == '__main__':
    main()
