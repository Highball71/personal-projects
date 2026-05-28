#!/usr/bin/env bash
# Runs the full Family Meal Planner test suite on the iPhone 17 simulator,
# falling back to any iOS simulator device if iPhone 17 is unavailable.

set -euo pipefail

SCHEME="Family Meal Planner"
DESTINATION="platform=iOS Simulator,name=iPhone 17"

if ! xcrun simctl list devices available | grep -q "iPhone 17"; then
  DESTINATION="platform=iOS Simulator,name=Any iOS Simulator Device"
fi

if xcodebuild test -scheme "$SCHEME" -destination "$DESTINATION"; then
  echo "PASS: Family Meal Planner tests completed successfully."
else
  exit_code=$?
  echo "FAIL: Family Meal Planner tests failed with exit code $exit_code."
  exit "$exit_code"
fi
