#!/usr/bin/env bash
#
# Installs elelem rules and skills for OpenCode.
#
# Rules (./rules/) install to ~/.config/opencode/rules/ (user scope) or
# <project>/.opencode/rules/ (project scope). Common rules are always-on.
#
# Skills (./skills/) install to ~/.config/opencode/skills/ or
# <project>/.opencode/skills/.
#
#
# A manifest file (.elelem-manifest-opencode) in this repo tracks installed
# files for prune-on-reinstall.
#
# Tool-name placeholders of the form {{TOOL_NAME}} in rules and skills are
# substituted with OpenCode tool names during install.
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

if ! command -v jq > /dev/null 2>&1; then
  say_err "jq is required to update opencode.json without discarding existing settings. Install jq and re-run."
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
  'MODEL_ENUMERATION'
)

OPENCODE_SUBSTITUTIONS=(
  'question'
  'entering plan mode (in OpenCode, plan mode is toggled by the user pressing Tab; ask the user to enter plan mode before reviewing the design)'
  'exiting plan mode (in OpenCode, the user toggles out of plan mode with Tab after approving the design; present the design and wait for explicit approval before any code edit)'
  'todowrite'
  'subagent'
  'skill'
  'read'
  'write'
  'edit'
  'grep'
  'glob'
  'shell'
  'running `opencode models` with the shell tool, which lists every available model, one per line'
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

preflight_opencode_instructions() {
  local target="$1" previous="$2" ownership="$3" owned document requested
  shift 3
  owned="$(_opencode_owned_entries "$previous" "$ownership")" || return 1
  document="$(_opencode_config_document "$target")" || return 1
  requested="$(jq -cn --args '$ARGS.positional' -- "$@")" || return 1
  _opencode_render_owned_update "$document" "$owned" "$requested" > /dev/null || return 1
  _opencode_destination_writable "$target" || return 1
  _opencode_destination_writable "$ownership"
}

resolve_install_base base "$HOME/.config/opencode" ".opencode"

rules_target="$base/rules"
skills_target="$base/skills"
manifest_file="$SCRIPT_DIR/.elelem-manifest-opencode"
assert_manifest_base_matches "$manifest_file" "$base"
opencode_agents_preflight "$base/AGENTS.md" "$manifest_file"
manifest_entries=()
changed_paths=()
instructions_globs=()

bootstrap="$rules_target/elelem-language-packs.md"
if [[ -e "$bootstrap" || -L "$bootstrap" ]]; then
  if [[ ! -f "$bootstrap" || -L "$bootstrap" || ! -f "$manifest_file" ]] || ! tail -n +2 "$manifest_file" | grep -Fxq rules/elelem-language-packs.md; then
    say_err "unmanaged activation bootstrap collision at '$bootstrap'; move or remove it, then rerun."
    exit 1
  fi
fi

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
  instructions_globs+=("rules/common/*.md")
fi

instructions_globs+=("rules/elelem-language-packs.md")
preflight_opencode_instructions "$base/opencode.json" "$manifest_file" "$base/.elelem-opencode-instructions.json" "${instructions_globs[@]}"

if (( ${#common_selected[@]} > 0 )); then
  mkdir -p "$rules_target/common"
  install_files_from_dir "$RULES_SOURCE/common" "$rules_target/common" "rules/common" manifest_entries common_files
  substitute_tool_names "$rules_target/common" OPENCODE_PLACEHOLDERS OPENCODE_SUBSTITUTIONS
  say_ok "installed: ${common_selected[*]}"
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
    substitute_tool_names "$skills_target" OPENCODE_PLACEHOLDERS OPENCODE_SUBSTITUTIONS

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

echo
say_step "Optional agent bundle:"
agent_bundle_items=("Elelem agent bundle (11 agents)")
agent_bundle_defaults=(0)
multiselect agent_bundle_selected agent_bundle_items agent_bundle_defaults

if (( ${#agent_bundle_selected[@]} > 0 )); then
  agent_bundle_files=()
  for _f in "$SCRIPT_DIR/agents/opencode/"*.md; do
    [[ -f "$_f" ]] || continue
    agent_bundle_files+=("$(basename "$_f")")
  done

  config_paths=("$HOME/.config/opencode/opencode.json" "$PWD/opencode.json" "$PWD/.opencode/opencode.json" "$base/opencode.json")
  if [[ "$base" != "$HOME/.config/opencode" ]]; then
    config_paths+=("${base%/.opencode}/opencode.json")
  fi
  for config_path in "${config_paths[@]}"; do
    config_paths+=("${config_path}c")
  done
  inspected_config_paths=()
  for config_path in "${config_paths[@]}"; do
    [[ -e "$config_path" || -L "$config_path" ]] || continue
    if ! config_directory="$(cd "$(dirname "$config_path")" && pwd -P)"; then
      say_err "cannot inspect JSON agent declarations in '$config_path'."
      exit 1
    fi
    config_key="$config_directory/${config_path##*/}"
    already_inspected=0
    for inspected_config_path in "${inspected_config_paths[@]+"${inspected_config_paths[@]}"}"; do
      [[ "$config_key" == "$inspected_config_path" ]] && already_inspected=1
    done
    (( already_inspected == 0 )) || continue
    inspected_config_paths+=("$config_key")
    if [[ "$config_path" == *.jsonc ]]; then
      say_err "cannot inspect JSONC configuration '$config_path'; convert it to JSON, remove it, or deselect the agent bundle."
      exit 1
    fi
    if [[ ! -f "$config_path" || ! -r "$config_path" ]]; then
      say_err "cannot inspect JSON agent declarations in '$config_path'."
      exit 1
    fi
    if ! jq -se 'length == 1 and (.[0] | type == "object" and (if has("agent") then (.agent | type == "object") else true end) and (if has("agents") then (.agents | type == "object") else true end))' "$config_path" > /dev/null 2>&1; then
      say_err "cannot inspect JSON agent declarations in '$config_path'."
      exit 1
    fi
    for agent_file in "${agent_bundle_files[@]}"; do
      agent_id="${agent_file%.md}"
      if jq -e --arg agent_id "$agent_id" '(.agent // {} | has($agent_id)) or (.agents // {} | has($agent_id))' "$config_path" > /dev/null; then
        say_err "agent ID '$agent_id' conflicts with an existing JSON agent declaration in '$config_path'; rename or remove the competing declaration, then rerun."
        exit 1
      else
        query_status=$?
        if (( query_status != 1 )); then
          say_err "cannot inspect JSON agent declarations in '$config_path'."
          exit 1
        fi
      fi
    done
  done

  for agent_root in "$PWD/.opencode/agents" "$HOME/.config/opencode/agents" "$base/agents"; do
    if [[ ! -d "$agent_root" ]]; then
      inspection_path="$agent_root"
      while [[ ! -e "$inspection_path" && ! -L "$inspection_path" ]]; do
        inspection_path="${inspection_path%/*}"
      done
      if [[ ! -d "$inspection_path" || ! -r "$inspection_path" || ! -x "$inspection_path" ]]; then
        say_err "failed to enumerate Markdown agents in '$agent_root'."
        exit 1
      fi
      continue
    fi
    for agent_file in "${agent_bundle_files[@]}"; do
      if ! conflicting_agent_path=$(find -H "$agent_root" -maxdepth 1 -name "$agent_file" -print -quit); then
        say_err "failed to enumerate Markdown agents in '$agent_root'."
        exit 1
      fi
      [[ -n "$conflicting_agent_path" ]] || continue
      [[ "$conflicting_agent_path" == "$base/agents/$agent_file" ]] && continue
      if [[ -d "$base/agents" ]] && [[ "$(cd "$agent_root" && pwd -P)" == "$(cd "$base/agents" && pwd -P)" ]]; then
        continue
      fi
      agent_id="${agent_file%.md}"
      say_err "agent ID '$agent_id' conflicts with existing Markdown agent '$conflicting_agent_path'; rename or remove the competing file, then rerun."
      exit 1
    done
  done

  install_agent_bundle_notice "$SCRIPT_DIR/agents/LICENSE" "$base/agents.LICENSE" "agents.LICENSE" manifest_entries changed_paths
  install_agent_bundle_files "$SCRIPT_DIR/agents/opencode" "$base/agents" "agents" manifest_entries agent_bundle_files changed_paths
fi

install_language_packs "$RULES_SOURCE" "$skills_target" skills "$manifest_file" manifest_entries OPENCODE_PLACEHOLDERS OPENCODE_SUBSTITUTIONS
policy_stage="$(mktemp -d "${TMPDIR:-/tmp}/elelem-language-policy.XXXXXX")"
render_language_pack_policy > "$policy_stage/elelem-language-packs.md"
substitute_tool_names "$policy_stage" OPENCODE_PLACEHOLDERS OPENCODE_SUBSTITUTIONS
cp "$policy_stage/elelem-language-packs.md" "$bootstrap"
rm "$policy_stage/elelem-language-packs.md"
rmdir "$policy_stage"
manifest_entries+=("rules/elelem-language-packs.md")

update_opencode_instructions "$base/opencode.json" "$manifest_file" "$base/.elelem-opencode-instructions.json" "${instructions_globs[@]+"${instructions_globs[@]}"}"

if (( ${#instructions_globs[@]} > 0 )); then
  pushd "$base" > /dev/null
  validate_globs_resolve "${instructions_globs[@]}"
  popd > /dev/null
fi

manifest_entries+=(".elelem-opencode-instructions.json")

opencode_agents_update "$base/AGENTS.md" manifest_entries "$manifest_file"

manifest_entries+=("AGENTS.md")

if ! prune_stale_manifest_entries "$manifest_file" "$base" manifest_entries agents opencode; then
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
echo "Install base:  $base"
echo "Manifest:      $manifest_file"
echo "opencode.json: $base/opencode.json"
echo "AGENTS.md:     $base/AGENTS.md"

echo
echo "============================================================"
say_warn "ACTION REQUIRED: disable the Claude Code fallback in OpenCode"
echo "============================================================"
echo
echo "OpenCode has a built-in Claude Code fallback that reads rules"
echo "from ~/.claude/ alongside its own config. If you have also run"
echo "the Claude installer, OpenCode will load the Claude-substituted"
echo "rules from there, giving you Claude tool names like Read and"
echo "Agent in an OpenCode session instead of OpenCode's read and"
echo "task. The rules still parse, but they refer to tools the"
echo "OpenCode assistant does not recognise by those names."
echo
echo "To prevent this, set OPENCODE_DISABLE_CLAUDE_CODE=1 in your"
echo "shell environment. To persist it, run one of:"
echo
echo "  echo 'export OPENCODE_DISABLE_CLAUDE_CODE=1' >> ~/.zshrc"
echo "  echo 'export OPENCODE_DISABLE_CLAUDE_CODE=1' >> ~/.bashrc"
echo
echo "then restart your shell."
echo "============================================================"
echo
