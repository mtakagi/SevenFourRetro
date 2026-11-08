#!/bin/zsh
# Launches a built SevenFour with a throwaway HOME, so the app's database,
# caches, cookies and settings go to a temporary directory instead of yours.
# The board list comes from the fake server (Tools/fakebbs.py).
#
#   Tools/run-app-with-test-home.sh [path/to/SevenFour.app] [board list URL]
#
# Defaults: build/Build/Products/Release/SevenFour.app and
# http://127.0.0.1:8765/bbsmenu.html. The temporary HOME is printed and kept
# after the app quits, so its files can be inspected.
set -eu

ROOT=${0:A:h:h}
APP=${1:-$ROOT/build/Build/Products/Release/SevenFour.app}
MENU=${2:-http://127.0.0.1:8765/bbsmenu.html}

if pgrep -x SevenFour >/dev/null; then
  echo "SevenFour is already running. Quit it first, so files and windows are not mixed up." >&2
  exit 1
fi

TEST_HOME=$(mktemp -d "${TMPDIR:-/tmp}/SevenFourHome.XXXXXX")
echo "HOME for this run: $TEST_HOME"
HOME=$TEST_HOME CFFIXED_USER_HOME=$TEST_HOME \
  "$APP/Contents/MacOS/SevenFour" -URLOfBoardTree "$MENU"
