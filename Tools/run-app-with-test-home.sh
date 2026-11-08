#!/bin/zsh
# Launches a built SevenFour with a throwaway HOME, so the app's database,
# caches and cookies go to a temporary directory instead of yours.
# The board list comes from the fake server (Tools/fakebbs.py).
#
#   Tools/run-app-with-test-home.sh [path/to/SevenFour.app] [board list URL]
#
# Defaults: build/Build/Products/Release/SevenFour.app and
# http://127.0.0.1:8765/bbsmenu.html. The temporary HOME is printed and kept
# after the app quits, so its files can be inspected.
#
# Settings (NSUserDefaults: window frames, split positions, toolbar...) are
# kept by cfprefsd under your real home whatever HOME says. So the app runs
# as a copy with its own bundle identifier, io.github.mtakagi.SevenFourRetro.test,
# whose settings are deleted when it quits; yours are never touched.
set -eu

ROOT=${0:A:h:h}
APP=${1:-$ROOT/build/Build/Products/Release/SevenFour.app}
MENU=${2:-http://127.0.0.1:8765/bbsmenu.html}
TEST_ID=io.github.mtakagi.SevenFourRetro.test

if pgrep -x SevenFour >/dev/null; then
  echo "SevenFour is already running. Quit it first, so files and windows are not mixed up." >&2
  exit 1
fi

TEST_HOME=$(mktemp -d "${TMPDIR:-/tmp}/SevenFourHome.XXXXXX")
echo "HOME for this run: $TEST_HOME"

# A copy of the app with the test bundle identifier, signed again (ad hoc)
# because the Info.plist changed.
TEST_APP=$TEST_HOME/SevenFour.app
cp -R "$APP" "$TEST_APP"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $TEST_ID" "$TEST_APP/Contents/Info.plist"
# Keeps the flags (the hardened runtime, if the app was built with it, as
# releases are) so the copy runs as the original would.
codesign --force --sign - --preserve-metadata=entitlements,flags,runtime "$TEST_APP" 2>/dev/null
echo "Bundle identifier for this run: $TEST_ID (e.g. osascript -e 'tell application id \"$TEST_ID\" to activate')"

forget_settings() {
  defaults delete "$TEST_ID" 2>/dev/null || true
  rm -f "$HOME/Library/Preferences/$TEST_ID.plist"
}
forget_settings
trap forget_settings EXIT

HOME=$TEST_HOME CFFIXED_USER_HOME=$TEST_HOME \
  "$TEST_APP/Contents/MacOS/SevenFour" -URLOfBoardTree "$MENU"
