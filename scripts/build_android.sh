#!/usr/bin/env bash
# Build the Android-only TEFManager Flutter app.
#
# Usage:
#   scripts/build_android.sh          # analyze + test + release APK (arm64 only)
#   scripts/build_android.sh --debug  # debug APK (arm64 only)
#
# Optional environment variables:
#   FLUTTER_BIN   flutter executable (default: flutter from PATH)
#   ANDROID_SDK   Android SDK path passed to flutter config
#   HTTP_PROXY    proxy used for Gradle/pub downloads, e.g. http://127.0.0.1:7890
set -euo pipefail

cd "$(dirname "$0")/.."

FLUTTER_BIN="${FLUTTER_BIN:-flutter}"

if ! command -v "$FLUTTER_BIN" >/dev/null 2>&1; then
  echo "flutter not found. Set FLUTTER_BIN or add it to PATH." >&2
  exit 1
fi

if [ -n "${ANDROID_SDK:-}" ]; then
  "$FLUTTER_BIN" config --android-sdk "$ANDROID_SDK" >/dev/null
fi

if [ -n "${HTTP_PROXY:-}" ]; then
  export http_proxy="$HTTP_PROXY"
  export https_proxy="$HTTP_PROXY"
  export GRADLE_OPTS="-Dhttps.proxyHost=${HTTP_PROXY#*://} -Dhttp.proxyHost=${HTTP_PROXY#*://}"
  # GRADLE_OPTS above needs host:port split; keep it simple for the common case.
  host_port="${HTTP_PROXY#*://}"
  host="${host_port%%:*}"
  port="${host_port##*:}"
  export GRADLE_OPTS="-Dhttps.proxyHost=$host -Dhttps.proxyPort=$port -Dhttp.proxyHost=$host -Dhttp.proxyPort=$port"
fi

echo "==> flutter pub get"
"$FLUTTER_BIN" pub get

if [ "${1:-}" != "--skip-checks" ]; then
  echo "==> flutter analyze"
  "$FLUTTER_BIN" analyze --no-fatal-infos
  echo "==> flutter test"
  "$FLUTTER_BIN" test
fi

if [ "${1:-}" = "--debug" ]; then
  shift || true
  echo "==> flutter build apk --debug --target-platform android-arm64"
  "$FLUTTER_BIN" build apk --debug --target-platform android-arm64 "$@"
else
  echo "==> flutter build apk --release --target-platform android-arm64"
  "$FLUTTER_BIN" build apk --release --target-platform android-arm64 "$@"
fi

echo
echo "Output:"
ls -lh build/app/outputs/flutter-apk/*.apk || true
