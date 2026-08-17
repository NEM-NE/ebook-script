#!/usr/bin/env bash
# Capture orchestration: adaptive loop, temp dir, interrupt handling.
# Sourced, not executed. Requires globals: BOOK, PAGES, REGION, APP_NAME.
#
# The loop is bash-driven (A3): each captured frame is hashed with
# ImageMagick; a page is committed only when its pixels changed, so the
# pace adapts to the reader instead of a fixed delay. When the frame
# stops changing after a page-turn key (SAME_LIMIT consecutive identical
# hashes), the end of the book is assumed and the run finishes —
# which also makes --pages optional (PAGES=0 means "until the end").

CAPTURE_DIR=""

# Merge whatever pages were captured so far into a partial PDF,
# then clean up the temporary directory.
on_interrupt() {
  echo ""
  echo "Interrupted."
  if [[ -n "$CAPTURE_DIR" ]] && ls "$CAPTURE_DIR"/*.png >/dev/null 2>&1; then
    echo "Merging captured pages into a partial PDF..."
    if bash "$SCRIPT_ROOT/merge.sh" "$PREFIX$BOOK"; then
      rm -rf -- "$CAPTURE_DIR"
    else
      echo "Warning: partial merge failed. PNG files are kept in $CAPTURE_DIR"
    fi
  else
    [[ -n "$CAPTURE_DIR" ]] && rm -rf -- "$CAPTURE_DIR"
  fi
  exit 130
}

# Pixel hash of an image via ImageMagick (prefers IM7 `magick`).
im_hash() {
  if command -v magick >/dev/null 2>&1; then
    magick identify -format '%#' "$1"
  else
    identify -format '%#' "$1"
  fi
}

run_capture() {
  local pdf_path
  pdf_path="$(pwd)/$PREFIX$BOOK.pdf"
  if [[ -f "$pdf_path" ]]; then
    printf 'A PDF with the same name already exists:\n%s\n' "$pdf_path"
    die "please choose a different book name."
  fi

  CAPTURE_DIR="$HOME/Desktop/$PREFIX$BOOK"
  mkdir -p "$CAPTURE_DIR"
  trap on_interrupt INT TERM

  local region_comma="${REGION// /,}"
  local pages_label="$PAGES"
  [[ "$PAGES" == "0" ]] && pages_label="auto"

  echo "Capturing: book='$BOOK' pages=$pages_label region=($REGION) app=$APP_NAME"
  echo "(기계를 만지지 마세요 — 페이지가 자동으로 넘어갑니다)"

  osascript "$SCRIPT_ROOT/apple/activate.applescript" "$APP_NAME"

  local i=1 same=0 prev_hash="" hash
  local pending="$CAPTURE_DIR/pending.png"
  local SETTLE=0.6 RETRY_WAIT=0.3 SAME_LIMIT=8

  while true; do
    sleep "$SETTLE"
    screencapture -x -R"$region_comma" "$pending"
    hash="$(im_hash "$pending")"

    if [[ "$hash" == "$prev_hash" ]]; then
      same=$((same+1))
      if [[ "$same" -ge "$SAME_LIMIT" ]]; then
        echo "Page stopped changing — end of book."
        break
      fi
      sleep "$RETRY_WAIT"
      continue
    fi

    # New frame: commit it as the next page
    mv "$pending" "$CAPTURE_DIR/$PREFIX$BOOK-$(printf '%05d' "$i").png"
    echo "  [$i/$pages_label] captured"
    prev_hash="$hash"
    same=0
    i=$((i+1))

    if [[ "$PAGES" != "0" && "$i" -gt "$PAGES" ]]; then
      break
    fi
    osascript "$SCRIPT_ROOT/apple/next-page.applescript" "$APP_NAME"
  done
  rm -f -- "$pending"

  bash "$SCRIPT_ROOT/merge.sh" "$PREFIX$BOOK"

  # Delete Safely
  rm -rf -- "$CAPTURE_DIR"
  echo "Done: $pdf_path"
}
