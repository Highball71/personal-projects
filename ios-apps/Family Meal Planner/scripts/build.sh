#!/usr/bin/env bash
# Runs a fast compile-only build for Family Meal Planner on the iPhone 17
# simulator, falling back to any iOS simulator device if iPhone 17 is unavailable.

set -euo pipefail

SCHEME="Family Meal Planner"
DESTINATION="platform=iOS Simulator,name=iPhone 17"

if ! xcrun simctl list devices available | grep -q "iPhone 17"; then
  DESTINATION="platform=iOS Simulator,name=Any iOS Simulator Device"
fi

if xcodebuild build -scheme "$SCHEME" -destination "$DESTINATION"; then
  echo "PASS: Family Meal Planner build completed successfully."
else
  exit_code=$?
  echo "FAIL: Family Meal Planner build failed with exit code $exit_code."
  exit "$exit_code"
fi
