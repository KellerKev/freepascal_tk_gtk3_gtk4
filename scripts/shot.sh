#!/usr/bin/env bash
# Launch the demo, raise the window, screenshot its rect, quit.
set -euo pipefail

out="/tmp/fpc_demo.png"
args=()
while [ $# -gt 0 ]; do
  if [ "$1" = "--out" ]; then
    shift; out="$1"; shift
  else
    args+=("$1"); shift
  fi
done

# Set a sentinel WM_CLASS so AppleScript can find the Tk window reliably.
extra_args=()
if [ "${#args[@]}" -gt 0 ]; then extra_args=("${args[@]}"); fi

./build/demo "${extra_args[@]}" &
pid=$!
sleep 1.5

# Bring the window forward.
osascript <<'APPLESCRIPT' >/dev/null 2>&1 || true
tell application "System Events"
  set procs to every process whose name contains "demo"
  if (count of procs) > 0 then
    set frontmost of first item of procs to true
  end if
end tell
APPLESCRIPT
sleep 0.7

screencapture -x "$out"
kill "$pid" 2>/dev/null || true
wait 2>/dev/null || true
echo "saved $out"
