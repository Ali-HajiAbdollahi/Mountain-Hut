#!/usr/bin/env bash
# Runs every E2E file (one per user story) in Chrome, one after the other.
# Works on Windows (Git Bash), macOS and Linux. Needs: Chrome, Flutter, Node (npx).
#
# The backend must already be running on a fresh database:
#   cd server && npm run start:e2e
#
# Usage (from the client folder):  bash e2e_test/run_e2e_chrome.sh
# ChromeDriver matching the installed Chrome is downloaded automatically (once) into
# .dart_tool/chromedriver. The app is served on port 5173, the origin the backend allows (CORS).
set -u
cd "$(dirname "$0")/.."

# ── Chrome version (major) ────────────────────────────────────────────────────
chrome_version=""
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    chrome_version=$(reg query 'HKCU\Software\Google\Chrome\BLBeacon' //v version 2>/dev/null | awk '/version/ {print $3}') ;;
  Darwin)
    chrome_version=$("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --version 2>/dev/null | awk '{print $3}') ;;
  *)
    chrome_version=$( (google-chrome --version || chromium --version) 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)+' | head -1) ;;
esac
major="${chrome_version%%.*}"
if [ -z "$major" ]; then
  echo "Chrome version not detected: using the latest stable ChromeDriver."
  major="stable"
fi

# ── ChromeDriver ──────────────────────────────────────────────────────────────
echo "Preparing ChromeDriver for Chrome $major..."
driver=$(npx --yes @puppeteer/browsers install "chromedriver@$major" --path "$PWD/.dart_tool/chromedriver" \
  | tail -1 | cut -d' ' -f2-)
if [ ! -f "$driver" ]; then
  echo "Could not download ChromeDriver."
  exit 1
fi
"$driver" --port=4444 >/dev/null 2>&1 &
driver_pid=$!
trap 'kill $driver_pid 2>/dev/null' EXIT
sleep 2

# ── Tests ─────────────────────────────────────────────────────────────────────
failed=()
for file in e2e_test/mh*_test.dart; do
  echo "=== $file ==="
  flutter drive --driver=test_driver/integration_test.dart --target="$file" \
    -d web-server --browser-name=chrome --web-port=5173 || failed+=("$file")
done

echo
if [ ${#failed[@]} -eq 0 ]; then
  echo "All E2E files passed."
else
  echo "Files with failing tests:"
  printf '  %s\n' "${failed[@]}"
  exit 1
fi
