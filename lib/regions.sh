#!/usr/bin/env bash
# Capture-region helpers: auto-derive from the frontmost window and
# manage named presets. Sourced, not executed.

REGIONS_CONF="${REGIONS_CONF:-$HOME/.config/ebook-script/regions.conf}"

# Probe one frame of "x,y,w,h" (points) and refine it to the actual page
# content bounding box: rows/columns whose bright-pixel fraction is high
# are page area; the reader's tool bar and background are not. This makes
# the region independent of tool-bar height and window chrome.
# Echoes "x y w h" (points); returns 1 when detection is not confident
# (e.g. a dark cover page) so the caller can fall back to margins.
detect_content_region() {
  local rx ry rw rh app
  IFS=',' read -r rx ry rw rh <<< "$1"
  app="${2:-}"
  local probe="/tmp/ebook-region-probe.$$.png"

  # Bring the reader forward so the probe sees the page, not an overlay
  if [[ -n "$app" ]]; then
    osascript "$SCRIPT_ROOT/apple/activate.applescript" "$app" >/dev/null 2>&1 || true
    sleep 1
  fi
  screencapture -x -R"$1" "$probe"

  local w_px h_px
  read -r w_px h_px <<<"$(magick "$probe" -format '%w %h' info: 2>/dev/null)" || { rm -f "$probe"; return 1; }
  local scale
  scale="$(awk -v a="$w_px" -v b="$rw" 'BEGIN{printf "%.3f", a/b}')"

  # Per-row and per-column bright-pixel fractions (0-255) after threshold
  local rowdata coldata
  rowdata="$(magick "$probe" -alpha off -colorspace gray -threshold 75% -resize 1x${h_px}! -depth 8 txt:- 2>/dev/null | sed -n 's/^0,\([0-9]*\): (\([0-9]*\).*/\1 \2/p')"
  coldata="$(magick "$probe" -alpha off -colorspace gray -threshold 75% -resize ${w_px}x1! -depth 8 txt:- 2>/dev/null | sed -n 's/^\([0-9]*\),0: (\([0-9]*\).*/\1 \2/p')"
  rm -f "$probe"
  [[ -n "$rowdata" && -n "$coldata" ]] || return 1

  # First/last row (column) where the bright fraction reaches 40%
  local top_px bot_px left_px right_px
  top_px="$(echo "$rowdata" | awk '$2>=102{print $1; exit}')"
  bot_px="$(echo "$rowdata" | awk '$2>=102{y=$1} END{print y}')"
  left_px="$(echo "$coldata" | awk '$2>=102{print $1; exit}')"
  right_px="$(echo "$coldata" | awk '$2>=102{x=$1} END{print x}')"
  [[ -n "$top_px" && -n "$bot_px" && -n "$left_px" && -n "$right_px" ]] || return 1

  # Confidence: the detected box must be a reasonable part of the window
  if (( bot_px - top_px < h_px * 3 / 10 )) || (( right_px - left_px < w_px * 3 / 10 )); then
    return 1
  fi

  # Convert to points with a small padding, clamped to the window
  local pad=6
  local cx cy cw ch
  cx="$(awk -v x="$left_px" -v s="$scale" -v p="$pad" -v m="$rx" 'BEGIN{v=x/s-p; if(v<m)v=m; printf "%d", int(v)}')"
  cy="$(awk -v y="$top_px" -v s="$scale" -v p="$pad" -v m="$ry" 'BEGIN{v=y/s-p; if(v<m)v=m; printf "%d", int(v)}')"
  cw="$(awk -v a="$right_px" -v b="$left_px" -v s="$scale" -v p="$pad" -v m="$rx" -v w="$rw" -v cx="$cx" 'BEGIN{v=(a-b)/s+2*p; e=m+w-cx; if(v>e)v=e; if(v<1)v=1; printf "%d", int(v)}')"
  ch="$(awk -v a="$bot_px" -v b="$top_px" -v s="$scale" -v p="$pad" -v m="$ry" -v h="$rh" -v cy="$cy" 'BEGIN{v=(a-b)/s+2*p; e=m+h-cy; if(v>e)v=e; if(v<1)v=1; printf "%d", int(v)}')"
  echo "$cx $cy $cw $ch"
}

