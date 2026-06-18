#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$ROOT_DIR"

echo "Packaging TextGrabber for local use..."
"$SCRIPT_DIR/build-app.sh" --clean --archive "$@"

echo
echo "Opening dist folder..."
open "$ROOT_DIR/dist"

echo
read -r -p "Done. Press Return to close this window." _
