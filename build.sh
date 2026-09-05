#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
APP="${1:-../MausSprung.app}"
BUILD_CACHE="$(mktemp -d "${TMPDIR:-/tmp}/maussprung-build.XXXXXX")"
trap 'rm -rf "$BUILD_CACHE"' EXIT
# Sign outside cloud-synced Documents: File Provider adds Finder metadata there.
STAGING_APP="$BUILD_CACHE/MausSprung.app"
mkdir -p "$STAGING_APP/Contents/MacOS" "$STAGING_APP/Contents/Resources"
# No dependencies or downloads; build for the architecture of this Mac.
xcrun swiftc -swift-version 5 -O -module-cache-path "$BUILD_CACHE" \
  -target "$(uname -m)-apple-macosx13.0" Sources/*.swift \
  -framework AppKit -framework SwiftUI -framework Carbon -framework CoreGraphics \
  -o "$STAGING_APP/Contents/MacOS/MausSprung"
cp Info.plist "$STAGING_APP/Contents/Info.plist"
xattr -cr "$STAGING_APP"
codesign --force --sign - "$STAGING_APP"
codesign --verify --deep --strict "$STAGING_APP"
ditto --norsrc --noextattr "$STAGING_APP" "$APP"
ditto -c -k --norsrc --noextattr --keepParent "$STAGING_APP" "${APP%.app}.zip"
echo "App erstellt: $APP"
