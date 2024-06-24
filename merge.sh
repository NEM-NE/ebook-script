#!/bin/sh

# first argument should be bookname
convert ~/Desktop/$1/*.png "$1.pdf"
convert ~/Desktop/$1/*.png "~/Desktop/{$1}/{$1}.pdf"
# rm -rf ~/Desktop/$1/*.png
echo "Checkout Your PDF in ${PWD}"
