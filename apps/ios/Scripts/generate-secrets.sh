#!/usr/bin/env bash
set -euo pipefail

# Generated values are bundled into the app. Server credentials never belong here.
configuration="${CONFIGURATION:-Debug}"
source_root="${SRCROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

case "$configuration" in
  Debug) env_file="$source_root/../.env.local"; prefix="" ;;
  Staging) env_file=""; prefix="STAGING_" ;;
  Release) env_file="$source_root/../.env.local.release"; prefix="PROD_" ;;
  *) printf 'Unsupported build configuration: %s\n' "$configuration" >&2; exit 1 ;;
esac

if [[ -n "$env_file" && -f "$env_file" ]]; then
  # shellcheck disable=SC1090
  source "$env_file"
fi

select_value() {
  local name="$1"
  if [[ -n "$prefix" ]]; then
    local selected="${prefix}${name}"
    printf '%s' "${!selected:-}"
  else
    printf '%s' "${!name:-}"
  fi
}

SPROUT_CLIENT_API_KEY="$(select_value API_KEY)"
SPROUT_CLIENT_API_BASE_URL="$(select_value API_BASE_URL)"
SPROUT_CLIENT_MIXPANEL_TOKEN="$(select_value MIXPANEL_PROJECT_TOKEN)"
SPROUT_CLIENT_APPSFLYER_KEY="$(select_value APPSFLYER_DEV_KEY)"
SPROUT_CLIENT_STREAM_KEY="$(select_value STREAM_API_KEY)"
SPROUT_CLIENT_ONESIGNAL_ID="$(select_value ONESIGNAL_APP_ID)"
export SPROUT_CLIENT_API_KEY SPROUT_CLIENT_API_BASE_URL SPROUT_CLIENT_MIXPANEL_TOKEN
export SPROUT_CLIENT_APPSFLYER_KEY SPROUT_CLIENT_STREAM_KEY SPROUT_CLIENT_ONESIGNAL_ID
export SPROUT_CLIENT_SOURCE_ROOT="$source_root"

python3 - <<'PY'
import os
from pathlib import Path

root = Path(os.environ["SPROUT_CLIENT_SOURCE_ROOT"])

def swift_string(value: str) -> str:
    escaped = []
    for char in value:
        if char == "\\":
            escaped.append("\\\\")
        elif char == '"':
            escaped.append('\\"')
        elif char == "\n":
            escaped.append("\\n")
        elif char == "\r":
            escaped.append("\\r")
        elif char == "\t":
            escaped.append("\\t")
        elif ord(char) < 32:
            escaped.append(f"\\u{{{ord(char):x}}}")
        else:
            escaped.append(char)
    return '"' + "".join(escaped) + '"'

fields = {
    "apiKey": "SPROUT_CLIENT_API_KEY",
    "apiBaseURL": "SPROUT_CLIENT_API_BASE_URL",
    "mixpanelProjectToken": "SPROUT_CLIENT_MIXPANEL_TOKEN",
    "appsFlyerDevKey": "SPROUT_CLIENT_APPSFLYER_KEY",
    "streamApiKey": "SPROUT_CLIENT_STREAM_KEY",
    "onesignalAppId": "SPROUT_CLIENT_ONESIGNAL_ID",
}
lines = ["// Generated client configuration. Values here are public in the app binary.", "struct Secrets {"]
lines.extend(f"    static let {name} = {swift_string(os.environ[env])}" for name, env in fields.items())
lines.append("}")
contents = "\n".join(lines) + "\n"

for relative in ("Sprout/Generated/Secrets.swift", "OneSignalNotificationServiceExtension/Generated/Secrets.swift"):
    destination = root / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(contents)
PY

printf 'Generated client configuration for %s\n' "$configuration"
