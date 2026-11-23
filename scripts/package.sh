#!/usr/bin/env bash
# 배포용 zip 생성: Apple Silicon + Intel 유니버설 빌드 → dist/DevServers.zip
set -euo pipefail
cd "$(dirname "$0")/.."

UNIVERSAL=1 ./build.sh
mkdir -p dist
rm -f dist/DevServers.zip
# ditto 는 번들 구조·확장 속성·서명을 보존한다
ditto -c -k --keepParent build/DevServers.app dist/DevServers.zip
shasum -a 256 dist/DevServers.zip
