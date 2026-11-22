#!/bin/sh
# Starts Jellyfin Cosmic from this folder, with its data in ./data
here="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
export PATH="$here/tools:$PATH"
export MALLOC_TRIM_THRESHOLD_=131072 MALLOC_ARENA_MAX=2 DOTNET_GCConserveMemory=5

if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "Falta ffmpeg. Instálalo con el gestor de paquetes de tu sistema." >&2
    exit 1
fi

exec "$here/server/jellyfin" \
    --datadir "$here/data" \
    --cachedir "$here/data/cache" \
    --logdir "$here/data/log" \
    --webdir "$here/web" \
    --ffmpeg "$(command -v ffmpeg)" \
    "$@"