# Echo "x y w h" for the reader window minus margins.
#   $1 = margin (all sides, default 10)
#   $2 = app name → target that app's window (see NFD note inside);
#       empty falls back to the frontmost window
#   $3 = top margin override — when set, margin-based only (skips
#       content detection); otherwise the page content box is detected
#       by probing one frame, falling back to margins when unsure
auto_region() {
  local margin="${1:-10}"
  local top="${3:-}"
  local app="${2:-}"
  local bounds
  if [[ -n "$app" ]]; then
    # Match the process by BUNDLE ID, not display name: process names are
    # stored NFD-normalized on macOS, so a byte comparison with a
    # (typically NFC) script constant silently fails for Korean app names.
    local bundle_id
    bundle_id="$(osascript -e 'on run argv
id of application (item 1 of argv)
end run' "$app" 2>/dev/null)" || bundle_id=""
    if [[ -n "$bundle_id" ]]; then
      bounds="$(osascript -e 'on run argv
tell application "System Events" to tell (first application process whose bundle identifier is (item 1 of argv))
get {position, size} of front window
end tell
end run' "$bundle_id" 2>/dev/null)" || bounds=""
    fi
  fi
  if [[ -z "$bounds" ]]; then
    if [[ -n "$app" ]]; then
      die "cannot find an open window of '$app'. Open the reader and a book first, then retry."
    fi
    bounds="$(osascript -e 'tell application "System Events" to get {position, size} of front window of (first application process whose frontmost is true)')"
    if [[ -z "$bounds" ]]; then
      die "cannot read the frontmost window. Grant Accessibility permission to your terminal."
    fi
  fi
  local wx wy ww wh
  read -r wx wy ww wh <<<"$(echo "$bounds" | tr ',' ' ')"

  # Prefer live content detection (toolbar/background excluded) unless an
  # explicit --region-margin-top pins the top edge manually.
  if [[ -z "$top" ]]; then
    local detected
    if detected="$(detect_content_region "$wx,$wy,$ww,$wh" "$app")"; then
      echo "Detected page region: $detected (content detection)" >&2
      echo "$detected"
      return 0
    fi
    echo "Note: page detection unsure — using window margins." >&2
  fi

  local m_top="${top:-$margin}"
  echo "$((wx+margin)) $((wy+m_top)) $((ww-2*margin)) $((wh-m_top-margin))"
}

# Echo the stored region for preset $1, or fail.
load_region_preset() {
  [[ -f "$REGIONS_CONF" ]] || die "no saved regions yet ($REGIONS_CONF missing)"
  local line
  while read -r line; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    if [[ "$line" == "$1 "* ]]; then
      echo "${line#* }"
      return 0
    fi
  done < "$REGIONS_CONF"
  die "region preset not found: $1 (see --list-regions)"
}

# Save preset $1 = region $2 ("x y w h"), replacing any previous value.
save_region_preset() {
  local name="$1" region="$2"
  local tmp="$REGIONS_CONF.tmp"
  mkdir -p "$(dirname "$REGIONS_CONF")"
  touch "$REGIONS_CONF"
  {
    grep -v "^$name " "$REGIONS_CONF" 2>/dev/null || true
    echo "$name $region"
  } > "$tmp"
  mv "$tmp" "$REGIONS_CONF"
  echo "Region preset saved: $name = $region"
}

list_region_presets() {
  if [[ ! -f "$REGIONS_CONF" ]]; then
    echo "(no saved regions)"
    return 0
  fi
  cat "$REGIONS_CONF"
}
