#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../install.sh
source "$REPO_ROOT/install.sh"
# uninstall.sh guards its interactive body, so sourcing it only defines uninstall_manifest and friends.
# shellcheck source=../uninstall.sh
source "$REPO_ROOT/uninstall.sh"
set +e # install.sh runs "set -euo pipefail" at top level; restore this suite's intended -e-off mode

# The confirmation prompt needs a TTY; the stand-in always answers "Proceed".
multiselect() {
  eval "$1=(\"Proceed with removal\")"
}

passed=0
failed=0

_pass() {
  echo "[PASS] $1"
  (( passed++ )) || true
}

_fail() {
  echo "[FAIL] $1: $2"
  (( failed++ )) || true
}

# Installs every common rule, every language pack and every skill for OpenCode
# into $1 (which should end in /.opencode for project-style paths).
_install_everything() {
  local base="$1"
  local entries_var="$2"
  local common_all=() lang_all=() skills_all=() dir

  common_rule_basenames common_all
  for dir in "$RULES_SOURCE"/*/; do
    [[ "$(basename "$dir")" == "common" ]] && continue
    compgen -G "$dir*.md" > /dev/null && lang_all+=("$(basename "$dir")")
  done
  skill_basenames skills_all

  run_opencode_install "$base" "$base/rules" "$base/skills" "$base/.elelem-manifest-opencode" "$entries_var" common_all lang_all skills_all
}

test_every_claude_tool_name_is_rewritten_in_the_full_install() {
  local name="every_claude_tool_name_is_rewritten_in_the_full_install"
  local root base
  root="$(mktemp -d)"
  trap "rm -rf '$root'" RETURN
  base="$root/.opencode"

  local m_entries=()
  _install_everything "$base" m_entries > /dev/null

  local hits
  hits="$(grep -rnE 'AskUserQuestion|EnterPlanMode|ExitPlanMode|ToolSearch|`Agent`|^Agent[ :]' "$base/rules" "$base/skills" --include='*.md' 2>/dev/null)"
  if [[ -n "$hits" ]]; then
    _fail "$name" "installed markdown still names Claude Code tools: $(echo "$hits" | head -3 | cut -c1-200)"
    return
  fi

  if ! opencode_report_residue "$base" m_entries 2> /dev/null; then
    _fail "$name" "opencode_report_residue flagged residue the grep above did not"
    return
  fi

  _pass "$name"
}

test_substitutions_produce_the_opencode_forms() {
  local name="substitutions_produce_the_opencode_forms"
  local root base
  root="$(mktemp -d)"
  trap "rm -rf '$root'" RETURN
  base="$root/.opencode"

  local m_entries=()
  _install_everything "$base" m_entries > /dev/null

  grep -qF 'dispatch it with `task`' "$base/skills/work-tdd/SKILL.md" \
    || { _fail "$name" "work-tdd should dispatch with \`task\`"; return; }
  grep -qxF 'task (general):' "$base/skills/work-tdd/SKILL.md" \
    || { _fail "$name" "work-tdd prompt template header should be 'task (general):'"; return; }
  grep -qF 'subagent_type: "explore"' "$base/skills/design-review/SKILL.md" \
    || { _fail "$name" "design-review should use the explore subagent"; return; }
  grep -qF 'opencode models' "$base/skills/work-review-request/SKILL.md" \
    || { _fail "$name" "work-review-request should enumerate models via opencode models"; return; }
  grep -qF '`question`' "$base/skills/design-dialogue/SKILL.md" \
    || { _fail "$name" "design-dialogue should ask through \`question\`"; return; }
  grep -qF 'Plan agent (Tab)' "$base/skills/design-dialogue/SKILL.md" \
    || { _fail "$name" "design-dialogue should describe plan mode as the Plan agent"; return; }

  _pass "$name"
}

test_non_markdown_skill_files_are_copied_unchanged() {
  local name="non_markdown_skill_files_are_copied_unchanged"
  local root base
  root="$(mktemp -d)"
  trap "rm -rf '$root'" RETURN
  base="$root/.opencode"

  local m_entries=() no_common=() no_lang=() skills=("work-swarm")
  run_opencode_install "$base" "$base/rules" "$base/skills" "$base/.elelem-manifest-opencode" m_entries no_common no_lang skills > /dev/null

  if ! cmp -s "$SKILLS_SOURCE/work-swarm/implementation-workflow.js" "$base/skills/work-swarm/implementation-workflow.js"; then
    _fail "$name" "the workflow script was modified by the markdown substitution"
    return
  fi

  _pass "$name"
}

test_claude_install_leaves_tool_names_alone() {
  local name="claude_install_leaves_tool_names_alone"
  local base
  base="$(mktemp -d)"
  trap "rm -rf '$base'" RETURN

  local m_entries=() no_common=() no_lang=() skills=("design-dialogue")
  run_claude_install "$base" "$base/rules" "$base/skills" "$base/.elelem-manifest-claude" m_entries no_common no_lang skills > /dev/null

  if ! cmp -s "$SKILLS_SOURCE/design-dialogue/SKILL.md" "$base/skills/design-dialogue/SKILL.md"; then
    _fail "$name" "the Claude Code install must copy skills verbatim"
    return
  fi

  _pass "$name"
}

test_opencode_install_writes_instructions_and_manifest() {
  local name="opencode_install_writes_instructions_and_manifest"
  local root base
  root="$(mktemp -d)"
  trap "rm -rf '$root'" RETURN
  base="$root/.opencode"

  local m_entries=() common=("coding-style") lang=("python") skills=("work-tdd")
  run_opencode_install "$base" "$base/rules" "$base/skills" "$base/.elelem-manifest-opencode" m_entries common lang skills > /dev/null

  local globs
  globs="$(jq -r '.instructions | join(",")' "$base/opencode.json")"
  if [[ "$globs" != ".opencode/rules/common/*.md,.opencode/rules/python/*.md" ]]; then
    _fail "$name" "unexpected instructions: $globs"
    return
  fi

  if ! grep -qF "AGENTS.md" "$base/.elelem-manifest-opencode"; then
    _fail "$name" "AGENTS.md should be recorded in the manifest"
    return
  fi

  if grep -qF "opencode.json" "$base/.elelem-manifest-opencode"; then
    _fail "$name" "opencode.json holds user settings and must not be in the manifest"
    return
  fi

  if ! grep -qF "[rules/python/coding-style.md](rules/python/coding-style.md)" "$base/AGENTS.md"; then
    _fail "$name" "AGENTS.md index is missing the python rule"
    return
  fi

  if [[ ! -f "$base/skills/work-tdd/SKILL.md" || -e "$base/skills/debug-investigation" ]]; then
    _fail "$name" "only the selected skill should be installed"
    return
  fi

  _pass "$name"
}

test_opencode_instruction_prefix_per_scope() {
  local name="opencode_instruction_prefix_per_scope"

  local project user other
  project="$(opencode_instruction_prefix "/work/app/.opencode")"
  user="$(opencode_instruction_prefix "$HOME/.config/opencode")"
  other="$(opencode_instruction_prefix "/srv/oc")"

  if [[ "$project" != ".opencode/" ]]; then
    _fail "$name" "project scope should be project-relative, got: $project"
    return
  fi
  if [[ "$user" != "~/.config/opencode/" ]]; then
    _fail "$name" "user scope should use ~/, got: $user"
    return
  fi
  if [[ "$other" != "/srv/oc/" ]]; then
    _fail "$name" "a base outside HOME should stay absolute, got: $other"
    return
  fi

  _pass "$name"
}

test_write_opencode_instructions_preserves_user_settings_and_entries() {
  local name="write_opencode_instructions_preserves_user_settings_and_entries"
  local dir
  dir="$(mktemp -d)"
  trap "rm -rf '$dir'" RETURN

  cat > "$dir/opencode.json" <<'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": [
    "CONTRIBUTING.md",
    ".opencode/rules/common/*.md",
    ".opencode/rules/go/*.md"
  ],
  "permission": { "edit": "ask" }
}
EOF

  write_opencode_instructions "$dir/opencode.json" ".opencode/" ".opencode/rules/common/*.md" ".opencode/rules/python/*.md"

  if [[ "$(jq -r '.permission.edit' "$dir/opencode.json")" != "ask" ]]; then
    _fail "$name" "the pre-existing permission key was discarded"
    return
  fi

  local globs
  globs="$(jq -r '.instructions | join(",")' "$dir/opencode.json")"
  if [[ "$globs" != "CONTRIBUTING.md,.opencode/rules/common/*.md,.opencode/rules/python/*.md" ]]; then
    _fail "$name" "expected the user entry kept and elelem entries replaced, got: $globs"
    return
  fi

  _pass "$name"
}

test_write_opencode_instructions_preserves_a_symlinked_target() {
  local name="write_opencode_instructions_preserves_a_symlinked_target"
  local dir
  dir="$(mktemp -d)"
  trap "rm -rf '$dir'" RETURN

  printf '{"permission": {"edit": "ask"}}\n' > "$dir/real.json"
  ln -s "$dir/real.json" "$dir/opencode.json"

  write_opencode_instructions "$dir/opencode.json" ".opencode/" ".opencode/rules/common/*.md"

  if [[ ! -L "$dir/opencode.json" ]]; then
    _fail "$name" "the symlink was replaced by a regular file"
    return
  fi
  if [[ "$(jq -r '.permission.edit' "$dir/real.json")" != "ask" ]]; then
    _fail "$name" "writing through the symlink discarded keys in the target"
    return
  fi

  _pass "$name"
}

test_write_opencode_instructions_leaves_a_malformed_target_unchanged() {
  local name="write_opencode_instructions_leaves_a_malformed_target_unchanged"
  local dir
  dir="$(mktemp -d)"
  trap "rm -rf '$dir'" RETURN

  printf '{ not valid json' > "$dir/opencode.json"

  if write_opencode_instructions "$dir/opencode.json" ".opencode/" ".opencode/rules/common/*.md" 2> /dev/null; then
    _fail "$name" "expected a non-zero return when the existing file is not valid JSON"
    return
  fi
  if [[ "$(cat "$dir/opencode.json")" != '{ not valid json' ]]; then
    _fail "$name" "the malformed target was modified"
    return
  fi

  _pass "$name"
}

test_existing_agents_md_is_not_overwritten() {
  local name="existing_agents_md_is_not_overwritten"
  local root base
  root="$(mktemp -d)"
  trap "rm -rf '$root'" RETURN
  base="$root/.opencode"
  mkdir -p "$base"
  printf 'my own instructions\n' > "$base/AGENTS.md"

  local m_entries=() common=("coding-style") no_lang=() no_skills=()
  run_opencode_install "$base" "$base/rules" "$base/skills" "$base/.elelem-manifest-opencode" m_entries common no_lang no_skills > /dev/null 2>&1

  if [[ "$(cat "$base/AGENTS.md")" != "my own instructions" ]]; then
    _fail "$name" "a user-authored AGENTS.md was overwritten"
    return
  fi
  if grep -qF "AGENTS.md" "$base/.elelem-manifest-opencode"; then
    _fail "$name" "an AGENTS.md elelem did not write must not be in the manifest"
    return
  fi

  _pass "$name"
}

test_reinstall_refreshes_an_agents_md_elelem_wrote() {
  local name="reinstall_refreshes_an_agents_md_elelem_wrote"
  local root base
  root="$(mktemp -d)"
  trap "rm -rf '$root'" RETURN
  base="$root/.opencode"

  local no_lang=() no_skills=()
  local first_entries=() first_common=("coding-style" "testing")
  run_opencode_install "$base" "$base/rules" "$base/skills" "$base/.elelem-manifest-opencode" first_entries first_common no_lang no_skills > /dev/null
  local second_entries=() second_common=("coding-style")
  run_opencode_install "$base" "$base/rules" "$base/skills" "$base/.elelem-manifest-opencode" second_entries second_common no_lang no_skills > /dev/null

  if grep -qF "testing.md" "$base/AGENTS.md"; then
    _fail "$name" "AGENTS.md still lists the rule dropped on reinstall"
    return
  fi
  if [[ -f "$base/rules/common/testing.md" ]]; then
    _fail "$name" "the dropped rule should have been pruned"
    return
  fi

  _pass "$name"
}

test_remove_opencode_instructions_keeps_user_content() {
  local name="remove_opencode_instructions_keeps_user_content"
  local dir
  dir="$(mktemp -d)"
  trap "rm -rf '$dir'" RETURN

  printf '{"instructions": ["CONTRIBUTING.md", ".opencode/rules/common/*.md"], "permission": {"edit": "ask"}}\n' > "$dir/opencode.json"

  remove_opencode_instructions "$dir/opencode.json" ".opencode/"

  if [[ ! -f "$dir/opencode.json" ]]; then
    _fail "$name" "a config holding user settings must not be deleted"
    return
  fi
  if [[ "$(jq -c '.instructions' "$dir/opencode.json")" != '["CONTRIBUTING.md"]' ]]; then
    _fail "$name" "expected only elelem's entry removed, got: $(jq -c '.instructions' "$dir/opencode.json")"
    return
  fi

  _pass "$name"
}

test_remove_opencode_instructions_deletes_a_config_elelem_created() {
  local name="remove_opencode_instructions_deletes_a_config_elelem_created"
  local dir
  dir="$(mktemp -d)"
  trap "rm -rf '$dir'" RETURN

  write_opencode_instructions "$dir/opencode.json" ".opencode/" ".opencode/rules/common/*.md"
  remove_opencode_instructions "$dir/opencode.json" ".opencode/"

  if [[ -e "$dir/opencode.json" ]]; then
    _fail "$name" "a config holding nothing but elelem's entries should be removed"
    return
  fi

  _pass "$name"
}

test_uninstall_removes_installed_files_and_only_elelem_config() {
  local name="uninstall_removes_installed_files_and_only_elelem_config"
  local root base
  root="$(mktemp -d)"
  trap "rm -rf '$root'" RETURN
  base="$root/.opencode"
  mkdir -p "$base"
  printf '{"permission": {"edit": "ask"}}\n' > "$base/opencode.json"
  printf 'user note\n' > "$base/skills-notes.md"

  local m_entries=() common=("coding-style") no_lang=() skills=("work-tdd")
  run_opencode_install "$base" "$base/rules" "$base/skills" "$base/.elelem-manifest-opencode" m_entries common no_lang skills > /dev/null
  printf 'user rule\n' > "$base/rules/common/user-rule.md"

  uninstall_manifest "$base/.elelem-manifest-opencode" > /dev/null

  if [[ -e "$base/skills" || -e "$base/rules/common/coding-style.md" || -e "$base/AGENTS.md" ]]; then
    _fail "$name" "installed files were not removed"
    return
  fi
  if [[ ! -f "$base/rules/common/user-rule.md" || ! -f "$base/skills-notes.md" ]]; then
    _fail "$name" "user-created files must survive uninstall"
    return
  fi
  if [[ "$(jq -c . "$base/opencode.json")" != '{"permission":{"edit":"ask"},"instructions":[]}' ]]; then
    _fail "$name" "opencode.json should keep user keys and lose only elelem instructions, got: $(jq -c . "$base/opencode.json")"
    return
  fi
  if [[ -e "$base/.elelem-manifest-opencode" ]]; then
    _fail "$name" "the manifest should be removed"
    return
  fi

  _pass "$name"
}

test_every_claude_tool_name_is_rewritten_in_the_full_install
test_substitutions_produce_the_opencode_forms
test_non_markdown_skill_files_are_copied_unchanged
test_claude_install_leaves_tool_names_alone
test_opencode_install_writes_instructions_and_manifest
test_opencode_instruction_prefix_per_scope
test_write_opencode_instructions_preserves_user_settings_and_entries
test_write_opencode_instructions_preserves_a_symlinked_target
test_write_opencode_instructions_leaves_a_malformed_target_unchanged
test_existing_agents_md_is_not_overwritten
test_reinstall_refreshes_an_agents_md_elelem_wrote
test_remove_opencode_instructions_keeps_user_content
test_remove_opencode_instructions_deletes_a_config_elelem_created
test_uninstall_removes_installed_files_and_only_elelem_config

total=$(( passed + failed ))
echo
echo "${passed}/${total} tests passed"
(( failed == 0 )) || exit 1
