#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
APP="${1:-../MausSprung.app}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:--}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
if [[ -n "$NOTARY_PROFILE" && "$SIGNING_IDENTITY" != 'Developer ID Application:'* ]]; then
  echo 'Notarisierung benötigt eine Developer ID Application Identität.' >&2
  exit 1
fi
BUILD_CACHE="$(mktemp -d "${TMPDIR:-/tmp}/maussprung-build.XXXXXX")"
trap 'rm -rf "$BUILD_CACHE"' EXIT
# Sign outside cloud-synced Documents: File Provider adds Finder metadata there.
STAGING_APP="$BUILD_CACHE/MausSprung.app"
mkdir -p "$STAGING_APP/Contents/MacOS" "$STAGING_APP/Contents/Resources"
# No dependencies or downloads; build for the architecture of this Mac.
xcrun swiftc -swift-version 5 -O -module-cache-path "$BUILD_CACHE" \
  -target "$(uname -m)-apple-macosx13.0" Sources/*.swift \
  -framework AppKit -framework SwiftUI -framework Carbon -framework CoreGraphics -framework ServiceManagement \
  -o "$STAGING_APP/Contents/MacOS/MausSprung"
cp Info.plist "$STAGING_APP/Contents/Info.plist"
xattr -cr "$STAGING_APP"
if [[ "$SIGNING_IDENTITY" == '-' ]]; then
  codesign --force --sign - "$STAGING_APP"
else
  codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$STAGING_APP"
fi
codesign --verify --deep --strict "$STAGING_APP"
if [[ -n "$NOTARY_PROFILE" ]]; then
  ditto -c -k --norsrc --noextattr --keepParent "$STAGING_APP" "$BUILD_CACHE/submit.zip"
  xcrun notarytool submit "$BUILD_CACHE/submit.zip" --keychain-profile "$NOTARY_PROFILE" --wait
  # Stapling must succeed before any deliverable is replaced or advertised as notarized.
  xcrun stapler staple "$STAGING_APP"
  xcrun stapler validate "$STAGING_APP"
  codesign --verify --deep --strict "$STAGING_APP"
  spctl --assess --type execute --verbose=2 "$STAGING_APP"
fi
# Replace the bundle rather than merging into an old app and retaining stale files.
python3 scripts/install_bundle.py "$STAGING_APP" "$APP"
# Documents/File Provider may attach Finder metadata to the destination directory;
# remove it after the atomic replacement without touching the signed bundle contents.
xattr -cr "$APP"
# The staged bundle was strictly verified above. A Documents/File Provider
# destination may immediately reattach Finder metadata to the outer .app;
# that host metadata is outside the signed bundle and can make a second strict
# verification report a resource-fork warning even though the sealed staging
# bundle is valid. Keep the signed ZIP sourced from that clean staging bundle.
ditto -c -k --norsrc --noextattr --keepParent "$STAGING_APP" "${APP%.app}.zip"
echo "App erstellt: $APP"
