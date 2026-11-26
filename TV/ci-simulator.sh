#!/usr/bin/env bash
# KEYSTONE_TV_v1 - prints the id of an Apple TV simulator, creating one (and downloading the tvOS runtime) if needed.
set -euo pipefail
pick() {
  xcrun simctl list devices available -j | python3 -c '
import json, sys
d = json.load(sys.stdin)["devices"]
for rt in sorted((k for k in d if "tvOS" in k), reverse=True):
    for dev in d[rt]:
        if "Apple TV 4K" in dev["name"]:
            print(dev["udid"]); sys.exit(0)
'
}
UDID="$(pick || true)"
if [ -z "$UDID" ]; then
  RT="$(xcrun simctl list runtimes -j | python3 -c 'import json,sys; r=[x for x in json.load(sys.stdin)["runtimes"] if x.get("platform")=="tvOS" and x.get("isAvailable")]; print(r[-1]["identifier"] if r else "")')"
  if [ -z "$RT" ]; then
    echo "Downloading the tvOS simulator runtime." >&2
    xcodebuild -downloadPlatform tvOS >&2
    RT="$(xcrun simctl list runtimes -j | python3 -c 'import json,sys; r=[x for x in json.load(sys.stdin)["runtimes"] if x.get("platform")=="tvOS" and x.get("isAvailable")]; print(r[-1]["identifier"] if r else "")')"
  fi
  DT="$(xcrun simctl list devicetypes -j | python3 -c 'import json,sys; t=[x["identifier"] for x in json.load(sys.stdin)["devicetypes"] if "Apple-TV-4K" in x["identifier"]]; print(t[-1] if t else "")')"
  UDID="$(xcrun simctl create "CI Apple TV" "$DT" "$RT")"
fi
echo "$UDID"
