#!/bin/sh
set -eu
# Building or testing locally must not publish artifacts. Distribution CI opts in.
if [ "${CONFIGURATION:-}" != Release ] || [ "${PLATFORM_NAME:-}" != iphoneos ] || [ "${SPROUT_UPLOAD_DSYMS:-0}" != 1 ]; then
  exit 0
fi
if [ -z "${SENTRY_AUTH_TOKEN:-}" ]; then
  echo 'Symbol upload was requested but Sentry authentication is not configured.' >&2
  exit 1
fi
if ! command -v sentry-cli >/dev/null 2>&1; then
  echo 'Symbol upload was requested but sentry-cli is unavailable.' >&2
  exit 1
fi
export SENTRY_ORG="${SENTRY_ORG:-michael-dadi}"
export SENTRY_PROJECT="${SENTRY_PROJECT:-sprout-ios}"
# dSYMs provide symbolication. Source uploads require a separate explicit choice.
sentry-cli debug-files upload "${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}"
