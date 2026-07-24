#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../_install-common.sh
source "$REPO_ROOT/_install-common.sh"

# install.sh guards its interactive main flow behind a
# `[[ "${BASH_SOURCE[0]}" == "${0}" ]]` check, so sourcing it here only
# defines its functions (_skill_resolve_dst, run_claude_install) without
# running the multiselect-driven install. Tests drive the install by calling
# run_claude_install directly with hardcoded selections, exercising the same
# deterministic install sequence install.sh's interactive body calls, instead
# of the interactive prompts.
# shellcheck source=../install.sh
source "$REPO_ROOT/install.sh"
set +e # install.sh runs "set -euo pipefail" at top level; restore this suite's intended -e-off mode

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

test_install_dot_sh_exists() {
  local name="install_dot_sh_exists"

  if [[ -f "$REPO_ROOT/install.sh" ]]; then
    _pass "$name"
  else
    _fail "$name" "install.sh does not exist"
  fi
}

test_install_dot_sh_executable() {
  local name="install_dot_sh_executable"

  if [[ -x "$REPO_ROOT/install.sh" ]]; then
    _pass "$name"
  else
    _fail "$name" "install.sh is not executable"
  fi
}

test_skill_resolve_dst_preserves_subdirectory_structure() {
  local name="skill_resolve_dst_preserves_subdirectory_structure"
  local result

  result="$(_skill_resolve_dst "$SKILLS_SOURCE/debugging/SKILL.md" /out)"

  if [[ "$result" == "/out/debugging/SKILL.md" ]]; then
    _pass "$name"
  else
    _fail "$name" "expected /out/debugging/SKILL.md, got $result"
  fi
}

test_skill_resolve_dst_preserves_nested_files() {
  local name="skill_resolve_dst_preserves_nested_files"
  local result

  result="$(_skill_resolve_dst "$SKILLS_SOURCE/brainstorming/modes/standard.md" /out)"

  if [[ "$result" == "/out/brainstorming/modes/standard.md" ]]; then
    _pass "$name"
  else
    _fail "$name" "expected /out/brainstorming/modes/standard.md, got $result"
  fi
}

test_full_install_to_tmp_target() {
  local name="full_install_to_tmp_target"
  local base rules_target skills_target manifest_file
  base="$(mktemp -d)"
  trap "rm -rf '$base'" RETURN

  rules_target="$base/rules"
  skills_target="$base/skills"
  manifest_file="$base/.elelem-manifest-claude"

  local manifest_entries=()
  local common_selected=("coding-style" "testing")
  local lang_selected=("python")
  local skills_selected=("Install skills")

  run_claude_install "$base" "$rules_target" "$skills_target" "$manifest_file" manifest_entries common_selected lang_selected skills_selected

  if [[ ! -f "$rules_target/common/coding-style.md" ]]; then
    _fail "$name" "expected $rules_target/common/coding-style.md to exist"
    return
  fi

  if [[ ! -f "$rules_target/python/coding-style.md" ]]; then
    _fail "$name" "expected $rules_target/python/coding-style.md to exist"
    return
  fi

  if [[ ! -f "$skills_target/debugging/SKILL.md" ]]; then
    _fail "$name" "expected $skills_target/debugging/SKILL.md to exist"
    return
  fi

  if [[ ! -f "$manifest_file" ]]; then
    _fail "$name" "expected manifest file to be written"
    return
  fi

  if ! grep -qF "rules/common/coding-style.md" "$manifest_file"; then
    _fail "$name" "manifest is missing the rules/common/coding-style.md entry"
    return
  fi

  if ! grep -qF "skills/debugging/SKILL.md" "$manifest_file"; then
    _fail "$name" "manifest is missing the skills/debugging/SKILL.md entry"
    return
  fi

  if [[ "$(head -n1 "$manifest_file")" != "$base" ]]; then
    _fail "$name" "manifest first line should be the install base"
    return
  fi

  _pass "$name"
}

test_reinstall_prunes_stale_file_but_preserves_user_created_file() {
  local name="reinstall_prunes_stale_file_but_preserves_user_created_file"
  local base rules_target skills_target manifest_file
  base="$(mktemp -d)"
  trap "rm -rf '$base'" RETURN

  rules_target="$base/rules"
  skills_target="$base/skills"
  manifest_file="$base/.elelem-manifest-claude"

  local first_entries=()
  local first_common_selected=("coding-style" "testing")
  local no_lang_selected=()
  local no_skills_selected=()
  run_claude_install "$base" "$rules_target" "$skills_target" "$manifest_file" first_entries first_common_selected no_lang_selected no_skills_selected

  if [[ ! -f "$base/rules/common/testing.md" ]]; then
    _fail "$name" "setup failed: testing.md was not installed on first pass"
    return
  fi

  printf 'user notes, not managed by elelem\n' > "$base/rules/common/user-notes.md"

  local second_entries=()
  local second_common_selected=("coding-style")
  run_claude_install "$base" "$rules_target" "$skills_target" "$manifest_file" second_entries second_common_selected no_lang_selected no_skills_selected

  if [[ -f "$base/rules/common/testing.md" ]]; then
    _fail "$name" "testing.md should have been pruned once it dropped out of the install set"
    return
  fi

  if [[ ! -f "$base/rules/common/coding-style.md" ]]; then
    _fail "$name" "coding-style.md should still be present after reinstall"
    return
  fi

  if [[ ! -f "$base/rules/common/user-notes.md" ]]; then
    _fail "$name" "user-created file must never be removed by prune_stale_manifest_entries"
    return
  fi

  if grep -qF "rules/common/testing.md" "$manifest_file"; then
    _fail "$name" "manifest still references the pruned testing.md entry"
    return
  fi

  _pass "$name"
}

test_install_dot_sh_exists
test_install_dot_sh_executable
test_skill_resolve_dst_preserves_subdirectory_structure
test_skill_resolve_dst_preserves_nested_files
test_full_install_to_tmp_target
test_reinstall_prunes_stale_file_but_preserves_user_created_file

total=$(( passed + failed ))
echo
echo "${passed}/${total} tests passed"
(( failed == 0 )) || exit 1
