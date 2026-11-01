#!/bin/bash
# Builds Trackpad Gestures, replaces the copy in ~/Applications and opens it.
set -euo pipefail
cd "$(dirname "$0")"

./build-app.sh
pkill -x TrackpadGestures || true
mkdir -p ~/Applications
rm -rf ~/Applications/TrackpadGestures.app
cp -R build/TrackpadGestures.app ~/Applications/
open ~/Applications/TrackpadGestures.app
