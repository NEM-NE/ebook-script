#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# Usage: merge.sh <bookName>
#   <bookName> includes the "ebook_reader_" prefix.
# Merges ~/Desktop/<bookName>/*.png into <bookName>.pdf in the current directory.

if [[ $# -ne 1 || -z "$1" ]]; then
  echo "Usage: $0 <bookName>" >&2
  exit 1
fi

book_name="$1"
img_dir="$HOME/Desktop/$book_name"

# Prefer ImageMagick 7's `magick`, fall back to legacy `convert`
if command -v magick >/dev/null 2>&1; then
  im_cmd=(magick)
elif command -v convert >/dev/null 2>&1; then
  im_cmd=(convert)
else
  echo "Error: ImageMagick is not installed (need 'magick' or 'convert')." >&2
  exit 1
fi

if ! ls "$img_dir"/*.png >/dev/null 2>&1; then
  echo "Error: no PNG files found in $img_dir" >&2
  exit 1
fi

pdf_path="$(pwd)/$book_name.pdf"
"${im_cmd[@]}" "$img_dir"/*.png "$pdf_path"
echo "PDF created: $pdf_path"
