#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

pkill -x Talkshot 2>/dev/null || true

xcodegen generate

IDENTITY="Developer ID Application"
TEAM_ID=$(security find-certificate -c "$IDENTITY" -p \
  | openssl x509 -noout -subject \
  | sed -n 's#.*/OU=\([^/]*\).*#\1#p')

if [ -z "$TEAM_ID" ]; then
  echo "error: no '$IDENTITY' certificate found in keychain." >&2
  echo "Create one via Xcode -> Settings -> Accounts -> Manage Certificates -> '+' -> Developer ID Application." >&2
  exit 1
fi

ARCHIVE_PATH="build/Talkshot.xcarchive"
rm -rf "$ARCHIVE_PATH"

xcodebuild archive \
  -project Talkshot.xcodeproj \
  -scheme Talkshot \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="$IDENTITY" \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  ENABLE_HARDENED_RUNTIME=YES \
  PROVISIONING_PROFILE_SPECIFIER=""

EXPORT_OPTIONS="build/ExportOptions.plist"
cat > "$EXPORT_OPTIONS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>$TEAM_ID</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>Developer ID Application</string>
</dict>
</plist>
PLIST

rm -rf dist-release
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath dist-release \
  -exportOptionsPlist "$EXPORT_OPTIONS"

echo ""
echo "Built: $(pwd)/dist-release/Talkshot.app"
echo "Signed with: $IDENTITY (team $TEAM_ID), hardened runtime enabled, developer-id export."
