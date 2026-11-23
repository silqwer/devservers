#!/usr/bin/env bash
# 데모/녹화용 가짜 개발 서버 3개를 띄운다. Ctrl-C 로 모두 종료.
#
#   ./scripts/demo-servers.sh
#   DEVSERVERS_DEMO_ROOT=/tmp/devservers-demo ./build/DevServers.app/Contents/MacOS/DevServers
#
# 앱을 DEVSERVERS_DEMO_ROOT 와 함께 실행하면 이 데모 서버들만 보이므로
# 실제 프로젝트 이름·경로가 화면에 노출되지 않는다.
set -euo pipefail
set -m  # 서버마다 별도 프로세스 그룹 → 앱의 그룹 종료 동작을 그대로 시연

ROOT="${DEVSERVERS_DEMO_ROOT:-/tmp/devservers-demo}"
command -v node >/dev/null || { echo "node 가 필요합니다"; exit 1; }

# make_project <폴더> <package name> <실행 파일명> <포트> <CPU 부하 0~1>
make_project() {
  local dir="$ROOT/$1" name="$2" bin="$3" port="$4" load="$5"
  mkdir -p "$dir/node_modules/.bin"
  printf '{ "name": "%s", "private": true }\n' "$name" > "$dir/package.json"
  cat > "$dir/node_modules/.bin/$bin" <<JS
const port = $port, load = $load;
require('http').createServer((_, res) => res.end('$name dev server on :' + port)).listen(port);
// 개발 서버가 컴파일하는 것처럼 CPU 를 일정 비율로 사용
if (load > 0) setInterval(() => { const end = Date.now() + 100 * load; while (Date.now() < end); }, 100);
JS
}

make_project my-blog       my-blog          next      3001 0.05
make_project landing-page  landing-page     vite      5173 0.2
make_project design-system "@acme/design-system" storybook 6006 0.6

pids=()
start() {  # start <폴더> <실행 파일명> <인자...>
  local dir="$ROOT/$1" bin="$2"; shift 2
  (cd "$dir" && exec node "node_modules/.bin/$bin" "$@") &
  pids+=($!)
}

start my-blog next dev
sleep "${DEMO_STAGGER:-0}"
start landing-page vite
sleep "${DEMO_STAGGER:-0}"
start design-system storybook dev -p 6006

trap 'kill -- $(printf -- "-%s " "${pids[@]}") 2>/dev/null; exit 0' INT TERM
echo "데모 서버 실행 중 (root: $ROOT) — Ctrl-C 로 종료"
wait
