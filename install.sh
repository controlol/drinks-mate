#!/usr/bin/env bash
# Workspace initialiser — run by Coder on every workspace start.
# Safe to re-run: all steps are idempotent.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# 1. Flutter on PATH
# The Coder workspace template adds /opt/flutter/bin at provision time, but
# that injection may not reach every shell startup path (e.g. SSH sessions or
# sub-shells that don't source the Coder env). Guard-add it to .bashrc once.
# ---------------------------------------------------------------------------
FLUTTER_BIN="/opt/flutter/bin"
if [ -d "$FLUTTER_BIN" ] && ! grep -qF "$FLUTTER_BIN" "$HOME/.bashrc" 2>/dev/null; then
  printf '\n# Flutter SDK (added by drinks-mate install.sh)\nexport PATH="$PATH:%s"\n' "$FLUTTER_BIN" >> "$HOME/.bashrc"
  echo "install.sh: added $FLUTTER_BIN to ~/.bashrc"
fi

# Make sure flutter/dart are reachable for the rest of this script.
export PATH="$PATH:$FLUTTER_BIN"

# ---------------------------------------------------------------------------
# 2. Pub dependencies
# flutter pub get covers the app; the core package is a separate pure-Dart
# package that needs its own pub get so its .dart_tool/ tree is populated.
# ---------------------------------------------------------------------------
echo "install.sh: flutter pub get (flutter/)"
(cd "$REPO_ROOT/flutter" && flutter pub get)

echo "install.sh: dart pub get (flutter/packages/core)"
(cd "$REPO_ROOT/flutter/packages/core" && dart pub get)

echo "install.sh: done — workspace ready."
