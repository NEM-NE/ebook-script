#!/usr/bin/env bash
# Capture orchestration: adaptive loop, resume, post-process, interrupts.
# Sourced, not executed. Requires globals: BOOK, PAGES, REGION, APP_NAME.
# Optional globals: RESUME(0/1), RESIZE("" or "N%"), GRAY(0/1).
#
# The loop is bash-driven (A3): each captured frame is hashed with
# ImageMagick; a page is committed only when its pixels changed, so the
# pace adapts to the reader instead of a fixed delay. When the frame
# stops changing after a page-turn key (SAME_LIMIT consecutive identical
# hashes), the end of the book is assumed and the run finishes —
# which also makes --pages optional (PAGES=0 means "until the end").
#
# Resume (A4): an interrupted run keeps its PNG directory, so
# `--resume` continues from the last captured page (page number and the
# previous frame hash are derived from the existing PNG files).

CAPTURE_DIR=""

# Merge whatever pages were captured so far into a partial PDF.
# The PNG directory is KEPT so the run can be resumed later.
on_interrupt() {
  echo ""
  echo "Interrupted."
  if [[ -n "$CAPTURE_DIR" ]] && ls "$CAPTURE_DIR"/*.png >/dev/null 2>&1; then
    echo "Merging captured pages into a partial PDF..."
    bash "$SCRIPT_ROOT/merge.sh" "$PREFIX$BOOK" \
      || echo "Warning: partial merge failed. PNG files are kept in $CAPTURE_DIR"
    echo "이어서 하려면:  bin/ebook-capture --book '$BOOK' --resume (나머지 옵션 동일하게)"
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

# Post-process captured PNGs in place (A6): optional resize / grayscale.
apply_postprocess() {
  local args=()
  if [[ -n "$RESIZE" ]]; then
    args+=(-resize "$RESIZE")
  fi
  if [[ "$GRAY" == "1" ]]; then
    args+=(-colorspace Gray)
  fi
  if [[ ${#args[@]} -eq 0 ]]; then
    return 0
  fi
  echo "Post-processing (resize=${RESIZE:-no} gray=$GRAY)..."
  if command -v magick >/dev/null 2>&1; then
    magick mogrify "${args[@]}" "$CAPTURE_DIR"/*.png
  else
    mogrify "${args[@]}" "$CAPTURE_DIR"/*.png
  fi
}

run_capture() {
  CAPTURE_DIR="$HOME/Desktop/$PREFIX$BOOK"
  local pdf_path
  pdf_path="$(pwd)/$PREFIX$BOOK.pdf"

  local start_i=1 prev_hash=""
  if [[ -d "$CAPTURE_DIR" ]] && ls "$CAPTURE_DIR"/*.png >/dev/null 2>&1; then
    # Unfinished run detected
    if [[ "$RESUME" != "1" ]]; then
      printf 'An unfinished capture exists:\n%s\n' "$CAPTURE_DIR"
      die "continue it with --resume, or remove the directory to start over."
    fi
    local last
    last="$(ls "$CAPTURE_DIR"/*.png | sed 's/.*-\([0-9]*\)\.png/\1/' | sort -n | tail -1)"
    start_i=$((10#$last + 1))
    prev_hash="$(im_hash "$CAPTURE_DIR/$PREFIX$BOOK-$last.png")"
    echo "Resuming from page $start_i (found $last captured page(s))."
    # Reuse the stored region/app when not given again
    if [[ -f "$CAPTURE_DIR/region.txt" ]]; then
      if [[ -z "$REGION" ]]; then
        REGION="$(sed -n 1p "$CAPTURE_DIR/region.txt")"
        echo "Using stored region: $REGION"
      fi
      if [[ -z "$APP_NAME" ]]; then
        APP_NAME="$(sed -n 2p "$CAPTURE_DIR/region.txt")"
        [[ -n "$APP_NAME" ]] && echo "Using stored app: $APP_NAME"
      fi
    fi
  else
    if [[ "$RESUME" == "1" ]]; then
      die "nothing to resume — no captured pages in $CAPTURE_DIR"
    fi
    if [[ -f "$pdf_path" ]]; then
      printf 'A PDF with the same name already exists:\n%s\n' "$pdf_path"
      die "please choose a different book name."
    fi
    mkdir -p "$CAPTURE_DIR"
    printf '%s\n%s\n' "$REGION" "$APP_NAME" > "$CAPTURE_DIR/region.txt"
  fi
  trap on_interrupt INT TERM

  local region_comma="${REGION// /,}"
  local pages_label="$PAGES"
  [[ "$PAGES" == "0" ]] && pages_label="auto"

  echo "Capturing: book='$BOOK' pages=$pages_label region=($REGION) app=$APP_NAME"
  echo "(기계를 만지지 마세요 — 페이지가 자동으로 넘어갑니다)"

  osascript "$SCRIPT_ROOT/apple/activate.applescript" "$APP_NAME"

  local i=$start_i same=0 hash pending_turn=0 repress_done=0
  local pending="$CAPTURE_DIR/pending.png"
  local SETTLE=0.6 RETRY_WAIT=0.3 SAME_LIMIT=8
  local started=$SECONDS

  while true; do
    sleep "$SETTLE"
    screencapture -x -R"$region_comma" "$pending"
    hash="$(im_hash "$pending")"

    if [[ "$hash" == "$prev_hash" ]]; then
      same=$((same+1))
      if [[ "$same" -ge "$SAME_LIMIT" ]]; then
        if [[ "$pending_turn" == "1" ]]; then
          echo "Page stopped changing — end of book."
          break
        fi
        # No turn pending but the frame matches the last captured page:
        # an interrupt lost our page-turn key — send it once more,
        # after giving the reader a moment to take focus.
        if [[ "$repress_done" == "0" ]]; then
          echo "Frame unchanged without a pending turn — re-sending page-turn key..."
          osascript "$SCRIPT_ROOT/apple/activate.applescript" "$APP_NAME"
          sleep 1
          osascript "$SCRIPT_ROOT/apple/next-page.applescript" "$APP_NAME"
          pending_turn=1
          repress_done=1
          same=0
          continue
        fi
        echo "Page still unchanged — stopping (use --resume to continue later)."
        break
      fi
      sleep "$RETRY_WAIT"
      continue
    fi

    # New frame: commit it as the next page
    mv "$pending" "$CAPTURE_DIR/$PREFIX$BOOK-$(printf '%05d' "$i").png"
    prev_hash="$hash"
    same=0
    repress_done=0
    i=$((i+1))

    # Progress (A5): count + percentage/ETA when a page total is known
    local done_pages=$((i-1))
    if [[ "$PAGES" != "0" ]]; then
      local elapsed=$((SECONDS-started)) eta=0
      if [[ "$done_pages" -gt "$start_i" ]]; then
        eta=$(( (PAGES-done_pages) * elapsed / (done_pages-start_i+1) ))
      fi
      echo "  [$done_pages/$PAGES] $((done_pages*100/PAGES))% · 경과 ${elapsed}s · 예상 ${eta}s"
    else
      echo "  [$done_pages] captured"
    fi

    if [[ "$PAGES" != "0" && "$i" -gt "$PAGES" ]]; then
      break
    fi
    osascript "$SCRIPT_ROOT/apple/next-page.applescript" "$APP_NAME"
    pending_turn=1
  done
  rm -f -- "$pending"

  local committed=$((i-1))
  if [[ "$PAGES" != "0" && "$committed" -lt "$PAGES" ]]; then
    echo "WARNING: expected $PAGES pages but captured $committed — the page-turn may have stopped early. Use --resume to continue from where it stopped."
  fi

  apply_postprocess
  bash "$SCRIPT_ROOT/merge.sh" "$PREFIX$BOOK"

  # Delete Safely
  rm -rf -- "$CAPTURE_DIR"
  echo "Done: $pdf_path"
}
