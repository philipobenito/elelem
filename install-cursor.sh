#!/usr/bin/env bash
#
# Installs elelem rules and skills for Cursor.
#
# Rules (./rules/) install to ~/.cursor/rules/ (user scope) or
# <project>/.cursor/rules/ (project scope). Common rules are always-on.
# Language packs are listed in Cursor's configuration and loaded in every session.
#
# Skills (./skills/) install to ~/.cursor/skills/ or
# <project>/.cursor/skills/.
#
# A manifest file (.elelem-manifest-cursor) in this repo tracks installed
# files for prune-on-reinstall.
#
# Tool-name placeholders of the form {{TOOL_NAME}} in rules and skills are
# substituted with Cursor tool names during install.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RULES_SOURCE="$SCRIPT_DIR/rules"
SKILLS_SOURCE="$SCRIPT_DIR/skills"

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_install-common.sh"

CURSOR_PLACEHOLDERS=(
  'READ_FILE_TOOL'
  'WRITE_FILE_TOOL'
  'EDIT_FILE_TOOL'
  'GREP_TOOL'
  'GLOB_TOOL'
  'SHELL_EXEC_TOOL'
  'ASK_USER_QUESTION_TOOL'
  'INVOKE_SKILL_TOOL'
  'TASK_TRACKER_TOOL'
  'ENTER_PLAN_TOOL'
  'EXIT_PLAN_TOOL'
  'DISPATCH_AGENT_TOOL'
)

CURSOR_SUBSTITUTIONS=(
  'Read'
  'Write'
  'StrReplace'
  'Grep'
  'Glob'
  'Shell'
  'AskQuestion'
  'invoking a skill (in Cursor, skills are auto-discovered or invoked by the user with a /skill-name slash command; reference skills by name and rely on auto-discovery)'
  'tracking tasks (no native task tracker in Cursor; maintain the task list inline in the conversation)'
  'entering plan mode (unavailable in Cursor; treat the design-before-implementation rule as a step you enforce manually)'
  'exiting plan mode (unavailable in Cursor; present the design and ask for explicit approval before any code edit)'
  'dispatching a subagent (unavailable in Cursor; perform the work inline within this conversation, applying the same procedure)'
)

# Canonicalises a path, following symlinks and handling non-existent directories.
# Tries realpath -m (GNU) first, falls back to macOS realpath on existing directories.
_canonicalise_path() {
  local path="$1"
  local canonical

  # Try realpath -m (GNU Linux) - works for non-existent paths
  if canonical="$(realpath -m "$path" 2>/dev/null)"; then
    printf '%s\n' "$canonical"
    return 0
  fi

  # Fallback for macOS: try realpath directly (follows symlinks, requires path to exist)
  if canonical="$(realpath "$path" 2>/dev/null)"; then
    printf '%s\n' "$canonical"
    return 0
  fi

  # Path doesn't exist: resolve the parent directory and reconstruct
  local parent dir_part
  parent="$(dirname "$path")"
  dir_part="$(basename "$path")"

  if [[ -d "$parent" ]]; then
    parent="$(realpath "$parent")"
    printf '%s\n' "$parent/$dir_part"
    return 0
  fi

  # Parent doesn't exist either; recurse
  parent="$(_canonicalise_path "$parent")"
  printf '%s\n' "$parent/$dir_part"
  return 0
}

# Asserts that the planned install paths under `base` do not resolve under
# any guarded paths (user-scope or project-scope .claude directories).
# Usage: cursor_assert_not_under_claude base
#   base - resolved install base path
#
# Computes planned paths: $base/rules and $base/skills.
# Computes guarded paths: $HOME/.claude/rules, $HOME/.claude/skills, and
# (if base is project-scope) <project>/.claude/rules and <project>/.claude/skills.
#
# For each pair, canonicalises both paths and asserts that the planned path
# is neither equal to nor a descendant of the guarded path.
# On failure, prints ERROR to stderr and returns non-zero (does not exit).
cursor_assert_not_under_claude() {
  local base="$1"

  local planned_rules="$base/rules"
  local planned_skills="$base/skills"

  local guarded_paths=()

  # Always guard user-scope .claude
  guarded_paths+=("$HOME/.claude/rules")
  guarded_paths+=("$HOME/.claude/skills")

  # If base is project-scope (does not start with $HOME/.cursor), also guard
  # the project-level .claude directories.
  if [[ ! "$base" =~ ^"$HOME"/.cursor ]]; then
    local project_root
    project_root="${base%/.cursor}"
    guarded_paths+=("$project_root/.claude/rules")
    guarded_paths+=("$project_root/.claude/skills")
  fi

  local planned_canonical_rules
  local planned_canonical_skills
  planned_canonical_rules="$(_canonicalise_path "$planned_rules")"
  planned_canonical_skills="$(_canonicalise_path "$planned_skills")"

  local guarded_path guarded_canonical
  for guarded_path in "${guarded_paths[@]}"; do
    guarded_canonical="$(_canonicalise_path "$guarded_path")"

    # Check rules path
    if [[ "$planned_canonical_rules" == "$guarded_canonical" ]] || \
       [[ "$planned_canonical_rules/" == "$guarded_canonical"/* ]]; then
      echo "ERROR: Refusing to install Cursor files to $planned_canonical_rules." >&2
      echo "This path resolves under $guarded_canonical, which is owned by the Claude Code installer." >&2
      echo "Sharing this directory would silently corrupt installed Claude Code rules or skills because the" >&2
      echo "Cursor installer rewrites tool placeholders into the copies it writes." >&2
      echo "Choose a different scope or fix your Cursor configuration so .cursor/ is read." >&2
      return 1
    fi

    # Check skills path
    if [[ "$planned_canonical_skills" == "$guarded_canonical" ]] || \
       [[ "$planned_canonical_skills/" == "$guarded_canonical"/* ]]; then
      echo "ERROR: Refusing to install Cursor files to $planned_canonical_skills." >&2
      echo "This path resolves under $guarded_canonical, which is owned by the Claude Code installer." >&2
      echo "Sharing this directory would silently corrupt installed Claude Code rules or skills because the" >&2
      echo "Cursor installer rewrites tool placeholders into the copies it writes." >&2
      echo "Choose a different scope or fix your Cursor configuration so .cursor/ is read." >&2
      return 1
    fi
  done

  return 0
}

# Main installer flow (only run if script is executed directly, not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if ! { : >/dev/tty; } 2>/dev/null; then
    echo "Error: this script requires an interactive terminal (/dev/tty is not accessible)." >&2
    exit 1
  fi

  if [[ ! -d "$RULES_SOURCE/common" ]]; then
    echo "Error: $RULES_SOURCE/common does not exist" >&2
    exit 1
  fi

  resolve_install_base base "$HOME/.cursor" ".cursor"
  cursor_assert_not_under_claude "$base" || exit 1

  echo
  echo "PENDING: Rules and skills installation to be implemented in later tasks."
  echo "Install base: $base"
  exit 0
fi
