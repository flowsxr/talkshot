#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

pkill -x Talkshot 2>/dev/null || true

xcodegen generate

IDENTITY="Apple Development"
TEAM_ID=$(security find-certificate -c "$IDENTITY" -p \
  | openssl x509 -noout -subject \
  | sed -n 's#.*/OU=\([^/]*\).*#\1#p')

if [ -z "$TEAM_ID" ]; then
  echo "error: no '$IDENTITY' certificate found in keychain (or its Team ID couldn't be parsed)." >&2
  echo "Create one via Xcode -> Settings -> Accounts -> Manage Certificates -> '+' -> Apple Development." >&2
  exit 1
fi

xcodebuild \
  -project Talkshot.xcodeproj \
  -scheme Talkshot \
  -configuration Release \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="$IDENTITY" \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGNING_ALLOWED=YES

APP="build/Build/Products/Release/Talkshot.app"
mkdir -p dist
rm -rf dist/Talkshot.app
cp -R "$APP" dist/Talkshot.app

echo ""
echo "Built: $(pwd)/dist/Talkshot.app"
echo "Signed with: $IDENTITY (team $TEAM_ID) — stable across rebuilds, no re-grant needed."

open dist/Talkshot.app
