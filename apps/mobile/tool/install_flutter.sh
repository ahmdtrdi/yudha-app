#!/usr/bin/env bash
set -euo pipefail

flutter_version="${FLUTTER_VERSION:-3.44.6}"
flutter_sdk_dir=".flutter-sdk"
flutter_bin="${flutter_sdk_dir}/bin/flutter"

if [[ ! -x "${flutter_bin}" ]]; then
  git clone \
    --branch "${flutter_version}" \
    --depth 1 \
    https://github.com/flutter/flutter.git \
    "${flutter_sdk_dir}"
fi

"${flutter_bin}" config --no-analytics
"${flutter_bin}" precache --web
"${flutter_bin}" pub get
