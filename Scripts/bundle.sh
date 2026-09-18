#!/usr/bin/env bash
# Builds the Swift package and wraps the binary in a runnable .app bundle.
# No Xcode needed: Command Line Tools + codesign are enough.
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="NotchIsland"
CONFIG="${CONFIG:-debug}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"   # "-" = ad-hoc signature
APP="build/${APP_NAME}.app"

swift build -c "$CONFIG"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP/Contents/Info.plist"

if [ "$SIGN_IDENTITY" = "-" ]; then
  # An ad-hoc signature's default designated requirement is its exact hash, which
  # changes with every build, so macOS would ask for Automation access to Spotify
  # and Music again after each rebuild. Pin the requirement to the bundle ID.
  codesign --force --sign - --timestamp=none \
    --requirements '=designated => identifier "com.goncalopinheiro.NotchIsland"' "$APP"
else
  codesign --force --sign "$SIGN_IDENTITY" --timestamp=none "$APP"
fi
echo "Built $APP ($CONFIG, signed with '$SIGN_IDENTITY')"
