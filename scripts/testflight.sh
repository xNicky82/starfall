#!/usr/bin/env bash
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
# Archive Starfall and upload it to TestFlight.
# Requires an active Apple Developer Program team + an App Store Connect API key:
#   ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH (path to AuthKey_XXXX.p8), TEAM_ID
# Build number = git commit count, so every push produces a new TestFlight build.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${ASC_KEY_ID:?set ASC_KEY_ID}" "${ASC_ISSUER_ID:?set ASC_ISSUER_ID}" "${ASC_KEY_PATH:?set ASC_KEY_PATH}" "${TEAM_ID:?set TEAM_ID}"
BUNDLE_ID="${BUNDLE_ID:-com.xnicky82.starfall}"
BUILD_NUMBER=$(git rev-list --count HEAD)
AUTH=(-authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID" -authenticationKeyPath "$ASC_KEY_PATH")

command -v xcodegen >/dev/null && xcodegen generate >/dev/null
rm -rf build/Starfall.xcarchive build/export
xcodebuild -project Starfall.xcodeproj -scheme Starfall -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/Starfall.xcarchive \
  DEVELOPMENT_TEAM="$TEAM_ID" PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  -allowProvisioningUpdates "${AUTH[@]}" archive -quiet

cat > build/ExportOptions.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>automatic</string>
  <key>testFlightInternalTestingOnly</key><true/>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict></plist>
EOF
xcodebuild -exportArchive -archivePath build/Starfall.xcarchive -exportOptionsPlist build/ExportOptions.plist \
  -exportPath build/export -allowProvisioningUpdates "${AUTH[@]}"
echo "Uploaded Starfall build $BUILD_NUMBER to TestFlight."
