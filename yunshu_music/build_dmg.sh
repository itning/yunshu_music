#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

echo "==> 构建 macOS Release..."
flutter build macos --release

RELEASE_DIR="build/macos/Build/Products/Release"
APP_PATH="$(find "$RELEASE_DIR" -maxdepth 1 -type d -name '*.app' -print -quit)"

if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "错误：在 $RELEASE_DIR 中找不到 .app" >&2
  exit 1
fi

APP_NAME="$(basename "$APP_PATH" .app)"
DMG_PATH="build/$APP_NAME.dmg"
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/yunshu-dmg.XXXXXX")"

cleanup() {
  rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

echo "==> 制作 $DMG_PATH..."
ditto "$APP_PATH" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo
echo "完成：$PROJECT_DIR/$DMG_PATH"
ls -lh "$DMG_PATH"
