#!/usr/bin/env bash
# Opens a file in a viewer for the human, without blocking the caller. The
# viewer is detached so this script returns immediately: nothing waits on the
# window being closed.

if [ "$#" -eq 0 ]; then
  echo "usage: ${0##*/} <file>..." >&2
  exit 1
fi

# uname -s, not -o: -o is a GNU extension that older macOS releases do not
# support, and an unsupported flag would silently fall through to the else.
if [ "$(uname -s)" = "Darwin" ]; then
  qlmanage -p "$@" >/dev/null 2>&1 & disown
else
  xdg-open "$@" >/dev/null 2>&1 & disown
fi
