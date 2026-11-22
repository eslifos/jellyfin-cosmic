#!/usr/bin/env bash
# Downloads, and checks, the helper programs that go inside a package.
# Usage: fetch-tools.sh <linux-amd64|linux-arm64|windows-x64> <payload folder>
set -euo pipefail

target="$1"
out="$2"

FFMPEG_VERSION=8.1.3-2
FFMPEG_SHA256=b65dd5011a80b5abec08bd559489cf188217238c8e38b5bf553504c974f5694d
WINSW_VERSION=v2.12.0
WINSW_SHA256=05b82d46ad331cc16bdc00de5c6332c1ef818df8ceefcd49c726553209b3a0da

case "$target" in
    linux-amd64) ytdlp=yt-dlp_linux; ytdlp_out=yt-dlp; deno=deno-x86_64-unknown-linux-gnu.zip ;;
    linux-arm64) ytdlp=yt-dlp_linux_aarch64; ytdlp_out=yt-dlp; deno=deno-aarch64-unknown-linux-gnu.zip ;;
    windows-x64) ytdlp=yt-dlp.exe; ytdlp_out=yt-dlp.exe; deno=deno-x86_64-pc-windows-msvc.zip ;;
    *) echo "Destino desconocido: $target" >&2; exit 1 ;;
esac

get() { curl -fsSL --retry 3 -o "$2" "$1"; }
check() { printf '%s  %s\n' "$1" "$2" | sha256sum -c --quiet -; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$out/tools"

ytdlp_base=https://github.com/yt-dlp/yt-dlp/releases/latest/download
get "$ytdlp_base/$ytdlp" "$work/$ytdlp"
get "$ytdlp_base/SHA2-256SUMS" "$work/ytdlp.sums"
check "$(awk -v f="$ytdlp" '$2 == f { print $1 }' "$work/ytdlp.sums")" "$work/$ytdlp"
install -m 755 "$work/$ytdlp" "$out/tools/$ytdlp_out"

deno_base=https://github.com/denoland/deno/releases/latest/download
get "$deno_base/$deno" "$work/$deno"
get "$deno_base/$deno.sha256sum" "$work/deno.sum"
check "$(grep -Eoi '[a-f0-9]{64}' "$work/deno.sum" | head -n 1 | tr '[:upper:]' '[:lower:]')" "$work/$deno"
unzip -q -o "$work/$deno" -d "$out/tools"
chmod 755 "$out/tools"/deno*

if [ "$target" = windows-x64 ]; then
    ffmpeg=jellyfin-ffmpeg_${FFMPEG_VERSION}_portable_win64-clang-gpl.zip
    get "https://github.com/jellyfin/jellyfin-ffmpeg/releases/download/v$FFMPEG_VERSION/$ffmpeg" "$work/ffmpeg.zip"
    check "$FFMPEG_SHA256" "$work/ffmpeg.zip"
    mkdir -p "$out/ffmpeg"
    unzip -q -o "$work/ffmpeg.zip" -d "$out/ffmpeg"

    mkdir -p "$out/winsw"
    get "https://github.com/winsw/winsw/releases/download/$WINSW_VERSION/WinSW-x64.exe" "$work/winsw.exe"
    check "$WINSW_SHA256" "$work/winsw.exe"
    install -m 755 "$work/winsw.exe" "$out/winsw/JellyfinCosmicService.exe"
fi
