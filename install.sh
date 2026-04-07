#!/usr/bin/env bash
#
# Front controller for elelem installers.
#
# Prompts for which harness to install (Claude Code, opencode, or Cursor) and
# execs the corresponding installer script. The sub-scripts (install-claude.sh,
# install-opencode.sh, install-cursor.sh) remain runnable directly if you want
# to skip this prompt.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_install-common.sh"

if ! declare -F multiselect > /dev/null; then
  echo "Error: _install-common.sh did not define multiselect" >&2
  exit 1
fi

if ! { : >/dev/tty; } 2>/dev/null; then
  echo "Error: this script requires an interactive terminal (/dev/tty is not accessible)." >&2
  exit 1
fi

echo "elelem installer"
echo
echo "Which harness do you want to install?"
harness_items=("Claude Code" "opencode" "Cursor")
harness_defaults=(1 0 0)
multiselect harness_selected harness_items harness_defaults

if (( ${#harness_selected[@]} == 0 )); then
  echo "Error: no harness selected; please select exactly one (Claude Code, opencode, or Cursor) and re-run." >&2
  exit 1
fi

if (( ${#harness_selected[@]} > 1 )); then
  echo "Error: please select exactly one harness (Claude Code, opencode, or Cursor), not several. Re-run the installer and toggle only one item." >&2
  exit 1
fi

case "${harness_selected[0]}" in
  "Claude Code")
    exec "$SCRIPT_DIR/install-claude.sh"
    ;;
  "opencode")
    exec "$SCRIPT_DIR/install-opencode.sh"
    ;;
  "Cursor")
    exec "$SCRIPT_DIR/install-cursor.sh"
    ;;
  *)
    echo "Error: unrecognised harness selection: ${harness_selected[0]}" >&2
    exit 1
    ;;
esac
