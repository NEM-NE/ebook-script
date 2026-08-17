#!/usr/bin/env bash
# Capture-region helpers: auto-derive from the frontmost window and
# manage named presets. Sourced, not executed.

REGIONS_CONF="${REGIONS_CONF:-$HOME/.config/ebook-script/regions.conf}"

# Echo "x y w h" for the reader window minus margins.
#   $1 = margin (all sides, default 10)
#   $2 = app name → target that app's window (see NFD note inside);
#       empty falls back to the frontmost window
#   $3 = top margin override — excludes the reader's title/tool bar
auto_region() {
  local margin="${1:-10}"
  local top="${3:-$margin}"
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
  echo "$((wx+margin)) $((wy+top)) $((ww-2*margin)) $((wh-top-margin))"
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
