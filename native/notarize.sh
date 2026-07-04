#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP="dist-release/Talkshot.app"
PROFILE="talkshot-notary"

if [ ! -d "$APP" ]; then
  echo "error: $APP not found. Run ./build-release.sh first." >&2
  exit 1
fi

ZIP="dist-release/Talkshot.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "Submitting for notarization (this can take a few minutes)..."
xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait

echo ""
echo "Stapling notarization ticket..."
xcrun stapler staple "$APP"

echo ""
echo "Verifying stapled ticket..."
xcrun stapler validate "$APP"
spctl -a -vvv --type execute "$APP"

rm -f "$ZIP"

DMG="dist-release/Talkshot.dmg"
rm -f "$DMG"
STAGING=$(mktemp -d)
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "Talkshot" -srcfolder "$STAGING" -ov -format UDZO "$DMG"
rm -rf "$STAGING"

echo ""
echo "Notarized and packaged: $(pwd)/$DMG"
