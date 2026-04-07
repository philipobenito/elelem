#!/usr/bin/env bash
#
# Installs Claude Code rules and skills from this repo.
#
# Rules (./rules/) install to ~/.claude/rules/ (user scope) or
# <project>/.claude/rules/ (project scope). Common rules (rules/common/*.md)
# are always-on and have no frontmatter. Language packs (rules/<lang>/*.md)
# use YAML `paths:` frontmatter and are auto-loaded when Claude reads matching files.
#
# Skills (./skills/) install to ~/.claude/skills/ or <project>/.claude/skills/.
#
# A manifest file (.elelem-manifest-claude) in this repo tracks which files were
# installed and where. On re-install to the same target, files present in the
# old manifest but absent from the new one are removed. Files not in the
# manifest (user-created) are left untouched.
#
# Tool-name placeholders of the form {{TOOL_NAME}} in both rules and skills are
# substituted with Claude Code tool names during install, so source files stay
# portable across harnesses.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RULES_SOURCE="$SCRIPT_DIR/rules"
SKILLS_SOURCE="$SCRIPT_DIR/skills"

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_install-common.sh"

if ! { : >/dev/tty; } 2>/dev/null; then
  echo "Error: this script requires an interactive terminal (/dev/tty is not accessible)." >&2
  exit 1
fi

if [[ ! -d "$RULES_SOURCE/common" ]]; then
  echo "Error: $RULES_SOURCE/common does not exist" >&2
  exit 1
fi

CLAUDE_PLACEHOLDERS=(
  'ASK_USER_QUESTION_TOOL'
  'ENTER_PLAN_TOOL'
  'EXIT_PLAN_TOOL'
  'TASK_TRACKER_TOOL'
  'DISPATCH_AGENT_TOOL'
  'INVOKE_SKILL_TOOL'
  'READ_FILE_TOOL'
  'WRITE_FILE_TOOL'
  'EDIT_FILE_TOOL'
  'GREP_TOOL'
  'GLOB_TOOL'
  'SHELL_EXEC_TOOL'
)

CLAUDE_SUBSTITUTIONS=(
  'AskUserQuestion'
  'EnterPlanMode'
  'ExitPlanMode'
  'TaskCreate'
  'Agent'
  'Skill'
  'Read'
  'Write'
  'Edit'
  'Grep'
  'Glob'
  'Bash'
)

# Resolves a source skill file to its destination by stripping $SKILLS_SOURCE
# from the path, preserving the subdirectory structure under $out. Reads
# $SKILLS_SOURCE from the installer's global scope; do not call before
# SKILLS_SOURCE is set.
_skill_resolve_dst() {
  local src="$1"
  local out="$2"
  printf '%s/%s\n' "$out" "${src#$SKILLS_SOURCE/}"
}

resolve_install_base base "$HOME/.claude" ".claude"

rules_target="$base/rules"
skills_target="$base/skills"
manifest_file="$SCRIPT_DIR/.elelem-manifest-claude"
manifest_entries=()

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
  mkdir -p "$rules_target/common"
  install_files_from_dir "$RULES_SOURCE/common" "$rules_target/common" "rules/common" manifest_entries common_files
  substitute_tool_names "$rules_target/common" CLAUDE_PLACEHOLDERS CLAUDE_SUBSTITUTIONS
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
      mkdir -p "$rules_target/$pick"
      install_files_from_dir "$RULES_SOURCE/$pick" "$rules_target/$pick" "rules/$pick" manifest_entries lang_files
      substitute_tool_names "$rules_target/$pick" CLAUDE_PLACEHOLDERS CLAUDE_SUBSTITUTIONS
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
    install_files_from_dir "$SKILLS_SOURCE" "$skills_target" "skills" manifest_entries skills_files _skill_resolve_dst
    substitute_tool_names "$skills_target" CLAUDE_PLACEHOLDERS CLAUDE_SUBSTITUTIONS

    installed_skills=()
    for skill_dir in "$skills_target"/*/; do
      [[ -d "$skill_dir" ]] || continue
      installed_skills+=("$(basename "$skill_dir")")
    done
    echo "  installed ${#installed_skills[@]} skill(s): ${installed_skills[*]}"
  else
    echo "Skipped skills install."
  fi
else
  echo
  echo "No skills found in $SKILLS_SOURCE (skipping skills install)."
fi

prune_stale_manifest_entries "$manifest_file" "$base" manifest_entries
write_manifest "$manifest_file" "$base" manifest_entries

echo
echo "Done."
echo "Rules:  $rules_target"
echo "Skills: $skills_target"
echo "Verify rules inside Claude Code with: /memory"
