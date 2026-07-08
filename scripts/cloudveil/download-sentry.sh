#!/bin/bash
# CloudVeil scripts
# Downloads Sentry.xcframework (8.41.0) into third-party/Sentry/.
# Run once after cloning, or when upgrading the Sentry version.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST="$SCRIPT_DIR/../third-party/Sentry/Sentry.xcframework"

if [ -d "$DEST" ]; then
  echo "Sentry.xcframework already present, skipping."
  exit 0
fi

TMP_DIR="$(mktemp -d)"
TMP="$TMP_DIR/Sentry.xcframework.zip"
echo "Downloading Sentry 8.41.0..."
curl -L -o "$TMP" \
  "https://github.com/getsentry/sentry-cocoa/releases/download/8.41.0/Sentry.xcframework.zip"
echo "Extracting..."
unzip -q "$TMP" -d "$SCRIPT_DIR/../third-party/Sentry/"
rm -rf "$TMP_DIR"
echo "Done: $DEST"
