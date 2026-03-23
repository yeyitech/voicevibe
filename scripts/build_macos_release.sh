#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/macOS端/TypelessMac.xcodeproj"
SCHEME="TypelessMac"
DERIVED_DATA_PATH="$ROOT_DIR/build/macos-release"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="Typeless Mac Dev.app"
ZIP_NAME="Typeless-Mac-Dev.zip"
INSTALL_DIR="$HOME/Applications"

mkdir -p "$DIST_DIR" "$INSTALL_DIR"

if [ -d "$DIST_DIR/$APP_NAME" ]; then
  mv "$DIST_DIR/$APP_NAME" "$HOME/.Trash/$APP_NAME.$(date +%Y%m%d-%H%M%S)"
fi

if [ -f "$DIST_DIR/$ZIP_NAME" ]; then
  mv "$DIST_DIR/$ZIP_NAME" "$HOME/.Trash/$ZIP_NAME.$(date +%Y%m%d-%H%M%S)"
fi

if [ -d "$INSTALL_DIR/$APP_NAME" ]; then
  mv "$INSTALL_DIR/$APP_NAME" "$HOME/.Trash/$APP_NAME.$(date +%Y%m%d-%H%M%S)"
fi

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  build

BUILT_APP="$DERIVED_DATA_PATH/Build/Products/Release/TypelessMac.app"

if [ ! -d "$BUILT_APP" ]; then
  echo "Release app not found: $BUILT_APP" >&2
  exit 1
fi

ditto "$BUILT_APP" "$DIST_DIR/$APP_NAME"
ditto -c -k --sequesterRsrc --keepParent "$DIST_DIR/$APP_NAME" "$DIST_DIR/$ZIP_NAME"
ditto "$BUILT_APP" "$INSTALL_DIR/$APP_NAME"

echo "Built app:"
echo "  $DIST_DIR/$APP_NAME"
echo "Zip package:"
echo "  $DIST_DIR/$ZIP_NAME"
echo "Installed dev app:"
echo "  $INSTALL_DIR/$APP_NAME"
