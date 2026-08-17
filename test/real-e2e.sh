#!/usr/bin/env bash
# Real-app E2E test — drives run-script.sh against the actual Kyobo reader.
#
# Unlike test/smoke.sh (fully automated, uses Preview as a stand-in reader),
# this is a semi-automated RELEASE GATE: it exercises the real reader app,
# and a human does the final visual check of the captured PDF.
#
# Prerequisites:
#   - One-time: Accessibility + Screen Recording permission for the terminal
#   - Per-run:  the Kyobo app is open with a book visible in the viewer,
#     and the machine stays idle (no typing/mouse) while pages turn.
#
# Usage:
#   bash test/real-e2e.sh [--pages N] [--margin N] [--app 1|2] [--name NAME]
#
# Options:
#   --pages N    pages to capture (default 3)
#   --margin N   inset from the viewer window edge in px (default 10)
#   --app 1|2    1: 교보도서관 (default), 2: 교보eBook
#   --name NAME  test book name (default realtest_<pid>)
#
# Automation mode: REAL_E2E_ASSUME_YES=1 skips the interactive prompts
# (assumes a book is already open; keeps the PDF for later visual check).

set -o errexit
set -o nounset
set -o pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PAGES=3
MARGIN=10
APP=1
NAME="realtest_$$"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pages)  PAGES="$2"; shift 2 ;;
    --margin) MARGIN="$2"; shift 2 ;;
    --app)    APP="$2"; shift 2 ;;
    --name)   NAME="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

ASSUME_YES="${REAL_E2E_ASSUME_YES:-0}"
OUT_NAME="ebook_reader_$NAME"
RUNDIR="$HOME/Desktop/ebook_realtest_run_$$"
FAILED=0

pass() { echo "[PASS] $1"; }
fail() { echo "[FAIL] $1"; FAILED=1; }

count_pngs() {
  ls -1 "$HOME/Desktop/$1" 2>/dev/null | grep -c '\.png$' || true
}

interactive() { [[ "$ASSUME_YES" == "1" ]] && return 1 || return 0; }

echo "== real-app E2E: pages=$PAGES margin=$MARGIN app=$APP name=$NAME"

# --- 0. Guided pre-flight ---------------------------------------------------
if interactive; then
  echo "1) 교보 앱에서 아무 책이나 열어 뷰어 화면을 띄워주세요"
  echo "2) 시작 후 캡처가 끝날 때까지 키보드/마우스 금지 (페이지당 ~2초)"
  read -r -p "준비되면 Enter... " < /dev/tty
fi

# --- 1/2. Run the real pipeline (--region auto targets the reader window) ---
# The tool derives the region from the reader app's own window, so the
# terminal running this test can never become the capture target.
mkdir -p "$RUNDIR"
( cd "$RUNDIR" && exec "$ROOT/bin/ebook-capture" \
    --book "$NAME" --pages "$PAGES" --region auto --region-margin "$MARGIN" --app "$APP" ) &
PID=$!
MAX=0
while kill -0 "$PID" 2>/dev/null; do
  C="$(count_pngs "$OUT_NAME")"
  if [[ "$C" -gt "$MAX" ]]; then MAX="$C"; fi
  sleep 0.2
done
wait "$PID" 2>/dev/null || true
echo "== captured pages (max observed): $MAX/$PAGES"

# --- 3. Assertions ------------------------------------------------------------
PDF="$RUNDIR/$OUT_NAME.pdf"
if [[ -f "$PDF" ]]; then pass "PDF created: $PDF ($(stat -f%z "$PDF") bytes)"; else fail "PDF missing"; fi
if [[ "$MAX" -ge "$PAGES" ]]; then pass "captured $MAX/$PAGES pages"; else fail "only $MAX/$PAGES pages captured"; fi
if [[ -e "$HOME/Desktop/$OUT_NAME" ]]; then fail "temp dir left behind"; else pass "temp dir cleaned"; fi

# --- 4. Human visual check ----------------------------------------------------
if [[ -f "$PDF" ]]; then
  if interactive; then
    open "$PDF"
    echo "== PDF를 열었습니다. 내용이 온전한지(짤림 없음, 페이지 순서) 확인해주세요."
    read -r -p "테스트 PDF를 삭제할까요? [y/N] " ANSWER < /dev/tty
    if [[ "$ANSWER" == "y" || "$ANSWER" == "Y" ]]; then
      rm -rf "$RUNDIR"
      echo "== test PDF deleted"
    else
      echo "== kept: $RUNDIR"
    fi
  else
    echo "== automation mode: PDF kept for manual visual check"
    echo "==   $PDF  (확인 후 삭제 권장)"
  fi
fi

# --- 5. Summary ----------------------------------------------------------------
echo
if [[ "$FAILED" -eq 0 ]]; then
  echo "REAL-E2E: ALL PASS (시각 확인은 위 PDF로)"
else
  echo "REAL-E2E: FAILURES DETECTED"
  exit 1
fi
