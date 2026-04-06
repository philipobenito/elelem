#!/usr/bin/env bash
#
# Installs Claude Code rules and skills from this repo.
#
# Rules (./instructions/) install to ~/.claude/rules/ (user scope) or
# <project>/.claude/rules/ (project scope). Common rules (instructions/common/*.md)
# are always-on and have no frontmatter. Language packs (instructions/<lang>/*.md)
# use YAML `paths:` frontmatter and are auto-loaded when Claude reads matching files.
#
# Skills (./skills/) install to ~/.claude/skills/ or <project>/.claude/skills/.
# The skills target directory is deleted and regenerated on each install so that
# skills removed from the repo do not linger locally.
#
# Tool-name placeholders of the form {{TOOL_NAME}} in both rules and skills are
# substituted with Claude Code tool names during install, so source files stay
# portable across harnesses.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RULES_SOURCE="$SCRIPT_DIR/instructions"
SKILLS_SOURCE="$SCRIPT_DIR/skills"

if [ ! -t 0 ]; then
  echo "Error: this script requires an interactive terminal (stdin is not a TTY)." >&2
  exit 1
fi

if [[ ! -d "$RULES_SOURCE/common" ]]; then
  echo "Error: $RULES_SOURCE/common does not exist" >&2
  exit 1
fi

# Interactive checkbox selector.
# Usage: multiselect RESULT_VAR items defaults
#   RESULT_VAR  - name of a global array variable to populate with selected items
#   items       - name of an array variable (in caller scope) with the item labels
#   defaults    - name of an array variable (in caller scope) where each element is
#                 1 (initially selected) or 0 (initially unselected)
#
# Does NOT use local -n; compatible with bash 3.2+.
# All tput calls are wrapped in || true so a dumb terminal does not abort the script.
multiselect() {
  local result_var="$1"
  local items_ref="$2"
  local defaults_ref="$3"

  # Read items and defaults via indirect expansion (bash 3.2 compatible).
  # eval into local arrays to avoid nameref.
  local items_list defaults_list
  eval "items_list=(\"\${${items_ref}[@]}\")"
  eval "defaults_list=(\"\${${defaults_ref}[@]}\")"

  local count="${#items_list[@]}"
  local -a selected
  local i
  for (( i=0; i<count; i++ )); do
    selected[$i]="${defaults_list[$i]:-0}"
  done

  local cursor=0

  # Hide cursor; restore on EXIT/INT/TERM.
  tput civis || true
  trap 'tput cnorm || true' EXIT INT TERM

  _multiselect_draw() {
    echo "Select items (↑↓ to move, space to toggle, enter to confirm):"
    for (( i=0; i<count; i++ )); do
      local mark="[ ]"
      [[ "${selected[$i]}" == "1" ]] && mark="[x]"
      if (( i == cursor )); then
        echo "> $mark ${items_list[$i]}"
      else
        echo "  $mark ${items_list[$i]}"
      fi
    done
  }

  local lines=$(( count + 1 ))   # header line + item lines

  _multiselect_draw

  while true; do
    local key
    # Read up to 3 bytes to capture escape sequences.
    IFS= read -rsn1 key
    if [[ "$key" == $'\x1b' ]]; then
      local seq1 seq2
      IFS= read -rsn1 -t 0.1 seq1 || true
      IFS= read -rsn1 -t 0.1 seq2 || true
      key="${key}${seq1}${seq2}"
    fi

    case "$key" in
      $'\x1b[A')  # up arrow
        (( cursor > 0 )) && (( cursor-- )) || true
        ;;
      $'\x1b[B')  # down arrow
        (( cursor < count - 1 )) && (( cursor++ )) || true
        ;;
      ' ')  # spacebar — toggle
        if [[ "${selected[$cursor]}" == "1" ]]; then
          selected[$cursor]=0
        else
          selected[$cursor]=1
        fi
        ;;
      ''|$'\n'|$'\r')  # enter — confirm
        break
        ;;
    esac

    # Move cursor up by $lines lines to redraw in place.
    tput cuu "$lines" || true
    _multiselect_draw
  done

  # Restore cursor.
  tput cnorm || true
  trap - EXIT INT TERM

  # Populate the caller's result variable with selected items.
  local result_items=()
  for (( i=0; i<count; i++ )); do
    [[ "${selected[$i]}" == "1" ]] && result_items+=("${items_list[$i]}")
  done
  eval "${result_var}=(\"\${result_items[@]}\")"
}

