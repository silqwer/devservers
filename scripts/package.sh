#!/usr/bin/env bash
# 배포용 zip 생성: Apple Silicon + Intel 유니버설 빌드 → dist/DevServers.zip
#
# 키체인에 "Developer ID Application" 인증서가 있으면 그 인증서로 서명하고 Apple 공증까지 받는다.
#   - 인증서를 고르려면:      SIGN_IDENTITY="Developer ID Application: 이름 (TEAMID)" ./scripts/package.sh
#   - 공증 자격 증명 프로필:  NOTARY_PROFILE (기본 devservers-notary). 처음 한 번 아래로 저장해 둔다.
#       xcrun notarytool store-credentials devservers-notary --apple-id <Apple ID> --team-id <TEAMID>
# 인증서가 없으면 예전처럼 ad-hoc 서명 zip 을 만든다 (공증 없음).
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/DevServers.app"
ZIP="dist/DevServers.zip"
NOTARY_PROFILE="${NOTARY_PROFILE:-devservers-notary}"

if [[ -z "${SIGN_IDENTITY:-}" ]]; then
  SIGN_IDENTITY=$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: .*\)"/\1/p' | head -1)
fi

make_zip() {
  mkdir -p dist
  rm -f "$ZIP"
  # ditto 는 번들 구조·확장 속성·서명을 보존한다
  ditto -c -k --keepParent "$APP" "$ZIP"
}

if [[ -z "$SIGN_IDENTITY" ]]; then
  echo "⚠️  Developer ID 인증서가 없어 ad-hoc 서명으로 만들어요 (공증 없음)."
  UNIVERSAL=1 ./build.sh
  make_zip
  shasum -a 256 "$ZIP"
  exit 0
fi

echo "==> 서명: $SIGN_IDENTITY"
UNIVERSAL=1 SIGN_IDENTITY="$SIGN_IDENTITY" ./build.sh
codesign --verify --strict --verbose=2 "$APP"
make_zip

echo "==> 공증 요청 중 (보통 수 분 걸려요)"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait

# 공증 티켓을 앱에 붙여 오프라인에서도 Gatekeeper 가 확인할 수 있게 한 뒤 다시 압축한다
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
make_zip

spctl --assess --type execute --verbose=2 "$APP"
shasum -a 256 "$ZIP"
echo "✅ 공증 완료: $ZIP"
