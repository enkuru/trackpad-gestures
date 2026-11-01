#!/bin/bash
# Builds the app and zips it into dist/ for a GitHub release.
set -euo pipefail
cd "$(dirname "$0")"

./build-app.sh
version=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Support/Info.plist)
zip="dist/TrackpadGestures-$version.zip"
mkdir -p dist
rm -f "$zip"
ditto -c -k --keepParent build/TrackpadGestures.app "$zip"
echo "$zip"
