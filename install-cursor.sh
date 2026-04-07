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

# Performs placeholder substitution on a destination file using global cursor placeholder arrays.
# Usage: _cursor_substitute_placeholders dst
#   dst - absolute path to the destination file to transform in-place
# Returns 0 on success, non-zero on failure.
# Reads CURSOR_PLACEHOLDERS and CURSOR_SUBSTITUTIONS from global scope.
# MUST NOT call exit; the caller owns the abort path.
_cursor_substitute_placeholders() {
  local dst="$1"

  local placeholders substitutions
  eval "placeholders=(\"\${CURSOR_PLACEHOLDERS[@]}\")"
  eval "substitutions=(\"\${CURSOR_SUBSTITUTIONS[@]}\")"

  local count="${#placeholders[@]}"
  if (( count == 0 )); then
    return 0
  fi

  local perl_expr=""
  local i
  for (( i=0; i<count; i++ )); do
    local placeholder="${placeholders[$i]}"
    local substitution="${substitutions[$i]}"
    local escaped_substitution
    escaped_substitution="$(printf '%s\n' "$substitution" | sed 's:[\\&|]:\\&:g')"
    perl_expr="${perl_expr}s|\\{\\{${placeholder}\\}\\}|${escaped_substitution}|g; "
  done

  perl -i -pe "$perl_expr" "$dst"
  return 0
}

# Tracks the rule group (e.g. "common", "python") that the next install_files_from_dir
# call is processing. Read by _cursor_rule_resolve_dst to namespace the flat output
# basename. Cursor does not load nested rule subdirectories at user scope, so all rule
# files install flat under <base>/rules/ with an elelem-<group>- prefix to avoid
# collisions across groups and to keep the source group identifiable.
CURSOR_RULE_GROUP_PREFIX=""

# Resolves the destination path for a Cursor rule file.
# Usage: _cursor_rule_resolve_dst src output_root
#   src         - absolute path to the source file (.md)
#   output_root - absolute path to the destination root directory
# Prints output_root/elelem-<CURSOR_RULE_GROUP_PREFIX>-<basename>.mdc to stdout.
# Reads CURSOR_RULE_GROUP_PREFIX from global scope; the caller MUST set it before
# invoking install_files_from_dir for each rule group.
_cursor_rule_resolve_dst() {
  local src="$1"
  local output_root="$2"
  local basename
  basename="$(basename "$src" .md)"
  printf '%s/elelem-%s-%s.mdc\n' "$output_root" "$CURSOR_RULE_GROUP_PREFIX" "$basename"
}

# Transforms a source rule file for Cursor installation.
# Usage: _cursor_rule_transform src dst
#   src - absolute path to the source file (.md)
#   dst - absolute path to the destination file (.mdc)
# Returns 0 on success, non-zero on failure.
# MUST NOT call exit; the caller owns the abort path.
_cursor_rule_transform() {
  local src="$1"
  local dst="$2"

  if ! rewrite_frontmatter_for_cursor "$src" > "$dst"; then
    return 1
  fi

  _cursor_substitute_placeholders "$dst"
  return 0
}

# Resolves the destination path for a Cursor skill file.
# Usage: _cursor_skill_resolve_dst src output_root
#   src         - absolute path to the source file
#   output_root - absolute path to the destination root directory
# Strips $SKILLS_SOURCE/ prefix from src and prepends output_root/.
# Preserves all subdirectory structure and file extensions.
# Reads $SKILLS_SOURCE from the installer's global scope; do not call before
# SKILLS_SOURCE is set.
_cursor_skill_resolve_dst() {
  local src="$1"
  local output_root="$2"
  printf '%s/%s\n' "$output_root" "${src#$SKILLS_SOURCE/}"
}

