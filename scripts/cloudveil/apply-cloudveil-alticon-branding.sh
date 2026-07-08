#!/bin/bash
#
# Rebrands every PNG in every alternate-icon (.alticon) folder under
# Telegram/Telegram-iOS with the CloudVeil cloud logo, replacing whatever
# artwork is currently there (typically stock Telegram artwork reintroduced
# by an upstream merge). Each file is rewritten in place at its own existing
# filename and exact existing pixel dimensions, so no BUILD.bazel or Swift
# changes are needed -- the app already resolves these files by name/size.
#
# Usage: scripts/apply-cloudveil-alticon-branding.sh
#
# The master art is derived fresh each run from the CloudVeil app icon
# source (Telegram-iOS/DefaultAppIcon.xcassets/AppIconLLC.appiconset/1024.png),
# flattened to remove its alpha channel (matches the no-alpha convention of
# the existing alticon PNGs) via a lossless-at-this-size JPEG round trip.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ALTICON_PARENT="$ROOT_DIR/Telegram/Telegram-iOS"
SOURCE_ICON="$ALTICON_PARENT/DefaultAppIcon.xcassets/AppIconLLC.appiconset/1024.png"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

MASTER_PNG="$WORK_DIR/cloudveil-master.png"
sips -s format jpeg -s formatOptions 100 "$SOURCE_ICON" --out "$WORK_DIR/cloudveil-master.jpg" >/dev/null
sips -s format png "$WORK_DIR/cloudveil-master.jpg" --out "$MASTER_PNG" >/dev/null

get_pixel_width() {
  sips -g pixelWidth "$1" 2>/dev/null | awk '/pixelWidth:/{print $2}'
}

for dir in "$ALTICON_PARENT"/*.alticon; do
  [ -d "$dir" ] || continue
  name="$(basename "$dir" .alticon)"
  count=0
  for f in "$dir"/*.png; do
    [ -e "$f" ] || continue
    w="$(get_pixel_width "$f")"
    h="$(sips -g pixelHeight "$f" 2>/dev/null | awk '/pixelHeight:/{print $2}')"
    if [ -z "$w" ] || [ -z "$h" ]; then
      continue
    fi
    sips -z "$h" "$w" "$MASTER_PNG" --out "$f" >/dev/null
    count=$((count + 1))
  done
  echo "REBRANDED: $name ($count files)"
done
