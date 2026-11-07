#!/bin/sh
# Usage: ./build.sh "/path/to/3D Weather Globe.app" [output.dmg]
# Applies the 1.1.5-U2B version to the app's Info.plist, re-signs it ad hoc, and builds the DMG.
set -e
APP="${1:?path to 3D Weather Globe.app}"; OUT="${2:-3D Weather Globe.dmg}"
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --deep --sign - "$APP"
pip install dmgbuild
dmgbuild -s settings.py -D app="$APP" -D guide="assets/3D Weather Globe User Guide.pdf" "3D Weather Globe" "$OUT"
