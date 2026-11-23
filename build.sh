#!/usr/bin/env bash
# DevServers.app 번들 생성: ./build.sh  →  build/DevServers.app
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release --product DevServers
BIN="$(swift build -c release --show-bin-path)/DevServers"

APP="build/DevServers.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/DevServers"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# ad-hoc 서명. entitlements 를 주지 않으므로 App Sandbox 는 꺼진 상태다.
codesign --force --sign - "$APP"

echo "✅ $APP"
