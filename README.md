# Jellyfin Cosmic

Servidor multimedia basado en [Jellyfin](https://jellyfin.org), con una interfaz rediseñada, Universos, un Inicio preparado en segundo plano, reproductor nuevo y control remoto de dispositivos.

> Es una versión modificada y **no está afiliada al proyecto oficial de Jellyfin**. Haz una copia de tus datos antes de usarla sobre una instalación existente.

Después de instalar, abre `http://localhost:8096` o `http://IP-DEL-EQUIPO:8096` y sigue el asistente.

## Docker

```sh
docker run -d --name jellyfin-cosmic --restart unless-stopped \
  -p 8096:8096 \
  -v jellyfin-cosmic-config:/config \
  -v jellyfin-cosmic-cache:/cache \
  -v /ruta/a/tus/medios:/media:ro \
  ghcr.io/eslifos/jellyfin-cosmic:latest
```

También puedes usar [docker-compose.yml](docker/docker-compose.yml). Funciona en equipos x86-64 y ARM64.

## Ubuntu y Debian

Descarga el `.deb` de tu equipo desde [Versiones](https://github.com/eslifos/jellyfin-cosmic/releases) e instálalo:

```sh
sudo apt install ./jellyfin-cosmic_VERSION_amd64.deb
```

Queda como servicio y arranca con el equipo. Dale permiso de lectura sobre tus carpetas al usuario `jellyfin-cosmic`.

## Otras distribuciones de Linux

Descarga el `.tar.gz`, instala `ffmpeg` con tu gestor de paquetes y ejecuta:

```sh
tar -xzf jellyfin-cosmic-VERSION-linux-amd64.tar.gz
cd jellyfin-cosmic-VERSION-linux-amd64
./start.sh
```

## Windows

Descarga `jellyfin-cosmic-VERSION-windows-x64-setup.exe` desde [Versiones](https://github.com/eslifos/jellyfin-cosmic/releases) y ábrelo. Queda como servicio de Windows y arranca con el equipo. Al desinstalar se conservan tus datos en `C:\ProgramData\JellyfinCosmic`.

## iPhone y iPad

iOS no puede ejecutar el servidor. Conéctate a él con la app de Jellyfin o abre su dirección en Safari y usa **Compartir → Agregar a inicio**.

## Publicar una versión

```sh
git tag v12.4.0-1
git push origin v12.4.0-1
```

GitHub compila, prueba y publica la imagen de Docker y los paquetes.

## Licencia

GPL-2.0. Consulta [LICENSE](LICENSE) y [NOTICE.md](NOTICE.md).
