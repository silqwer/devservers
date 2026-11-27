#!/usr/bin/env bash
# 앱 아이콘 생성: Resources/Icon/AppIcon.svg → Resources/AppIcon.icns
# SVG 를 고친 뒤에만 실행하면 된다 (rsvg-convert 필요: brew install librsvg).
set -euo pipefail
cd "$(dirname "$0")/.."

SVG="Resources/Icon/AppIcon.svg"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
SET="$WORK/AppIcon.iconset"
mkdir -p "$SET"

for size in 16 32 128 256 512; do
    rsvg-convert -w "$size" -h "$size" "$SVG" -o "$SET/icon_${size}x${size}.png"
    rsvg-convert -w $((size * 2)) -h $((size * 2)) "$SVG" -o "$SET/icon_${size}x${size}@2x.png"
done

iconutil -c icns "$SET" -o Resources/AppIcon.icns
echo "✅ Resources/AppIcon.icns"
