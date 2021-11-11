#!/bin/bash
export SENTRY_ORG=sentry
export SENTRY_PROJECT=cvm-ios
export SENTRY_URL=https://sentry.cloudveil.org/
export SENTRY_AUTH_TOKEN=ef543df4eaa94b9aac3f5ccf401ec4af0bff27599fa94fc5b0856cfc46420c52
sentry-cli upload-dif "$1"/*.dSYM 
