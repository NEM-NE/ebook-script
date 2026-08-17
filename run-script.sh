#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail


if [[ "${DEBUG:-}" == "true" ]]; then
  set -x
fi

if [[ "$OSTYPE" != "darwin"* ]]; then
  echo "This script is only supported on macOS"
  exit 1
fi

# Resolve the directory this script lives in, so sub-scripts work from any CWD
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check if ImageMagick's convert command is installed
if ! command_exists convert; then
  echo "ImageMagick is not installed or 'convert' command is not found. Please install ImageMagick first."
  exit 1
fi

echo "Enter the book name: "
read -r bookName

# Check invalid bookName
if [[ -z "$bookName" ]]; then
  echo "Error: book name cannot be empty."
  exit 1
fi

# Reject names that would break filesystem paths
if [[ "$bookName" == */* || "$bookName" == "." || "$bookName" == ".." ]]; then
  echo "Error: book name must not contain '/'."
  exit 1
fi

# Add prefix for safety
prefix="ebook_reader_"
target_dir="$HOME/Desktop/$prefix$bookName"

# Check duplicated BookName
pdf_path="$(pwd)/$prefix$bookName.pdf"

if [[ -f "$pdf_path" ]]; then
  printf 'A PDF with the same name already exists:\n%s\n' "$pdf_path"
  echo "Please choose a different book name."
  exit 1
fi

echo "Enter the page length: "
read -r pageLength

if ! [[ "$pageLength" =~ ^[1-9][0-9]*$ ]]; then
  echo "Error: page length must be a positive number."
  exit 1
fi

# Prompt the user for the position in the format "x y w h"
echo "Enter the position (x y w h):"
read -r position

if ! [[ "$position" =~ ^[0-9]+[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+[0-9]+$ ]]; then
  echo "Error: position must be 4 numbers separated by spaces (x y w h)."
  exit 1
fi

declare -a option_strings
option_strings[1]="교보도서관"
option_strings[2]="교보eBook"
while true; do
    echo "Select your application name"
    echo "1) 교보도서관 2) 교보ebook"
    read -r input_number

    # Check if the input number is in the list of valid options
    if [[ ${option_strings[$input_number]+_} ]]; then
        echo "You entered a valid number: ${input_number}"
        application_name=${option_strings[$input_number]}
        break
    else
        echo "Invalid number. Please try again."
    fi
done


# Parse the position into separate variables
IFS=' ' read -r pos_x pos_y pos_w pos_h <<< "$position"

mkdir -p "$target_dir"

# On SIGINT/SIGTERM, merge whatever pages were captured so far into a
# partial PDF before cleaning up the temporary directory.
on_interrupt() {
  echo ""
  echo "Interrupted."
  if ls "$target_dir"/*.png >/dev/null 2>&1; then
    echo "Merging captured pages into a partial PDF..."
    if bash "$script_dir/merge.sh" "$prefix$bookName"; then
      rm -rf -- "$target_dir"
    else
      echo "Warning: partial merge failed. PNG files are kept in $target_dir"
    fi
  else
    rm -rf -- "$target_dir"
  fi
  exit 130
}
trap on_interrupt INT TERM

osascript "$script_dir/screencapture.applescript" "$prefix$bookName" "$pageLength" "$pos_x" "$pos_y" "$pos_w" "$pos_h" "$application_name" "$script_dir"

# Delete Safely
rm -rf -- "$target_dir"
