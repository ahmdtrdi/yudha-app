#!/usr/bin/env bash
set -euo pipefail

flutter_bin="flutter"
if [[ -x ".flutter-sdk/bin/flutter" ]]; then
  flutter_bin=".flutter-sdk/bin/flutter"
fi

required_defines=(
  "SUPABASE_URL"
  "SUPABASE_PUBLISHABLE_KEY"
  "YUDHA_API_BASE_URL"
  "YUDHA_GAME_BASE_URL"
)

defines_file=".dart_tool/vercel-defines.env"
mkdir -p "$(dirname "${defines_file}")"
: > "${defines_file}"
trap 'rm -f "${defines_file}"' EXIT

for variable_name in "${required_defines[@]}"; do
  variable_value="${!variable_name:-}"
  if [[ -z "${variable_value}" ]]; then
    echo "Missing required build environment variable: ${variable_name}" >&2
    exit 1
  fi
  printf '%s=%s\n' "${variable_name}" "${variable_value}" >> "${defines_file}"
done

if [[ -n "${FIREBASE_WEB_VAPID_KEY:-}" ]]; then
  printf '%s=%s\n' "FIREBASE_WEB_VAPID_KEY" "${FIREBASE_WEB_VAPID_KEY}" >> "${defines_file}"
fi

"${flutter_bin}" build web \
  --release \
  --no-wasm-dry-run \
  --dart-define-from-file="${defines_file}"
