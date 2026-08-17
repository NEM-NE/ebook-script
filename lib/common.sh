#!/usr/bin/env bash
# Shared helpers for ebook-capture. Sourced, not executed.

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PREFIX="ebook_reader_"

die() { echo "Error: $*" >&2; exit 1; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

check_environment() {
  [[ "$OSTYPE" == darwin* ]] || die "this tool is only supported on macOS"
  if command_exists magick || command_exists convert; then
    return 0
  fi
  die "ImageMagick not found. Install it first: brew install imagemagick"
}

# Raw book name (without prefix).
validate_book_name() {
  local name="$1"
  [[ -n "$name" ]] || die "book name cannot be empty"
  [[ "$name" != */* && "$name" != "." && "$name" != ".." ]] \
    || die "book name must not contain '/'"
}

validate_pages() {
  [[ "$1" =~ ^[1-9][0-9]*$ ]] || die "page count must be a positive number (got: $1)"
}

validate_region() {
  [[ "$1" =~ ^[0-9]+[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+[0-9]+$ ]] \
    || die "region must be 4 numbers separated by spaces (x y w h)"
}

# Map a user-facing app selector to the macOS application name.
# Accepts: 1 | 2 | library | ebook (and the Korean names directly).
resolve_app_name() {
  case "$1" in
    1|library|교보도서관) echo "교보도서관" ;;
    2|ebook|교보eBook)    echo "교보eBook" ;;
    *) return 1 ;;
  esac
}
