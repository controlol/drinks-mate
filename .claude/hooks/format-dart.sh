#!/usr/bin/env sh
# PostToolUse hook — best-effort auto-format of the just-edited Dart file.
#
# Never fails the originating tool call (always exits 0). CI's `dart format
# --set-exit-if-changed` is the real gate; this is just convenience so edits
# land already-formatted. Requires `dart` and a POSIX shell (git bash on
# Windows). If either is missing, it silently no-ops.

command -v dart >/dev/null 2>&1 || exit 0

input=$(cat)
file=$(printf '%s' "$input" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

case "$file" in
  *.dart) dart format "$file" >/dev/null 2>&1 ;;
esac

exit 0
