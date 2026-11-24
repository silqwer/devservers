#!/usr/bin/env bash
# GitHub 릴리즈를 올린 뒤 Homebrew Cask(silqwer/homebrew-tap)의 version·sha256 을 갱신한다.
#
#   ./scripts/update-cask.sh            # Info.plist 의 버전으로 갱신하고 tap 에 푸시
#   ./scripts/update-cask.sh 1.0.2      # 버전 지정
#   ./scripts/update-cask.sh --dry-run  # 푸시하지 않고 변경 내용만 출력
#
# 해시는 로컬 dist/ 가 아니라 실제로 배포된 릴리즈 zip 에서 계산한다 (사용자가 받는 파일과 일치시키기 위해).
# GH_TOKEN 이 설정되어 있으면 그 토큰으로 푸시한다 (gh 계정이 여러 개일 때: GH_TOKEN=$(gh auth token -u silqwer)).
set -euo pipefail
cd "$(dirname "$0")/.."

REPO="silqwer/devservers"
TAP_REPO="silqwer/homebrew-tap"
CASK_PATH="Casks/devservers.rb"

DRY_RUN=0
VERSION=""
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -h | --help) sed -n '2,9p' "$0"; exit 0 ;;
    *) VERSION="$arg" ;;
  esac
done
if [[ -z "$VERSION" ]]; then
  VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

URL="https://github.com/$REPO/releases/download/v$VERSION/DevServers.zip"
echo "==> v$VERSION 릴리즈 zip 내려받는 중"
if ! curl -fsSL -o "$WORK/DevServers.zip" "$URL"; then
  echo "릴리즈 zip 을 찾을 수 없어요: $URL" >&2
  echo "먼저 GitHub 릴리즈(v$VERSION)에 DevServers.zip 을 올려 주세요." >&2
  exit 1
fi
SHA=$(shasum -a 256 "$WORK/DevServers.zip" | awk '{print $1}')
echo "    sha256 $SHA"

# 토큰이 있으면 이 명령에서만 쓰는 credential helper 로 인증한다 (전역 설정은 건드리지 않음)
GIT=(git)
if [[ -n "${GH_TOKEN:-}" ]]; then
  GIT=(git -c credential.helper= -c "credential.helper=!f(){ echo username=x-access-token; echo password=\$GH_TOKEN; }; f")
fi

echo "==> $TAP_REPO 받는 중"
"${GIT[@]}" clone -q --depth 1 "https://github.com/$TAP_REPO.git" "$WORK/tap"
CASK="$WORK/tap/$CASK_PATH"

sed -i '' -E \
  -e "s/^(  version )\"[^\"]*\"/\1\"$VERSION\"/" \
  -e "s/^(  sha256 )\"[^\"]*\"/\1\"$SHA\"/" \
  "$CASK"

cd "$WORK/tap"
if git diff --quiet; then
  echo "cask 가 이미 v$VERSION 이에요. 바꿀 내용이 없어요."
  exit 0
fi
git --no-pager diff

if [[ "$DRY_RUN" == 1 ]]; then
  echo "==> --dry-run: 푸시하지 않았어요."
  exit 0
fi

git -c user.name="$(git -C "$OLDPWD" config user.name)" -c user.email="$(git -C "$OLDPWD" config user.email)" \
  commit -q -am "🚀 tap: devservers $VERSION 업데이트"
"${GIT[@]}" push -q origin HEAD
echo "==> $TAP_REPO 에 v$VERSION 반영 완료. 사용자는 'brew upgrade --cask devservers' 로 업데이트할 수 있어요."
