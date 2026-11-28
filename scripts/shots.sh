#!/usr/bin/env bash
# Screenshot onboarding steps and every Orbit tab on the simulator with a seeded soul.
# Usage: scripts/shots.sh [outdir]
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
SIM="${SIM:-A5862363-0EBF-49D2-89EC-A3EF976D6A2B}"
OUT="${1:-$HOME/.hermes/cache/scratch/shots}"
BUNDLE=com.xnicky82.starfall
mkdir -p "$OUT"
xcrun simctl boot "$SIM" 2>/dev/null || true
xcodebuild -project Starfall.xcodeproj -scheme Starfall -destination "id=$SIM" -derivedDataPath build/dd build -quiet
xcrun simctl uninstall "$SIM" $BUNDLE || true
xcrun simctl install "$SIM" build/dd/Build/Products/Debug-iphonesimulator/Starfall.app
xcrun simctl launch "$SIM" $BUNDLE >/dev/null; sleep 6
xcrun simctl io "$SIM" screenshot "$OUT/attune0.png" >/dev/null 2>&1
xcrun simctl terminate "$SIM" $BUNDLE || true
D=$(xcrun simctl get_app_container "$SIM" $BUNDLE data); mkdir -p "$D/Documents"
seed() { python3 - "$D/Documents/starfall.json" "$1" <<'PY'
import json, sys
me = {"id":"11111111-2222-3333-4444-555555555555","name":"Nick","interests":{"hiking":20,"music":14,"hardware":12,"sauna":10,"astronomy":8},
      "ascended":[],"values":{"wonder":16,"kindness":10},
      "traits":{"social":-0.25,"tempo":0.5,"craft":0.5,"stance":0.5},"bornAt":786000000}
json.dump({"me": me, "bonds": [], "attuned": sys.argv[2] == "1"}, open(sys.argv[1], "w"))
PY
}
seed 0
for s in 1 2 3 4; do
  xcrun simctl launch "$SIM" $BUNDLE -attuneStep $s >/dev/null; sleep 5
  xcrun simctl io "$SIM" screenshot "$OUT/attune$s.png" >/dev/null 2>&1
  xcrun simctl terminate "$SIM" $BUNDLE || true
done
seed 1
for t in 1 0 2 3; do
  xcrun simctl launch "$SIM" $BUNDLE -orbitTab $t >/dev/null; sleep 7
  xcrun simctl io "$SIM" screenshot "$OUT/tab$t.png" >/dev/null 2>&1
  xcrun simctl terminate "$SIM" $BUNDLE || true
done
python3 - "$OUT" <<'PY'
import sys
from PIL import Image
o = sys.argv[1]
def strip(names, path):
    ims = [Image.open(f"{o}/{n}.png").convert("RGB").resize((603, 1311)) for n in names]
    S = Image.new("RGB", (613 * len(ims) - 10, 1311), (255, 0, 255))
    for i, im in enumerate(ims): S.paste(im, (613 * i, 0))
    S.save(path)
strip(["attune0", "attune1", "attune2", "attune3", "attune4"], f"{o}/attune.jpg")
strip(["tab1", "tab0", "tab2", "tab3"], f"{o}/tabs.jpg")
PY
echo "$OUT/attune.jpg $OUT/tabs.jpg"
