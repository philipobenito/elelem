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
  say_err "this script requires an interactive terminal (/dev/tty is not accessible)."
  exit 1
fi

if [[ ! -d "$RULES_SOURCE/common" ]]; then
  say_err "$RULES_SOURCE/common does not exist"
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
  'MODEL_ENUMERATION'
)

CLAUDE_SUBSTITUTIONS=(
  'AskUserQuestion'
  'EnterPlanMode'
  'ExitPlanMode'
  'TodoWrite'
  'Agent'
  'Skill'
  'Read'
  'Write'
  'Edit'
  'Grep'
  'Glob'
  'Bash'
  'reading the `model` enum on the Agent tool schema, which is the set of values the harness will accept'
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

check_agent_bundle_conflicts() {
  local target="$1"
  shift
  local roots=("$PWD/.claude/agents" "$HOME/.claude/agents" "$target")
  local root candidate identity canonical candidate_list ancestor scan_status=0
  if ! candidate_list="$(mktemp "${TMPDIR:-/tmp}/claude-agent-candidates.XXXXXX")"; then
    say_err "cannot create a temporary agent scan list."
    return 1
  fi
  for root in "${roots[@]}"; do
    if [[ -L "$root" ]]; then
      say_err "cannot inspect agent scan root '$root'; ensure it is a readable and searchable directory."
      scan_status=1
      break
    fi
    if [[ ! -e "$root" && ! -L "$root" ]]; then
      ancestor="$root"
      while [[ ! -e "$ancestor" && ! -L "$ancestor" ]]; do
        if [[ "$ancestor" == */* ]]; then
          ancestor="${ancestor%/*}"
          [[ -n "$ancestor" ]] || ancestor="/"
        else
          ancestor="."
        fi
      done
      if [[ ! -d "$ancestor" || ! -x "$ancestor" ]]; then
        say_err "cannot inspect agent scan root '$root'; ensure it is a readable and searchable directory."
        scan_status=1
        break
      fi
      continue
    fi
    if [[ ! -d "$root" || ! -r "$root" || ! -x "$root" ]]; then
      say_err "cannot inspect agent scan root '$root'; ensure it is a readable and searchable directory."
      scan_status=1
      break
    elif ! ls -a "$root" >/dev/null 2>&1; then
      say_err "cannot inspect agent scan root '$root'; ensure it is a readable and searchable directory."
      scan_status=1
      break
    fi
    if ! find "$root" -type l -print0 > "$candidate_list"; then
      say_err "cannot inspect agent scan root '$root'; ensure it is a readable and searchable directory."
      scan_status=1
      break
    fi
    while IFS= read -r -d '' candidate; do
      if [[ ! -d "$candidate" && "$candidate" != *.md ]]; then
        continue
      fi
      say_err "cannot inspect agent scan path '$candidate'; refusing a symlinked path."
      scan_status=1
      break
    done < "$candidate_list"
    if (( scan_status != 0 )); then
      break
    fi
    if ! find "$root" -type f -name '*.md' -print0 > "$candidate_list"; then
      say_err "cannot inspect agent scan root '$root'; ensure it is a readable and searchable directory."
      scan_status=1
      break
    fi
    while IFS= read -r -d '' candidate; do
      [[ -f "$candidate" ]] || continue
      if [[ ! -r "$candidate" ]]; then
        say_err "cannot be inspected: $candidate"
        scan_status=1
        break
      fi
      if ! identity="$(awk '
        { sub(/\r$/, "") }
        NR == 1 { if ($0 != "---") exit; next }
        $0 == "---" { exit }
        { frontmatter[++line_count] = $0 }
        END {
          for (line_number = 1; line_number <= line_count; line_number++) {
            line = frontmatter[line_number]
            if (line ~ /^[[:space:]]*$/ || line ~ /^[[:space:]]*#/) continue
            match(line, /[^[:space:]]/)
            indentation = RSTART - 1
            if (!root_indentation_found || indentation < root_indentation) {
              root_indentation = indentation
              root_indentation_found = 1
            }
          }
          for (line_number = 1; line_number <= line_count; line_number++) {
            line = frontmatter[line_number]
            if (line ~ /^[[:space:]]*$/ || line ~ /^[[:space:]]*#/) continue
            match(line, /[^[:space:]]/)
            if (RSTART - 1 != root_indentation) continue
            line = substr(line, root_indentation + 1)
            if (line ~ /^\.\.\.[[:space:]]*($|#)/) { parse_error = 1; break }
            if (line ~ /^[{&!?]/) { parse_error = 1; break }
            if (line ~ /^<<[[:space:]]*:/ || line ~ /^"<<"[[:space:]]*:/ || line ~ /^\047<<\047[[:space:]]*:/) { parse_error = 1; break }
            if (line ~ /^"/) {
              quoted_key_closed = 0
              escaped = 0
              for (character_index = 2; character_index <= length(line); character_index++) {
                character = substr(line, character_index, 1)
                if (escaped) { escaped = 0; continue }
                if (character == "\\") { escaped = 1; continue }
                if (character == "\"") { quoted_key_closed = 1; break }
              }
              if (!quoted_key_closed) { parse_error = 1; break }
            }
            if (line ~ /^"[^"]*\\[^"]*"[[:space:]]*:/ || line ~ /^"name"[[:space:]]*:/ || line ~ /^\047name\047[[:space:]]*:/) { parse_error = 1; break }
            if (line ~ /^\047/) {
              quoted_key_closed = 0
              for (character_index = 2; character_index <= length(line); character_index++) {
                character = substr(line, character_index, 1)
                if (character == "\047") {
                  if (substr(line, character_index + 1, 1) == "\047") { character_index++; continue }
                  quoted_key_closed = 1
                  break
                }
              }
              if (!quoted_key_closed) { parse_error = 1; break }
            }
            if (line !~ /^name[[:space:]]*:[[:space:]]*/) continue
            if (found_name) { parse_error = 1; break }
            found_name = 1
            value = line
            sub(/^name[[:space:]]*:[[:space:]]*/, "", value)
            sub(/^[[:space:]]+/, "", value)
            sub(/[[:space:]]+$/, "", value)
            if (value ~ /^[>|]/) { parse_error = 1; break }
            if (value ~ /^"/) {
              if (value !~ /^"[^\"]*"([[:space:]]+#.*)?$/) { parse_error = 1; break }
              if (index(value, "\\") != 0) { parse_error = 1; break }
              sub(/^"/, "", value)
              sub(/"([[:space:]]+#.*)?$/, "", value)
            } else if (value ~ /^\047/) {
              if (value !~ /^\047[^\047]*\047([[:space:]]+#.*)?$/) { parse_error = 1; break }
              sub(/^\047/, "", value)
              sub(/\047([[:space:]]+#.*)?$/, "", value)
            } else {
              if (value ~ /^!/) { parse_error = 1; break }
              if (value ~ /^[&*]/) { parse_error = 1; break }
              sub(/[[:space:]]+#.*$/, "", value)
              sub(/[[:space:]]+$/, "", value)
              if (value == "") { parse_error = 1; break }
            }
            if (value == "") { parse_error = 1; break }
            identity = value
          }
          if (parse_error) exit 2
          if (found_name) print identity
        }
      ' "$candidate")"; then
        say_err "cannot inspect agent identity in '$candidate'; its name field is unreadable or malformed."
        scan_status=1
        break
      fi
      identity="${identity#\"}"
      identity="${identity%\"}"
      identity="${identity#\'}"
      identity="${identity%\'}"
      for canonical in "$@"; do
        if [[ "$identity" == "${canonical%.md}" && "$candidate" != "$root/$identity.md" ]]; then
          say_err "competing agent definition at $candidate claims bundled identity $identity"
          scan_status=1
          break
        fi
      done
      if (( scan_status != 0 )); then
        break
      fi
    done < "$candidate_list"
    if (( scan_status != 0 )); then
      break
    fi
  done
  if ! rm -f "$candidate_list"; then
    say_err "cannot remove the temporary agent scan list '$candidate_list'."
    return 1
  fi
  return "$scan_status"
}

resolve_install_base base "$HOME/.claude" ".claude"

rules_target="$base/rules"
skills_target="$base/skills"
manifest_file="$SCRIPT_DIR/.elelem-manifest-claude"
assert_manifest_base_matches "$manifest_file" "$base"
manifest_entries=()
changed_paths=()

mkdir -p "$rules_target"

echo
say_step "Common instruction files to install:"
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
  say_warn "no common rules selected."
  confirm_common_items=("Continue with no common rules")
  confirm_common_defaults=(0)
  multiselect confirm_common_selected confirm_common_items confirm_common_defaults
  (( ${#confirm_common_selected[@]} > 0 )) || { say_info "Aborted."; exit 0; }
else
  common_files=()
  for _item in "${common_selected[@]}"; do
    common_files+=("${_item}.md")
  done
  mkdir -p "$rules_target/common"
  install_files_from_dir "$RULES_SOURCE/common" "$rules_target/common" "rules/common" manifest_entries common_files
  substitute_tool_names "$rules_target/common" CLAUDE_PLACEHOLDERS CLAUDE_SUBSTITUTIONS
  say_ok "installed: ${common_selected[*]}"
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
  say_step "Language packs to install (none selected by default):"
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
      say_ok "installed: $pick"
    done
  fi
else
  echo
  say_info "No language packs found in $RULES_SOURCE (common-only install)."
fi

if [[ -d "$SKILLS_SOURCE" ]] && compgen -G "$SKILLS_SOURCE/*/" > /dev/null; then
  echo
  say_step "Skills (target: $skills_target):"
  skills_items=("Install skills")
  skills_defaults=(1)
  multiselect skills_selected skills_items skills_defaults

  if (( ${#skills_selected[@]} > 0 )); then
    say_info "Installing skills -> $skills_target/"
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
    say_ok "installed ${#installed_skills[@]} skill(s): ${installed_skills[*]}"
  else
    say_info "Skipped skills install."
  fi
else
  echo
  say_info "No skills found in $SKILLS_SOURCE (skipping skills install)."
fi

agent_bundle_items=("Elelem agent bundle (11 agents)")
agent_bundle_defaults=(0)
multiselect agent_bundle_selected agent_bundle_items agent_bundle_defaults

if (( ${#agent_bundle_selected[@]} > 0 )); then
  agent_bundle_files=()
  for _f in "$SCRIPT_DIR/agents/claude/"*.md; do
    [[ -f "$_f" ]] || continue
    agent_bundle_files+=("$(basename "$_f")")
  done
  check_agent_bundle_conflicts "$base/agents" "${agent_bundle_files[@]}" || exit 1
  install_agent_bundle_notice "$SCRIPT_DIR/agents/LICENSE" "$base/agents.LICENSE" "agents.LICENSE" manifest_entries changed_paths
  install_agent_bundle_files "$SCRIPT_DIR/agents/claude" "$base/agents" "agents" manifest_entries agent_bundle_files changed_paths
fi

if ! prune_stale_manifest_entries "$manifest_file" "$base" manifest_entries agents; then
  if (( ${#changed_paths[@]} > 0 )); then
    report_agent_bundle_changes changed_paths
  fi
  exit 1
fi
if ! write_manifest "$manifest_file" "$base" manifest_entries; then
  if (( ${#changed_paths[@]} > 0 )); then
    report_agent_bundle_changes changed_paths
  fi
  exit 1
fi

echo
say_ok "Done."
echo "Rules:  $rules_target"
echo "Skills: $skills_target"
echo "Verify rules inside Claude Code with: /memory"
