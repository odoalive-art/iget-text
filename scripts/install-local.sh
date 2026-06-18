#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/install-local.sh [options]

Options:
  --launch       Launch TextGrabber after installation
  --no-build     Require an existing dist/TextGrabber.app instead of building it
  --help         Show this message
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_NAME="TextGrabber"
SOURCE_APP="$ROOT_DIR/dist/$APP_NAME.app"
DEST_APP="/Applications/$APP_NAME.app"
LAUNCH_AFTER_INSTALL=false
BUILD_IF_MISSING=true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --launch)
      LAUNCH_AFTER_INSTALL=true
      shift
      ;;
    --no-build)
      BUILD_IF_MISSING=false
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ ! -d "$SOURCE_APP" ]]; then
  if [[ "$BUILD_IF_MISSING" == true ]]; then
    "$SCRIPT_DIR/build-app.sh"
  else
    echo "Missing app bundle: $SOURCE_APP" >&2
    echo "Run scripts/build-app.sh first, or omit --no-build." >&2
    exit 1
  fi
fi

echo "==> Installing $APP_NAME to $DEST_APP"
if [[ -w "/Applications" ]]; then
  rm -rf "$DEST_APP"
  ditto "$SOURCE_APP" "$DEST_APP"
else
  sudo rm -rf "$DEST_APP"
  sudo ditto "$SOURCE_APP" "$DEST_APP"
fi

xattr -cr "$DEST_APP"
codesign --verify --deep --strict "$DEST_APP"

echo "Installed app:"
echo "  $DEST_APP"

if [[ "$LAUNCH_AFTER_INSTALL" == true ]]; then
  echo "==> Launching $APP_NAME"
  open "$DEST_APP"
else
  open -R "$DEST_APP"
fi
