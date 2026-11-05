#!/usr/bin/env bash
# Runs every E2E file (one per user story) on the desktop app, one after the other.
# Files are run separately because the app of one file must close before the next starts.
#
# The backend must already be running on a fresh database:
#   cd server && npm run start:e2e
#
# Usage (from the client folder):  bash e2e_test/run_e2e.sh
# Other device (default windows):  DEVICE=macos bash e2e_test/run_e2e.sh
set -u
cd "$(dirname "$0")/.."
device="${DEVICE:-windows}"
failed=()

for file in e2e_test/mh*_test.dart; do
  echo "=== $file ==="
  flutter drive --driver=test_driver/integration_test.dart --target="$file" -d "$device" \
    || failed+=("$file")
done

echo
if [ ${#failed[@]} -eq 0 ]; then
  echo "All E2E files passed."
else
  echo "Files with failing tests:"
  printf '  %s\n' "${failed[@]}"
  exit 1
fi
