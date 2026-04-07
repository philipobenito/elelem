#!/usr/bin/env bash
#
# Front controller for elelem installers.
#
# Prompts for which harness to install (Claude Code, OpenCode, or Cursor) and
# execs the corresponding installer script. The sub-scripts (install-claude.sh,
# install-opencode.sh, install-cursor.sh) remain runnable directly if you want
# to skip this prompt.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_install-common.sh"

if ! declare -F singleselect > /dev/null; then
  say_err "_install-common.sh did not define singleselect"
  exit 1
fi

if ! { : >/dev/tty; } 2>/dev/null; then
  say_err "this script requires an interactive terminal (/dev/tty is not accessible)."
  exit 1
fi

say_step "elelem installer"
echo
echo "Which harness do you want to install?"
harness_items=("Claude Code" "OpenCode" "Cursor")
singleselect harness_choice harness_items 0

case "$harness_choice" in
  "Claude Code")
    exec "$SCRIPT_DIR/install-claude.sh"
    ;;
  "OpenCode")
    exec "$SCRIPT_DIR/install-opencode.sh"
    ;;
  "Cursor")
    exec "$SCRIPT_DIR/install-cursor.sh"
    ;;
  *)
    say_err "unrecognised harness selection: $harness_choice"
    exit 1
    ;;
esac
