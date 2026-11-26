# DevServers

[English](README.md) · **한국어**

로컬에서 띄워 둔 개발 서버(`next dev`, `vite`, `storybook` …)가 **어느 프로젝트의 서버인지, 포트가 뭔지** 한눈에 보고 바로 끌 수 있는 macOS 메뉴바 앱.

서버 랙 콘셉트로 만들었다. 메뉴바 아이콘의 LED는 서버 수만큼 켜지고, 서버가 CPU를 많이 쓸수록 빠르게 깜빡인다.

<p align="center">
  <img src="docs/assets/menubar.gif" alt="서버가 하나씩 켜질 때마다 랙 아이콘의 초록 LED가 늘어나고 빨간 활동 LED가 깜빡이는 메뉴바 아이콘" height="72">
</p>

**[소개 페이지](https://silqwer.github.io/devservers/) · [다운로드 (DevServers.zip)](https://github.com/silqwer/devservers/releases/latest/download/DevServers.zip)**

[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20me%20a%20coffee-FFDD00?logo=buymeacoffee&logoColor=000)](https://buymeacoffee.com/silqwers)

## 기능

- **메뉴바 아이콘**: 3칸짜리 서버 랙
  - 초록 전원 LED: 실행 중인 서버 수만큼 위 칸부터 켜짐 (최대 3칸)
  - 빨강 활동 LED: 서버 CPU 사용량 합계에 비례해 깜빡임 (0% → 0.9초 간격, 100%+ → 0.07초 간격)
- **서버 목록 패널**: 서버 하나가 1U 랙 장비 한 대로 표시됨
  - 프로젝트명(`package.json`의 `name`, 없으면 폴더명), 종류(Next.js / Vite / Storybook …), 포트, PID
  - 포트 LCD 창 클릭 → `http://localhost:포트` 열기
  - 🧭 브라우저로 열기 · 📁 Finder에서 열기 (툴팁에 경로 표시) · ⏻ 서버 종료
- **종료**: 프로세스 그룹에 `SIGTERM` → 3초 뒤에도 살아 있으면 `SIGKILL`
- **전체 종료**: 확인 띠를 거친 뒤 목록의 모든 서버 종료
- **ALL PROCS 스위치**: 기본은 node 프로세스만, 켜면 LISTEN 중인 모든 프로세스 표시
- 패널을 열 때와 3초마다 자동 갱신 (스캔은 백그라운드에서 실행)
- Dock 아이콘 없음 (`LSUIElement`), 시스템 설정의 "동작 줄이기"를 켜면 LED 깜빡임 멈춤
- 영어 · 한국어 화면 지원 (시스템 언어를 따름)

## 요구 사항

- macOS 14 이상
- Xcode 또는 Swift 5.10 이상 툴체인 (`xcode-select -p`로 확인)

## 설치

### Homebrew

```bash
brew install --cask silqwer/tap/devservers
```

업데이트는 `brew upgrade --cask devservers`. 업데이트 중에 실행 중인 앱이 종료되므로, 끝나면 다시 열어 준다.

로그인 시 자동 실행하려면 `/Applications/DevServers.app`을 **시스템 설정 → 일반 → 로그인 항목**에 추가한다.

### 직접 내려받기

1. [DevServers.zip](https://github.com/silqwer/devservers/releases/latest/download/DevServers.zip)을 내려받아 압축을 풀고 `DevServers.app`을 `/Applications`로 옮긴다. (Apple Silicon · Intel 유니버설)
2. 실행한다. 처음 한 번은 "인터넷에서 다운로드한 앱"이라는 확인 창이 뜨는데 **열기**를 누르면 된다.

배포본은 Developer ID로 서명하고 Apple 공증을 받았기 때문에 "확인되지 않은 개발자" 경고가 뜨지 않는다.

## 빌드 & 실행

```bash
git clone https://github.com/silqwer/devservers.git
cd devservers
./build.sh                     # build/DevServers.app 생성
open build/DevServers.app
```

로그인 시 자동 실행하려면 `build/DevServers.app`을 `/Applications`로 복사한 뒤 **시스템 설정 → 일반 → 로그인 항목**에 추가한다.

앱 종료는 패널 오른쪽 아래 **⏏ QUIT** 버튼 또는 `⌘Q`. 앱을 꺼도 실행 중인 서버는 그대로 유지된다.

### 터미널에서 스캔 결과만 확인

```bash
swift run devservers-scan          # node 서버만
swift run devservers-scan --all    # LISTEN 중인 모든 프로세스
```

```
PID     PGID    PORTS          KIND        CPU%   PROJECT                    PATH
38272   38236   3000           Next.js     0.0    @cv-front/typist           ~/…/apps/typist
        └ next-server (v15.5.24)
```

### 릴리즈

```bash
# 1. Resources/Info.plist 의 CFBundleShortVersionString / CFBundleVersion 올리기
./scripts/package.sh       # 2. 유니버설 빌드 → Developer ID 서명 → 공증 → dist/DevServers.zip
# 3. vX.Y.Z 태그로 GitHub 릴리즈를 만들고 dist/DevServers.zip 업로드
./scripts/update-cask.sh   # 4. silqwer/homebrew-tap 의 version·sha256 갱신 (--dry-run 으로 미리보기)
```

`package.sh`는 키체인의 첫 번째 **Developer ID Application** 인증서(또는 `SIGN_IDENTITY`)로 서명한 뒤 공증을 받고 결과를 앱에 붙인다(staple). 공증 자격 증명은 처음 한 번만 저장해 두면 된다. 앱 암호는 `notarytool`이 직접 물어본다.

```bash
xcrun notarytool store-credentials devservers-notary --apple-id <Apple ID> --team-id <TEAMID>
```

Developer ID 인증서가 없으면 예전처럼 공증 없는 ad-hoc 서명 zip을 만든다.

### 데모 / 녹화

실제 프로젝트 이름·경로를 노출하지 않고 시연하려면 데모 서버를 띄우고 앱을 데모 모드로 실행한다.

```bash
./scripts/demo-servers.sh   # my-blog(:3001) · landing-page(:5173) · @acme/design-system(:6006)
DEVSERVERS_DEMO_ROOT=/tmp/devservers-demo ./build/DevServers.app/Contents/MacOS/DevServers
```

`DEVSERVERS_DEMO_ROOT`가 설정되면 그 폴더 아래에서 실행된 서버만 표시한다.

## 동작 방식

| 단계 | 명령 | 용도 |
|---|---|---|
| 1 | `lsof -iTCP -sTCP:LISTEN -n -P` | LISTEN 포트와 PID 수집 (PID 기준으로 묶음) |
| 2 | `lsof -a -p <PID,…> -d cwd -Fpn` | 작업 디렉터리 확인 |
| 3 | `<cwd>/package.json` | 프로젝트명 읽기 |
| 4 | `ps -o pid=,pgid=,%cpu=,command= -p <PID,…>` | 프로세스 그룹, CPU, 실행 명령 → 종류 라벨 |

여러 PID는 쉼표로 묶어 한 번에 조회하므로 스캔 한 번에 약 0.3초 걸린다.

다른 프로세스를 조회하고 종료해야 하므로 **App Sandbox를 사용하지 않는다**. 앱 자신의 프로세스 그룹이나 시스템 그룹(PGID ≤ 1)은 그룹 단위로 종료하지 않고 해당 PID만 종료한다.

## 구조

```
Sources/
├─ DevServersCore/    스캔 · 종료 로직 (UI 없음)
├─ devservers-scan/   터미널 확인용 CLI
└─ DevServers/        SwiftUI 메뉴바 앱 (MenuBarExtra .window)
Resources/Info.plist  LSUIElement 등 번들 설정
build.sh              .app 번들 생성 + 서명 (SIGN_IDENTITY 가 있으면 Developer ID, 없으면 ad-hoc · UNIVERSAL=1 이면 유니버설)
scripts/              package.sh (배포 zip) · update-cask.sh (Homebrew cask) · demo-servers.sh (데모 서버)
docs/                 GitHub Pages 소개 페이지
```

## 후원

DevServers는 무료 오픈소스예요. 도움이 되셨다면 커피 한 잔으로 응원해 주세요 ☕

[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20me%20a%20coffee-FFDD00?logo=buymeacoffee&logoColor=000)](https://buymeacoffee.com/silqwers)

## 라이선스

[MIT](LICENSE)
