#!/bin/sh

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
read bookName

echo "Enter the page length: "
read pageLength

# Prompt the user for the position in the format "x y w h"
echo "Enter the position (x y w h):"
read position

declare -a option_strings
option_strings[1]="교보도서관"
option_strings[2]="교보eBook"
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

mkdir -p ~/Desktop/$bookName

osascript ./screencapture.applescript "$bookName" "$pageLength" "$pos_x" "$pos_y" "$pos_w" "$pos_h" "$application_name"
