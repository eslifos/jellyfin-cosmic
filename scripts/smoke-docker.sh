#!/usr/bin/env bash
# Starts an image with empty data and checks that the server and the Cosmic web answer.
set -euo pipefail

image="$1"
port="${2:-18096}"
name="cosmic-smoke-$$"

trap 'docker rm -f "$name" >/dev/null 2>&1 || true' EXIT
docker run -d --name "$name" -p "127.0.0.1:$port:8096" "$image" >/dev/null

for _ in $(seq 1 60); do
    if [ "$(curl -fsS "http://127.0.0.1:$port/health" 2>/dev/null || true)" = "Healthy" ]; then
        code=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$port/web/index.html")
        wizard=$(curl -fsS "http://127.0.0.1:$port/System/Info/Public")
        [ "$code" = "200" ] || { echo "La web respondió $code" >&2; exit 1; }
        printf '%s' "$wizard" | grep -q '"StartupWizardCompleted":false' || { echo "No inició como instalación nueva" >&2; exit 1; }
        docker exec "$name" sh -c 'ffmpeg -version >/dev/null && yt-dlp --version >/dev/null && deno --version >/dev/null && mkvmerge --version >/dev/null'
        echo "Imagen correcta"
        exit 0
    fi
    sleep 2
done

docker logs --tail 40 "$name" >&2
echo "El servidor no respondió a tiempo" >&2
exit 1
