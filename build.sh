#!/usr/bin/env bash
# DevServers.app 번들 생성: ./build.sh  →  build/DevServers.app
set -euo pipefail
cd "$(dirname "$0")"

# UNIVERSAL=1 이면 Apple Silicon + Intel 유니버설 바이너리로 빌드 (배포용)
ARCH_FLAGS=()
if [[ "${UNIVERSAL:-0}" == "1" ]]; then
    ARCH_FLAGS=(--arch arm64 --arch x86_64)
fi

swift build -c release --product DevServers ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}
BIN="$(swift build -c release --show-bin-path ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"})/DevServers"

APP="build/DevServers.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/DevServers"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# ad-hoc 서명. entitlements 를 주지 않으므로 App Sandbox 는 꺼진 상태다.
codesign --force --sign - "$APP"

echo "✅ $APP"
