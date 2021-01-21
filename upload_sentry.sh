# Type a script or drag a script file from your workspace to insert its path.
if which sentry-cli >/dev/null; then
export SENTRY_ORG=sentry
export SENTRY_PROJECT=cvm-win
export SENTRY_URL=https://sentry.cloudveil.org/
export SENTRY_AUTH_TOKEN=ef543df4eaa94b9aac3f5ccf401ec4af0bff27599fa94fc5b0856cfc46420c52
ERROR=$(sentry-cli upload-dif "$DWARF_DSYM_FOLDER_PATH" 2>&1 >/dev/null)
if [ ! $? -eq 0 ]; then
echo "warning: sentry-cli - $ERROR"
fi
else
echo "warning: sentry-cli not installed, download from https://github.com/getsentry/sentry-cli/releases"
fi
