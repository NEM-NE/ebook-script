#!/usr/bin/env bash
# Capture orchestration: temp dir, interrupt handling, osascript call.
# Sourced, not executed. Requires globals: BOOK, PAGES, REGION, APP_NAME.

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

  read -r pos_x pos_y pos_w pos_h <<< "$REGION"
  osascript "$SCRIPT_ROOT/screencapture.applescript" \
    "$PREFIX$BOOK" "$PAGES" "$pos_x" "$pos_y" "$pos_w" "$pos_h" \
    "$APP_NAME" "$SCRIPT_ROOT"

  # Delete Safely
  rm -rf -- "$CAPTURE_DIR"
  echo "Done: $pdf_path"
}