echo "Install scope:"
echo "  (p) project  -> <project>/.claude/"
echo "  (u) user     -> ~/.claude/"
read -rp "Choose [p/u]: " scope

case "$scope" in
  p|P)
    read -rp "Project path [$(pwd)]: " project_path
    project_path="${project_path:-$(pwd)}"
    if [[ ! -d "$project_path" ]]; then
      echo "Error: $project_path does not exist" >&2
      exit 1
    fi
    base="$project_path/.claude"
    ;;
  u|U)
    base="$HOME/.claude"
    echo
    echo "Warning: user-scope path-scoped rules have known issues."
    echo "  See https://github.com/anthropics/claude-code/issues/21858"
    echo "  Common rules (no frontmatter) are unaffected and will load normally."
    read -rp "Continue? [y/N]: " confirm
    [[ "$confirm" =~ ^[yY]$ ]] || { echo "Aborted."; exit 0; }
    ;;
  *)
    echo "Invalid choice." >&2
    exit 1
    ;;
esac

rules_target="$base/rules"
skills_target="$base/skills"

mkdir -p "$rules_target"

# Substitutes tool-name placeholders in every .md file under the given directory.
# Update this map when Claude Code tool names change, or when a new tool placeholder
# is introduced in any rule or skill file.
substitute_tool_names() {
  local dir="$1"
  [[ -d "$dir" ]] || return 0
  find "$dir" -type f -name '*.md' -exec perl -i -pe '
    s/\{\{ASK_USER_QUESTION_TOOL\}\}/AskUserQuestion/g;
    s/\{\{ENTER_PLAN_TOOL\}\}/EnterPlanMode/g;
    s/\{\{EXIT_PLAN_TOOL\}\}/ExitPlanMode/g;
    s/\{\{TASK_TRACKER_TOOL\}\}/TaskCreate/g;
    s/\{\{DISPATCH_AGENT_TOOL\}\}/Agent/g;
    s/\{\{INVOKE_SKILL_TOOL\}\}/Skill/g;
    s/\{\{READ_FILE_TOOL\}\}/Read/g;
    s/\{\{WRITE_FILE_TOOL\}\}/Write/g;
    s/\{\{EDIT_FILE_TOOL\}\}/Edit/g;
    s/\{\{GREP_TOOL\}\}/Grep/g;
    s/\{\{GLOB_TOOL\}\}/Glob/g;
    s/\{\{SHELL_EXEC_TOOL\}\}/Bash/g;
  ' {} +
}

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
  echo "Warning: no common instructions selected."
  read -rp "No common instructions selected. Continue anyway? [y/N]: " _confirm_common
  [[ "$_confirm_common" =~ ^[yY]$ ]] || { echo "Aborted."; exit 0; }
else
  mkdir -p "$rules_target/common"
  for _item in "${common_selected[@]}"; do
    cp "$RULES_SOURCE/common/${_item}.md" "$rules_target/common/${_item}.md"
  done
  substitute_tool_names "$rules_target/common"
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
      rm -rf "$rules_target/$pick"
      cp -r "$RULES_SOURCE/$pick" "$rules_target/$pick"
      substitute_tool_names "$rules_target/$pick"
      echo "  installed: $pick"
    done
  fi
else
  echo
  echo "No language packs found in $RULES_SOURCE (common-only install)."
fi

if [[ -d "$SKILLS_SOURCE" ]] && compgen -G "$SKILLS_SOURCE/*/" > /dev/null; then
  echo
  read -rp "Install skills from ./skills/ to $skills_target/? [Y/n]: " install_skills
  install_skills="${install_skills:-Y}"
  if [[ "$install_skills" =~ ^[yY]$ ]]; then
    echo "Installing skills -> $skills_target/"
    rm -rf "$skills_target"
    mkdir -p "$skills_target"
    cp -r "$SKILLS_SOURCE"/. "$skills_target"/
    substitute_tool_names "$skills_target"

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

echo
echo "Done."
echo "Rules:  $rules_target"
echo "Skills: $skills_target"
echo "Verify rules inside Claude Code with: /memory"
