#!/bin/sh

echo "Enter the book name: "
read bookName

echo "Enter the page length: "
read pageLength

# Prompt the user for the position in the format "x y w h"
echo "Enter the position (x y w h):"
read position

# Parse the position into separate variables
IFS=' ' read -r pos_x pos_y pos_w pos_h <<< "$position"

osascript ./kyobo.applescript "$bookName" "$pageLength" "$pos_x" "$pos_y" "$pos_w" "$pos_h"
