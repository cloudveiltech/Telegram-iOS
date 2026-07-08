#!/bin/bash
# CloudVeil scripts
# Uploads dSYMs to Sentry for symbolication.
set -euo pipefail

sentry-cli debug-files upload --auth-token $SENTRY_TOKEN \
  --org cloudveil-technology \
  --project cvm-ios \
  ../../build-output
