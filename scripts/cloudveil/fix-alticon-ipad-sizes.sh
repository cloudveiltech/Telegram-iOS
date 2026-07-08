#!/bin/bash
#
# Detects and fixes missing iPad-sized (152x152, 167x167) icons in the
# alternate-icon (.alticon) folders under Telegram/Telegram-iOS.
#
# Background: `alticonstool.py` (build-system/bazel-rules/rules_apple/tools/alticonstool)
# writes the same derived CFBundleIconFiles list into both CFBundleIcons and
# CFBundleIcons~ipad for every alternate icon set. If a .alticon folder only
# contains iPhone-sized PNGs (120x120 / 180x180), Apple flags it during App
# Store Connect validation with ITMS-90892 ("Missing recommended icon ...
# for iPad"). This script scans every .alticon folder, and for any that are
# missing a 152x152 and/or 167x167 PNG, generates one by downsampling the
# largest existing PNG for that icon (never upscales). Safe to re-run --
# folders that already have both sizes are left untouched.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ALTICON_PARENT="$ROOT_DIR/Telegram/Telegram-iOS"

get_pixel_width() {
  sips -g pixelWidth "$1" 2>/dev/null | awk '/pixelWidth:/{print $2}'
}

# Returns the largest PNG in "$1" whose filename (stripped of an @Nx suffix)
# equals "$2", or the largest PNG in the folder overall as a fallback.
find_source_png() {
  local dir="$1" name="$2"
  local best="" best_size=0
  for f in "$dir"/*.png; do
    [ -e "$f" ] || continue
    local base
    base="$(basename "$f")"
    base="${base%%@*}"
    base="${base%.png}"
    if [ "$base" = "$name" ]; then
      local w
      w="$(get_pixel_width "$f")"
      [ -z "$w" ] && continue
      if [ "$w" -gt "$best_size" ]; then
        best="$f"
        best_size="$w"
      fi
    fi
  done
  if [ -z "$best" ]; then
    for f in "$dir"/*.png; do
      [ -e "$f" ] || continue
      local w
      w="$(get_pixel_width "$f")"
      [ -z "$w" ] && continue
      if [ "$w" -gt "$best_size" ]; then
        best="$f"
        best_size="$w"
      fi
    done
  fi
  echo "$best"
}

has_size() {
  local dir="$1" target="$2"
  for f in "$dir"/*.png; do
    [ -e "$f" ] || continue
    local w
    w="$(get_pixel_width "$f")"
    if [ "$w" = "$target" ]; then
      return 0
    fi
  done
  return 1
}

exit_code=0

for dir in "$ALTICON_PARENT"/*.alticon; do
  [ -d "$dir" ] || continue
  name="$(basename "$dir" .alticon)"

  missing_sizes=()
  has_size "$dir" 152 || missing_sizes+=(152)
  has_size "$dir" 167 || missing_sizes+=(167)

  if [ "${#missing_sizes[@]}" -eq 0 ]; then
    echo "OK: $name"
    continue
  fi

  source_png="$(find_source_png "$dir" "$name")"
  if [ -z "$source_png" ]; then
    echo "SKIPPED: $name (no source PNG found in $dir)"
    exit_code=1
    continue
  fi
  source_width="$(get_pixel_width "$source_png")"

  written=()
  for target in "${missing_sizes[@]}"; do
    if [ "$source_width" -lt "$target" ]; then
      echo "SKIPPED: $name ${target}x${target} (source $(basename "$source_png") is only ${source_width}x${source_width}, refusing to upscale)"
      exit_code=1
      continue
    fi
    if [ "$target" -eq 152 ]; then
      out="$dir/${name}Ipad@2x.png"
    else
      out="$dir/${name}LargeIpad@2x.png"
    fi
    sips -z "$target" "$target" "$source_png" --out "$out" >/dev/null
    written+=("$(basename "$out")")
  done

  if [ "${#written[@]}" -gt 0 ]; then
    echo "FIXED: $name (wrote ${written[*]}, downsampled from $(basename "$source_png"))"
  fi
done

exit $exit_code
