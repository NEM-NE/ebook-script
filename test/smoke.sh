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
AUTO_NAME="smoke_auto"
FULL_OUT="ebook_reader_$FULL_NAME"
INTR_OUT="ebook_reader_$INTR_NAME"
AUTO_OUT="ebook_reader_$AUTO_NAME"
FAILED=0

pass() { echo "[PASS] $1"; }
fail() { echo "[FAIL] $1"; FAILED=1; }

cleanup() {
  # Close only the windows this test opened, then quit Preview if idle
  osascript -e 'tell application "Preview" to close (every window whose name contains "smokebook")' >/dev/null 2>&1 || true
  osascript -e 'tell application "Preview" to if (count of windows) is 0 then quit' >/dev/null 2>&1 || true
  rm -rf "$WORK" "$HOME/Desktop/$FULL_OUT" "$HOME/Desktop/$INTR_OUT" "$HOME/Desktop/$AUTO_OUT" 2>/dev/null || true
}
trap cleanup EXIT

# Count captured PNGs without tripping errexit/pipefail when none exist yet
# Count committed pages only (pending.png is an in-flight scratch file)
count_pngs() {
  ls -1 "$HOME/Desktop/$1" 2>/dev/null | grep -c -- '-[0-9]*\.png$' || true
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
kill -TERM "$PID2" 2>/dev/null || true
pkill -TERM -P "$PID2" 2>/dev/null || true
# Why TERM, not INT: a non-interactive shell that backgrounds a job leaves
# the child's SIGINT ignored-at-startup (untrappable by bash), so kill -INT
# from this harness would be silently discarded and the run complete
# normally. SIGTERM reaches the same trap handler (INT TERM) and exercises
# the partial-merge + resume path; a real terminal Ctrl-C hits INT with a
# normal disposition, which the handler also covers.
RC=0
wait "$PID2" 2>/dev/null || RC=$?
echo "== interrupted after ~$PAGES_AT_KILL page(s), exit code $RC"

if [[ -f "$WORK/intr/$INTR_OUT.pdf" ]]; then pass "partial PDF created"; else fail "partial PDF missing"; fi
if [[ -s "$WORK/intr/$INTR_OUT.pdf" ]]; then pass "partial PDF non-empty"; else fail "partial PDF empty"; fi
if [[ -d "$HOME/Desktop/$INTR_OUT" ]] && ls "$HOME/Desktop/$INTR_OUT"/*.png >/dev/null 2>&1; then
  pass "PNG dir kept for resume (intr)"
else
  fail "PNG dir missing — cannot resume (intr)"
fi

# --- 4b. TEST 2b: resume the interrupted run to completion --------------------
echo "== TEST 2b: --resume completes the book"
# region/app intentionally omitted — resume must reuse the stored values
( cd "$WORK/intr" && exec env EBOOK_APP_NAME=Preview "$ROOT/bin/ebook-capture" \
    --book "$INTR_NAME" --pages "$PAGES" --resume > resume.log 2>&1 ) &
PID2B=$!
MAXR=0
while kill -0 "$PID2B" 2>/dev/null; do
  C="$(count_pngs "$INTR_OUT")"
  if [[ "$C" -gt "$MAXR" ]]; then MAXR="$C"; fi
  sleep 0.2
done
wait "$PID2B" 2>/dev/null || true
echo "--- resume log ---"
cat "$WORK/intr/resume.log" 2>/dev/null || true

if [[ -f "$WORK/intr/$INTR_OUT.pdf" ]]; then pass "resumed PDF created"; else fail "resumed PDF missing"; fi
# Preview's arrow key scrolls fractionally and swallows key events around
# focus changes, so "how many more pages" is stand-in-dependent. What must
# hold: resume detected the last committed page and continued from there.
# Exact per-page resume progression is verified by real-e2e (discrete paging).
if grep -q "Resuming from page" "$WORK/intr/resume.log" 2>/dev/null; then
  pass "resume detected prior pages: $(grep -m1 'Resuming from' "$WORK/intr/resume.log")"
else
  fail "resume did not detect prior pages"
fi
if [[ "$MAXR" -gt "$PAGES_AT_KILL" ]]; then
  echo "  (note: resume also progressed $PAGES_AT_KILL -> $MAXR pages)"
fi
if [[ -e "$HOME/Desktop/$INTR_OUT" ]]; then fail "temp dir left behind (resume)"; else pass "temp dir cleaned (resume)"; fi

# --- 5. TEST 3: auto page count + post-processing -----------------------------
echo "== TEST 3: --pages auto (end-of-book stop) + --resize 50"
# Fresh copy → Preview opens it at page 1 (no saved position)
cp "$BOOK_PDF" "$WORK/smokebook_auto.pdf"
open -a Preview "$WORK/smokebook_auto.pdf"
sleep 3
( cd "$WORK" && exec env EBOOK_APP_NAME=Preview "$ROOT/bin/ebook-capture" \
    --book "$AUTO_NAME" --pages auto --region "$POS" --app 1 --resize 50 \
    >/dev/null 2>&1 ) &
PID3=$!
MAXA=0
while kill -0 "$PID3" 2>/dev/null; do
  C="$(count_pngs "$AUTO_OUT")"
  if [[ "$C" -gt "$MAXA" ]]; then MAXA="$C"; fi
  sleep 0.2
done
wait "$PID3" 2>/dev/null || true

if [[ -f "$WORK/$AUTO_OUT.pdf" ]]; then pass "auto PDF created"; else fail "auto PDF missing"; fi
if [[ "$MAXA" -ge "$PAGES" ]]; then
  pass "auto-stop captured $MAXA pages (>= $PAGES)"
else
  fail "auto-stop captured only $MAXA/$PAGES pages"
fi
if [[ -e "$HOME/Desktop/$AUTO_OUT" ]]; then fail "temp dir left behind (auto)"; else pass "temp dir cleaned (auto)"; fi

# --- 6. Summary --------------------------------------------------------------
echo
if [[ "$FAILED" -eq 0 ]]; then
  echo "SMOKE: ALL PASS"
else
  echo "SMOKE: FAILURES DETECTED"
  exit 1
fi
