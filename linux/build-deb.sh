#!/usr/bin/env bash
# Builds the .deb package.
# Usage: build-deb.sh <version> <amd64|arm64> <payload folder> <web folder> <output folder>
set -euo pipefail

version="$1"
arch="$2"
payload="$3"
web="$4"
out="$5"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT

install -d "$root/DEBIAN" "$root/opt/jellyfin-cosmic" "$root/lib/systemd/system" "$root/usr/share/doc/jellyfin-cosmic"
cp -a "$payload/." "$root/opt/jellyfin-cosmic/"
mkdir -p "$root/opt/jellyfin-cosmic/web"
cp -a "$web/." "$root/opt/jellyfin-cosmic/web/"
chmod 755 "$root/opt/jellyfin-cosmic/server/jellyfin"
install -m 644 "$here/jellyfin-cosmic.service" "$root/lib/systemd/system/jellyfin-cosmic.service"
install -m 644 "$here/../LICENSE" "$root/usr/share/doc/jellyfin-cosmic/copyright"
install -m 644 "$here/../NOTICE.md" "$root/usr/share/doc/jellyfin-cosmic/NOTICE.md"
for script in postinst prerm postrm; do
    install -m 755 "$here/$script" "$root/DEBIAN/$script"
done

size=$(du -sk "$root" | cut -f1)
cat > "$root/DEBIAN/control" <<EOF
Package: jellyfin-cosmic
Version: $version
Architecture: $arch
Maintainer: Jellyfin Cosmic <noreply@users.noreply.github.com>
Installed-Size: $size
Depends: adduser, ca-certificates, ffmpeg, libfontconfig1, libfreetype6, libssl3 | libssl3t64, libicu78 | libicu76 | libicu74 | libicu72 | libicu70
Recommends: mkvtoolnix, fonts-dejavu-core
Conflicts: jellyfin, jellyfin-server
Section: video
Priority: optional
Homepage: https://github.com/eslifos/jellyfin-cosmic
Description: Servidor multimedia basado en Jellyfin
 Jellyfin Cosmic es una versión modificada de Jellyfin, no afiliada al
 proyecto oficial.
EOF

mkdir -p "$out"
dpkg-deb --root-owner-group -Zxz --build "$root" "$out/jellyfin-cosmic_${version}_${arch}.deb"