# Transforms a source skill file for Cursor installation.
# Usage: _cursor_skill_transform src dst
#   src - absolute path to the source file
#   dst - absolute path to the destination file
# Returns 0 on success, non-zero on failure.
# Does NOT call rewrite_frontmatter_for_cursor; SKILL.md files already carry
# name: and description: frontmatter that Cursor expects and must be preserved.
# MUST NOT call exit; the caller owns the abort path.
_cursor_skill_transform() {
  local src="$1"
  local dst="$2"

  if ! cp "$src" "$dst"; then
    return 1
  fi

  _cursor_substitute_placeholders "$dst"
  return 0
}

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
  # the project-level .claude directories. String prefix comparison, not a
  # regex, so a $HOME containing regex metacharacters does not corrupt the
  # match.
  if [[ "$base" != "$HOME/.cursor" && "$base" != "$HOME/.cursor/"* ]]; then
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

  rules_target="$base/rules"
  skills_target="$base/skills"
  manifest_entries=()
  manifest_file="$SCRIPT_DIR/.elelem-manifest-cursor"
  mkdir -p "$rules_target"

  echo
  echo "Common instruction files to install:"
  common_items=()
  common_defaults=()
  for _f in "$RULES_SOURCE/common/"*.md; do
    [[ -f "$_f" ]] || continue
    _base="$(basename "$_f" .md)"
    common_items+=("$_base")
    common_defaults+=(1)
  done

  multiselect common_selected common_items common_defaults

  if (( ${#common_selected[@]} == 0 )); then
    echo "Warning: no common rules selected."
    confirm_common_items=("Continue with no common rules")
    confirm_common_defaults=(0)
    multiselect confirm_common_selected confirm_common_items confirm_common_defaults
    (( ${#confirm_common_selected[@]} > 0 )) || { echo "Aborted."; exit 0; }
  else
    common_files=()
    for _item in "${common_selected[@]}"; do
      common_files+=("${_item}.md")
    done
    CURSOR_RULE_GROUP_PREFIX="common"
    install_files_from_dir "$RULES_SOURCE/common" "$rules_target" "rules" manifest_entries common_files _cursor_rule_resolve_dst _cursor_rule_transform
    CURSOR_RULE_GROUP_PREFIX=""
    echo "  installed: ${common_selected[*]}"
  fi

  lang_dirs=()
  for dir in "$RULES_SOURCE"/*/; do
    name="$(basename "$dir")"
    [[ "$name" == "common" ]] && continue
    if compgen -G "$dir*.md" > /dev/null; then
      lang_dirs+=("$name")
    fi
  done

  if (( ${#lang_dirs[@]} > 0 )); then
    lang_defaults=()
    for _ in "${lang_dirs[@]}"; do
      lang_defaults+=(0)
    done
    echo
    echo "Language packs to install (none selected by default):"
    multiselect lang_selected lang_dirs lang_defaults

    if (( ${#lang_selected[@]} > 0 )); then
      for pick in "${lang_selected[@]}"; do
        lang_files=()
        for _f in "$RULES_SOURCE/$pick/"*.md; do
          [[ -f "$_f" ]] || continue
          lang_files+=("$(basename "$_f")")
        done
        CURSOR_RULE_GROUP_PREFIX="$pick"
        install_files_from_dir "$RULES_SOURCE/$pick" "$rules_target" "rules" manifest_entries lang_files _cursor_rule_resolve_dst _cursor_rule_transform
        CURSOR_RULE_GROUP_PREFIX=""
        echo "  installed: $pick"
      done
    fi
  else
    echo
    echo "No language packs found in $RULES_SOURCE (common-only install)."
  fi

  if [[ -d "$SKILLS_SOURCE" ]] && compgen -G "$SKILLS_SOURCE/*/" > /dev/null; then
    echo
    echo "Skills (target: $skills_target):"
    skills_items=("Install skills")
    skills_defaults=(1)
    multiselect skills_selected skills_items skills_defaults

    if (( ${#skills_selected[@]} > 0 )); then
      echo "Installing skills -> $skills_target/"
      mkdir -p "$skills_target"
      skills_files=()
      while IFS= read -r -d '' _f; do
        skills_files+=("${_f#"$SKILLS_SOURCE"/}")
      done < <(find "$SKILLS_SOURCE" -type f -print0)
      install_files_from_dir "$SKILLS_SOURCE" "$skills_target" "skills" manifest_entries skills_files _cursor_skill_resolve_dst _cursor_skill_transform
      echo "  installed ${#skills_files[@]} skill file(s)"
    else
      echo "Skipped skills install."
    fi
  else
    echo
    echo "No skills found in $SKILLS_SOURCE (skipping skills install)."
  fi

  scan_no_unsubstituted_placeholders "$rules_target" || exit 1
  scan_no_unsubstituted_placeholders "$skills_target" || exit 1

  prune_stale_manifest_entries "$manifest_file" "$base" manifest_entries
  write_manifest "$manifest_file" "$base" manifest_entries

  echo
  echo "Recommendation: disable third-party config loading in Cursor"
  echo
  echo "Cursor will, by default, also load rules and skills from"
  echo ".claude/, .codex/, and similar directories. If you have"
  echo "installed elelem for Claude Code on the same machine, Cursor"
  echo "will end up loading two copies of every rule, one with"
  echo "Claude tool names and one with Cursor tool names, producing"
  echo "incoherent guidance."
  echo
  echo "To prevent this, open:"
  echo "  Cursor Settings -> Rules, Skills, Subagents"
  echo "  -> \"Include third-party Plugins, Skills, and other configs\""
  echo "and turn it OFF."
  echo

  echo "Done."
  echo "Install base:  $base"
  echo "Manifest:      $manifest_file"
  echo
  echo "Cursor placeholder map:"
  for (( i=0; i<${#CURSOR_PLACEHOLDERS[@]}; i++ )); do
    printf '  {{%s}} -> %s\n' "${CURSOR_PLACEHOLDERS[$i]}" "${CURSOR_SUBSTITUTIONS[$i]}"
  done
fi
