#!/usr/bin/env bash
# No installation, licence acceptance, signing changes, or upload.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-check}"
BASE_URL="${2:-https://api.korkem.asia}"
case "$MODE" in
  check|simulator|unsigned|archive) ;;
  *) echo "Usage: bash scripts/ios_on_mac.sh [check|simulator|unsigned|archive] [https://server]" >&2; exit 2 ;;
esac
if [ "$(uname -s)" != Darwin ]; then
  echo "STOP: an iOS build requires macOS and Xcode. This is not a build result." >&2
  exit 2
fi
for tool in flutter xcodebuild xcrun pod python3; do
  command -v "$tool" >/dev/null || { echo "Missing: $tool (see docs/operations/IOS_ON_MAC_RU.md)" >&2; exit 2; }
done
cd "$ROOT/mobile/korkem_flow"
flutter --version --machine | python3 -c '
import json, sys
v = json.load(sys.stdin)["frameworkVersion"]
if v != "3.44.8":
    sys.exit("STOP: expected Flutter 3.44.8, got " + v + ". Do not upgrade dependencies during first iOS build.")
print("Flutter version OK:", v)
'
python3 -c '
import sys
from urllib.parse import urlsplit
u = urlsplit(sys.argv[1])
if u.scheme != "https" or not u.hostname or u.username or u.password or u.query or u.fragment:
    sys.exit("STOP: use an HTTPS server URL without credentials, query or fragment.")
' "$BASE_URL"
xcodebuild -version
xcrun --sdk iphoneos --show-sdk-version
pod --version
python3 tool/test_ios_scaffold.py
if [ "$MODE" = check ]; then
  flutter doctor -v
  flutter devices
  exit 0
fi
flutter pub get --enforce-lockfile
DEFINES=("--dart-define=KORKEM_BASE_URL=$BASE_URL" "--dart-define=KORKEM_FLAVOR=prod")
case "$MODE" in
  simulator) flutter build ios --simulator --debug "${DEFINES[@]}" ;;
  unsigned) flutter build ios --release --no-codesign "${DEFINES[@]}" ;;
  archive) flutter build ipa --release "${DEFINES[@]}" ;;
esac
