#!/usr/bin/env bash
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
# Build Starfall and install + launch it on the USB-connected iPhone.
set -euo pipefail
cd "$(dirname "$0")/.."
DEVICE_NAME="${DEVICE_NAME:-iPhone}"
command -v xcodegen >/dev/null && xcodegen generate >/dev/null
UDID=$(xcodebuild -project Starfall.xcodeproj -scheme Starfall -showdestinations 2>/dev/null \
  | grep -E "platform:iOS, arch" | grep -v Simulator | sed -E 's/.*id:([^,]+),.*/\1/' | head -1)
[ -n "$UDID" ] || { echo "No iPhone connected"; exit 1; }
xcodebuild -project Starfall.xcodeproj -scheme Starfall -destination "id=$UDID" \
  -derivedDataPath build/dd -allowProvisioningUpdates build -quiet
CORE=$(xcrun devicectl list devices 2>/dev/null | awk '/iPhone/ && (/connected/ || /available/) {print $3; exit}')
xcrun devicectl device install app --device "$CORE" build/dd/Build/Products/Debug-iphoneos/Starfall.app >/dev/null
xcrun devicectl device process launch --device "$CORE" com.xnicky82.starfall >/dev/null && echo "Starfall launched on $DEVICE_NAME"
