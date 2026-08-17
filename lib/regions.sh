#!/usr/bin/env bash
# Capture-region helpers: auto-derive from the frontmost window and
# manage named presets. Sourced, not executed.

REGIONS_CONF="${REGIONS_CONF:-$HOME/.config/ebook-script/regions.conf}"

# Echo "x y w h" derived from the frontmost window minus $1 (margin, default 10).
# The viewer must be frontmost when this runs.
auto_region() {
  local margin="${1:-10}"
  local bounds
  bounds="$(osascript -e 'tell application "System Events" to get {position, size} of front window of (first application process whose frontmost is true)')"
  if [[ -z "$bounds" ]]; then
    die "cannot read the frontmost window. Grant Accessibility permission to your terminal, and make sure the reader is frontmost."
  fi
  local wx wy ww wh
  read -r wx wy ww wh <<<"$(echo "$bounds" | tr ',' ' ')"
  echo "$((wx+margin)) $((wy+margin)) $((ww-2*margin)) $((wh-2*margin))"
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
