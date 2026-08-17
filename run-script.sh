#!/usr/bin/env bash
# Backward-compatible entry point — delegates to bin/ebook-capture.
# Interactive when called with no arguments (same UX as before);
# CLI flags are passed through.

set -o errexit
set -o nounset
set -o pipefail

exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/bin/ebook-capture" "$@"
