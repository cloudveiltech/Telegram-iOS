#!/bin/bash
#
# Renames build artifacts in build-output/ from the Telegram-branded
# filenames the build produces (e.g. Telegram.ipa, Telegram.DSYMs.zip) to
# CloudVeil-branded, build-numbered filenames (e.g. CloudVeil_490.ipa,
# CloudVeil_490.DSYMs.zip).
#
# Usage: scripts/rename-build-output.sh <build_number>

set -euo pipefail

if [ $# -ne 1 ] || [ -z "$1" ]; then
  echo "usage: $(basename "$0") <build_number>" >&2
  exit 1
fi

BUILD_NUMBER="$1"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUTPUT_DIR="$ROOT_DIR/build-output"

if [ ! -d "$OUTPUT_DIR" ]; then
  echo "error: $OUTPUT_DIR does not exist" >&2
  exit 1
fi

renamed=0
for f in "$OUTPUT_DIR"/Telegram*; do
  [ -e "$f" ] || continue
  base="$(basename "$f")"
  rest="${base#Telegram}"
  new="CloudVeil_${BUILD_NUMBER}${rest}"
  mv "$f" "$OUTPUT_DIR/$new"
  echo "RENAMED: $base -> $new"
  renamed=$((renamed + 1))
done

if [ "$renamed" -eq 0 ]; then
  echo "No Telegram-prefixed files found in $OUTPUT_DIR"
fi
