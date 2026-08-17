#!/usr/bin/env bash
# Interactive prompts for missing parameters. Sourced, not executed.
# Each prompt_* function validates the answer and sets a global:
#   BOOK / PAGES / REGION / APP_NAME

prompt_book() {
  local name=""
  while true; do
    echo "Enter the book name: "
    read -r name
    if [[ -z "$name" ]]; then
      echo "Error: book name cannot be empty."
      continue
    fi
    if [[ "$name" == */* || "$name" == "." || "$name" == ".." ]]; then
      echo "Error: book name must not contain '/'."
      continue
    fi
    break
  done
  BOOK="$name"
}

prompt_pages() {
  local pages=""
  while true; do
    echo "Enter the page length: "
    read -r pages
    if ! [[ "$pages" =~ ^[1-9][0-9]*$ ]]; then
      echo "Error: page length must be a positive number."
      continue
    fi
    break
  done
  PAGES="$pages"
}

prompt_region() {
  local pos=""
  while true; do
    echo "Enter the position (x y w h):"
    read -r pos
    if ! [[ "$pos" =~ ^[0-9]+[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+[0-9]+$ ]]; then
      echo "Error: position must be 4 numbers separated by spaces (x y w h)."
      continue
    fi
    break
  done
  REGION="$pos"
}

prompt_app() {
  local choice=""
  while true; do
    echo "Select your application name"
    echo "1) 교보도서관 2) 교보ebook"
    read -r choice
    local resolved
    if resolved="$(resolve_app_name "$choice")"; then
      APP_NAME="$resolved"
      break
    fi
    echo "Invalid number. Please try again."
  done
}
