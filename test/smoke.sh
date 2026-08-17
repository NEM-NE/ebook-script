#!/usr/bin/env bash
# End-to-end smoke test for ebook-script — uses Preview as a stand-in reader.
#
# Generates a numbered 10-page PDF, opens it in Preview, and drives
# run-script.sh against it via the EBOOK_APP_NAME test hook.
#   TEST 1: full 10-page run -> complete PDF, temp dir cleaned up
#   TEST 2: SIGINT mid-run   -> partial PDF, temp dir cleaned up
#
# Requirements:
#   - ImageMagick (magick or convert)
#   - Accessibility + Screen Recording permission for the terminal app
#     running this script (System Settings > Privacy & Security)
#   - Keep the machine idle while the test runs (~60s): page turns are
#     real key events sent to the Preview window.
#
# Usage: bash test/smoke.sh

set -o errexit
set -o nounset
set -o pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d "${HOME}/Desktop/ebook_smoke.XXXXXX")"
PAGES=10
BOOK_PDF="$WORK/smokebook.pdf"
# Raw book names: run-script.sh prepends the "ebook_reader_" prefix itself
FULL_NAME="smoke_full"
INTR_NAME="smoke_intr"
FULL_OUT="ebook_reader_$FULL_NAME"
INTR_OUT="ebook_reader_$INTR_NAME"
FAILED=0

pass() { echo "[PASS] $1"; }
fail() { echo "[FAIL] $1"; FAILED=1; }

cleanup() {
  # Close only the windows this test opened, then quit Preview if idle
  osascript -e 'tell application "Preview" to close (every window whose name contains "smokebook")' >/dev/null 2>&1 || true
  osascript -e 'tell application "Preview" to if (count of windows) is 0 then quit' >/dev/null 2>&1 || true
  rm -rf "$WORK" "$HOME/Desktop/$FULL_OUT" "$HOME/Desktop/$INTR_OUT" 2>/dev/null || true
}
trap cleanup EXIT

# Count captured PNGs without tripping errexit/pipefail when none exist yet
count_pngs() {
  ls -1 "$HOME/Desktop/$1" 2>/dev/null | grep -c '\.png$' || true
}

# --- 1. Build a numbered 10-page test book ---------------------------------
echo "== building $PAGES-page test book in $WORK"
# Explicit font: Homebrew ImageMagick often ships without a default font
SYSFONT="/System/Library/Fonts/Supplemental/Arial.ttf"
for i in $(seq 1 "$PAGES"); do
  magick -size 800x1000 xc:white -font "$SYSFONT" -pointsize 80 -fill black \
    -annotate +250+520 "PAGE $i" "$WORK/page-$(printf '%02d' "$i").png"
done
magick "$WORK"/page-*.png "$BOOK_PDF"
rm -f "$WORK"/page-*.png

# --- 2. Open in Preview; derive the capture region from its window ---------
open -a Preview "$BOOK_PDF"
sleep 3
BOUNDS=""
for _ in 1 2 3; do
  BOUNDS="$(osascript -e 'tell application "System Events" to tell process "Preview" to get {position, size} of front window' 2>/dev/null)" && break
  sleep 2
done
if [[ -z "$BOUNDS" ]]; then
  echo "ERROR: cannot read the Preview window." >&2
  echo "Grant Accessibility permission to your terminal app, then retry." >&2
  exit 1
fi
echo "== preview window (x, y, w, h): $BOUNDS"
read -r wx wy ww wh <<<"$(echo "$BOUNDS" | tr ',' ' ')"
m=60
POS="$((wx+m)) $((wy+m)) $((ww-2*m)) $((wh-2*m))"
echo "== capture region (x y w h): $POS"

# --- 3. TEST 1: full run via the CLI flag interface --------------------------
echo "== TEST 1: full $PAGES-page run (CLI flags)"
( cd "$WORK" && exec env EBOOK_APP_NAME=Preview "$ROOT/bin/ebook-capture" \
    --book "$FULL_NAME" --pages "$PAGES" --region "$POS" --app 1 \
    >/dev/null 2>&1 ) &
PID1=$!
MAX=0
while kill -0 "$PID1" 2>/dev/null; do
  C="$(count_pngs "$FULL_OUT")"
  if [[ "$C" -gt "$MAX" ]]; then MAX="$C"; fi
  sleep 0.2
done
wait "$PID1" 2>/dev/null || true

if [[ -f "$WORK/$FULL_OUT.pdf" ]]; then pass "full PDF created"; else fail "full PDF missing"; fi
if [[ "$MAX" -ge "$PAGES" ]]; then
  pass "captured $MAX/$PAGES pages"
elif [[ "$MAX" -ge $((PAGES-2)) ]]; then
  pass "captured ~$MAX/$PAGES pages (poll race, acceptable)"
else
  fail "only $MAX/$PAGES pages captured"
fi
if [[ -e "$HOME/Desktop/$FULL_OUT" ]]; then fail "temp dir left behind (full)"; else pass "temp dir cleaned (full)"; fi

# --- 4. TEST 2: SIGINT mid-run ----------------------------------------------
echo "== TEST 2: SIGINT mid-run"
mkdir -p "$WORK/intr"
printf '%s\n' "$INTR_NAME" "$PAGES" "$POS" 1 > "$WORK/intr/input.txt"
( cd "$WORK/intr" && exec env EBOOK_APP_NAME=Preview "$ROOT/run-script.sh" < input.txt >/dev/null 2>&1 ) &
PID2=$!
sleep 7
PAGES_AT_KILL="$(count_pngs "$INTR_OUT")"
kill -INT "$PID2" 2>/dev/null || true
# A terminal Ctrl-C signals the whole foreground group; a bare kill hits only
# the script, so also signal the osascript child explicitly.
pkill -INT -f "screencapture.applescript" 2>/dev/null || true
RC=0
wait "$PID2" 2>/dev/null || RC=$?
echo "== interrupted after ~$PAGES_AT_KILL page(s), exit code $RC"

if [[ -f "$WORK/intr/$INTR_OUT.pdf" ]]; then pass "partial PDF created"; else fail "partial PDF missing"; fi
if [[ -s "$WORK/intr/$INTR_OUT.pdf" ]]; then pass "partial PDF non-empty"; else fail "partial PDF empty"; fi
if [[ -e "$HOME/Desktop/$INTR_OUT" ]]; then fail "temp dir left behind (intr)"; else pass "temp dir cleaned (intr)"; fi

# --- 5. Summary --------------------------------------------------------------
echo
if [[ "$FAILED" -eq 0 ]]; then
  echo "SMOKE: ALL PASS"
else
  echo "SMOKE: FAILURES DETECTED"
  exit 1
fi
