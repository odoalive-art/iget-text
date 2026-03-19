#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/build-app.sh [options]

Options:
  --configuration <debug|release>   Build configuration. Default: release
  --output-dir <path>               Output directory for the app bundle. Default: ./dist
  --bundle-id <identifier>          CFBundleIdentifier. Default: com.textgrabber.app
  --version <version>               CFBundleShortVersionString. Default: 0.1.0
  --build-number <number>           CFBundleVersion. Default: git commit count or 1
  --sign-identity <identity>        codesign identity. Default: ad-hoc (-)
  --archive                         Create a zip archive next to the .app bundle
  --help                            Show this message
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

APP_NAME="TextGrabber"
PRODUCT_NAME="TextGrabber"
CONFIGURATION="release"
DIST_DIR="$ROOT_DIR/dist"
BUNDLE_ID="com.textgrabber.app"
SHORT_VERSION="0.1.0"
BUILD_NUMBER="$(git -C "$ROOT_DIR" rev-list --count HEAD 2>/dev/null || printf '1')"
SIGN_IDENTITY="-"
CREATE_ARCHIVE=false
MINIMUM_SYSTEM_VERSION="14.0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --configuration)
      CONFIGURATION="$2"
      shift 2
      ;;
    --output-dir)
      DIST_DIR="$2"
      shift 2
      ;;
    --bundle-id)
      BUNDLE_ID="$2"
      shift 2
      ;;
    --version)
      SHORT_VERSION="$2"
      shift 2
      ;;
    --build-number)
      BUILD_NUMBER="$2"
      shift 2
      ;;
    --sign-identity)
      SIGN_IDENTITY="$2"
      shift 2
      ;;
    --archive)
      CREATE_ARCHIVE=true
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

APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
EXECUTABLE_PATH="$MACOS_DIR/$APP_NAME"

echo "==> Building $PRODUCT_NAME ($CONFIGURATION)"
swift build -c "$CONFIGURATION" --product "$PRODUCT_NAME"

BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"
BUILT_PRODUCT="$BIN_DIR/$PRODUCT_NAME"

if [[ ! -x "$BUILT_PRODUCT" ]]; then
  echo "Built product not found: $BUILT_PRODUCT" >&2
  exit 1
fi

echo "==> Creating app bundle at $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$FRAMEWORKS_DIR" "$RESOURCES_DIR"
cp "$BUILT_PRODUCT" "$EXECUTABLE_PATH"
chmod +x "$EXECUTABLE_PATH"

cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>zh-Hans</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$SHORT_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.productivity</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MINIMUM_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>NSScreenCaptureUsageDescription</key>
  <string>TextGrabber needs screen capture access to let you select an area for OCR.</string>
</dict>
</plist>
EOF

printf 'APPL????' > "$CONTENTS_DIR/PkgInfo"

echo "==> Embedding Swift runtime"
xcrun swift-stdlib-tool \
  --copy \
  --platform macosx \
  --scan-executable "$EXECUTABLE_PATH" \
  --unsigned-destination "$FRAMEWORKS_DIR"

xattr -cr "$APP_DIR"

echo "==> Signing app bundle ($SIGN_IDENTITY)"
codesign_cmd=(codesign --force --deep --sign "$SIGN_IDENTITY" --timestamp=none)
if [[ "$SIGN_IDENTITY" == "-" ]]; then
  codesign_cmd+=(--requirements "=designated => identifier \"$BUNDLE_ID\"")
fi
"${codesign_cmd[@]}" "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"

if [[ "$CREATE_ARCHIVE" == true ]]; then
  ARCHIVE_PATH="$DIST_DIR/$APP_NAME-$SHORT_VERSION-macos.zip"
  echo "==> Creating archive at $ARCHIVE_PATH"
  rm -f "$ARCHIVE_PATH"
  ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ARCHIVE_PATH"
  echo "Archive: $ARCHIVE_PATH"
fi

echo "App bundle: $APP_DIR"
