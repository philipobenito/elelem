#!/usr/bin/env bash
#
# Installs elelem rules and skills for opencode.
#
# Rules (./rules/) install to ~/.config/opencode/rules/ (user scope) or
# <project>/.opencode/rules/ (project scope). Common rules are always-on.
# Language packs are listed in opencode.json and loaded in every session.
#
# Skills (./skills/) install to ~/.config/opencode/skills/ or
# <project>/.opencode/skills/.
#
# After install, opencode.json is written with an `instructions` glob array
# listing every installed rule directory. AGENTS.md is written with a
# human-readable preamble describing the opencode-specific behaviour.
#
# A manifest file (.elelem-manifest-opencode) in this repo tracks installed
# files for prune-on-reinstall.
#
# Tool-name placeholders of the form {{TOOL_NAME}} in rules and skills are
# substituted with opencode tool names during install.
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

OPENCODE_PLACEHOLDERS=(
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

OPENCODE_SUBSTITUTIONS=(
  'question'
  'entering plan mode (in opencode, plan mode is toggled by the user pressing Tab; ask the user to enter plan mode before reviewing the design)'
  'exiting plan mode (in opencode, the user toggles out of plan mode with Tab after approving the design; present the design and wait for explicit approval before any code edit)'
  'todowrite'
  'task'
  'skill'
  'read'
  'write'
  'edit'
  'grep'
  'glob'
  'bash'
)

_skill_resolve_dst() {
  local src="$1"
  local out="$2"
  printf '%s/%s\n' "$out" "${src#$SKILLS_SOURCE/}"
}

resolve_install_base base "$HOME/.config/opencode" ".opencode"

rules_target="$base/rules"
skills_target="$base/skills"
manifest_file="$SCRIPT_DIR/.elelem-manifest-opencode"
manifest_entries=()
instructions_globs=()

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
  substitute_tool_names "$rules_target/common" OPENCODE_PLACEHOLDERS OPENCODE_SUBSTITUTIONS
  instructions_globs+=("rules/common/*.md")
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
  echo "Note: opencode loads selected language packs in every session (no path-based activation)."
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
      substitute_tool_names "$rules_target/$pick" OPENCODE_PLACEHOLDERS OPENCODE_SUBSTITUTIONS
      instructions_globs+=("rules/$pick/*.md")
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
    substitute_tool_names "$skills_target" OPENCODE_PLACEHOLDERS OPENCODE_SUBSTITUTIONS

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

write_opencode_json() {
  local target="$1"
  shift
  local globs=("$@")

  local json_entries=""
  local i
  for (( i=0; i<${#globs[@]}; i++ )); do
    local comma=""
    (( i < ${#globs[@]} - 1 )) && comma=","
    json_entries="${json_entries}    \"${globs[$i]}\"${comma}
"
  done

  printf '{\n  "$schema": "https://opencode.ai/config.json",\n  "instructions": [\n%s  ]\n}\n' \
    "$json_entries" > "$target"
}

if (( ${#instructions_globs[@]} > 0 )); then
  write_opencode_json "$base/opencode.json" "${instructions_globs[@]}"

  pushd "$base" > /dev/null
  validate_globs_resolve "${instructions_globs[@]}"
  popd > /dev/null
else
  printf '{\n  "$schema": "https://opencode.ai/config.json",\n  "instructions": []\n}\n' > "$base/opencode.json"
fi

manifest_entries+=("opencode.json")

write_agents_md() {
  local target="$1"
  local entries_ref="$2"

  [[ "$entries_ref" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { echo "write_agents_md: invalid entries variable name: $entries_ref" >&2; return 1; }

  local entries
  eval "entries=(\"\${${entries_ref}[@]+\${${entries_ref}[@]}}\")"

  local rule_entries=()
  local entry
  for entry in "${entries[@]+"${entries[@]}"}"; do
    [[ "$entry" == rules/*/*.md ]] && rule_entries+=("$entry")
  done

  {
    printf '# Project rules\n\n'
    printf 'The following rule files apply to this project. Each entry links to the installed file relative to this AGENTS.md.\n\n'

    if (( ${#rule_entries[@]} == 0 )); then
      printf 'No rules are currently installed.\n'
      return 0
    fi

    local sorted
    sorted=$(printf '%s\n' "${rule_entries[@]}" | LC_ALL=C sort)

    local current_group=""
    local line group heading_initial heading_rest
    while IFS= read -r line; do
      group="${line#rules/}"
      group="${group%%/*}"
      if [[ "$group" != "$current_group" ]]; then
        current_group="$group"
        heading_initial="$(printf '%s' "${group:0:1}" | tr '[:lower:]' '[:upper:]')"
        heading_rest="${group:1}"
        printf '\n## %s%s\n\n' "$heading_initial" "$heading_rest"
      fi
      printf -- '- [%s](%s)\n' "$line" "$line"
    done <<< "$sorted"
  } > "$target"
}

write_agents_md "$base/AGENTS.md" manifest_entries

manifest_entries+=("AGENTS.md")

prune_stale_manifest_entries "$manifest_file" "$base" manifest_entries
write_manifest "$manifest_file" "$base" manifest_entries

echo
echo "Done."
echo "Install base:  $base"
echo "Manifest:      $manifest_file"
echo "opencode.json: $base/opencode.json"
echo "AGENTS.md:     $base/AGENTS.md"
