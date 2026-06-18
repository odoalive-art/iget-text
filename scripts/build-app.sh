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
  --clean                           Remove previous app and archives before building
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
CLEAN_OUTPUT=false
MINIMUM_SYSTEM_VERSION="14.0"
ICON_FILE="TextGrabber"
ICON_SOURCE="$ROOT_DIR/Resources/$ICON_FILE.icns"
COPYRIGHT="Copyright © $(date +%Y) TextGrabber. All rights reserved."
SCREEN_CAPTURE_USAGE="TextGrabber 需要屏幕录制权限，用于选择屏幕区域并识别其中的文字。"

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
    --clean)
      CLEAN_OUTPUT=true
      shift
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
ARCHIVE_PATH="$DIST_DIR/$APP_NAME-$SHORT_VERSION-macos.zip"

if [[ "$CLEAN_OUTPUT" == true ]]; then
  echo "==> Cleaning previous local package output"
  rm -rf "$APP_DIR"
  rm -f "$DIST_DIR"/"$APP_NAME"-*-macos.zip
fi

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

if [[ -f "$ICON_SOURCE" ]]; then
  cp "$ICON_SOURCE" "$RESOURCES_DIR/$ICON_FILE.icns"
else
  echo "Warning: app icon not found at $ICON_SOURCE" >&2
fi

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
  <key>CFBundleIconFile</key>
  <string>$ICON_FILE</string>
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
  <key>NSHumanReadableCopyright</key>
  <string>$COPYRIGHT</string>
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
  <string>$SCREEN_CAPTURE_USAGE</string>
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
  echo "==> Creating archive at $ARCHIVE_PATH"
  rm -f "$ARCHIVE_PATH"
  ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ARCHIVE_PATH"
fi

echo
echo "Built app bundle:"
echo "  $APP_DIR"
if [[ "$CREATE_ARCHIVE" == true ]]; then
  echo "Built archive:"
  echo "  $ARCHIVE_PATH"
fi
