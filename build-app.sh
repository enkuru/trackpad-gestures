#!/bin/bash
# Builds build/TrackpadGestures.app for Apple silicon and Intel Macs, signed ad hoc.
set -euo pipefail
cd "$(dirname "$0")"

# `swift build --arch` needs full Xcode; building each architecture and merging also works with the Command Line Tools.
binaries=()
for arch in arm64 x86_64; do
    swift build -c release --triple "$arch-apple-macosx14.0"
    binaries+=("$(swift build -c release --triple "$arch-apple-macosx14.0" --show-bin-path)/TrackpadGestures")
done

app=build/TrackpadGestures.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
lipo -create "${binaries[@]}" -output "$app/Contents/MacOS/TrackpadGestures"
cp Support/Info.plist "$app/Contents/"
codesign --force --sign - "$app"
