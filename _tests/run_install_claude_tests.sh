#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# install.sh guards its interactive main flow behind a
# `[[ "${BASH_SOURCE[0]}" == "${0}" ]]` check, so sourcing it here only
# defines its functions (run_claude_install, common_rule_basenames) without
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

test_common_rule_basenames_returns_all_common_md_files() {
  local name="common_rule_basenames_returns_all_common_md_files"
  local result=()

  common_rule_basenames result

  local expected=()
  local _f
  while IFS= read -r _f; do
    expected+=("$(basename "$_f" .md)")
  done < <(find "$RULES_SOURCE/common" -maxdepth 1 -type f -name '*.md' | sort)

  local sorted_result sorted_expected
  sorted_result="$(printf '%s\n' "${result[@]+"${result[@]}"}" | sort)"
  sorted_expected="$(printf '%s\n' "${expected[@]+"${expected[@]}"}" | sort)"

  if [[ -n "$sorted_expected" ]] && [[ "$sorted_result" == "$sorted_expected" ]]; then
    _pass "$name"
  else
    _fail "$name" "expected [$sorted_expected], got [$sorted_result]"
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
  local skills_selected=("debug-investigation")

  run_claude_install "$base" "$rules_target" "$skills_target" "$manifest_file" manifest_entries common_selected lang_selected skills_selected

  if [[ ! -f "$rules_target/common/coding-style.md" ]]; then
    _fail "$name" "expected $rules_target/common/coding-style.md to exist"
    return
  fi

  if [[ ! -f "$rules_target/python/coding-style.md" ]]; then
    _fail "$name" "expected $rules_target/python/coding-style.md to exist"
    return
  fi

  if [[ ! -f "$skills_target/debug-investigation/SKILL.md" ]]; then
    _fail "$name" "expected $skills_target/debug-investigation/SKILL.md to exist"
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

  if ! grep -qF "skills/debug-investigation/SKILL.md" "$manifest_file"; then
    _fail "$name" "manifest is missing the skills/debug-investigation/SKILL.md entry"
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

test_skill_basenames_returns_every_skill_folder() {
  local name="skill_basenames_returns_every_skill_folder"
  local result=()

  skill_basenames result

  local expected=()
  local _d
  while IFS= read -r _d; do
    expected+=("$(basename "$_d")")
  done < <(find "$SKILLS_SOURCE" -mindepth 1 -maxdepth 1 -type d | sort)

  local sorted_result sorted_expected
  sorted_result="$(printf '%s\n' "${result[@]+"${result[@]}"}" | sort)"
  sorted_expected="$(printf '%s\n' "${expected[@]+"${expected[@]}"}" | sort)"

  if [[ -n "$sorted_expected" ]] && [[ "$sorted_result" == "$sorted_expected" ]]; then
    _pass "$name"
  else
    _fail "$name" "expected [$sorted_expected], got [$sorted_result]"
  fi
}

test_only_selected_skills_are_installed_with_all_their_files() {
  local name="only_selected_skills_are_installed_with_all_their_files"
  local base
  base="$(mktemp -d)"
  trap "rm -rf '$base'" RETURN

  local manifest_entries=()
  local no_common=()
  local no_lang=()
  local skills_selected=("work-tdd" "design-committee")

  run_claude_install "$base" "$base/rules" "$base/skills" "$base/.elelem-manifest-claude" manifest_entries no_common no_lang skills_selected

  local expected
  for expected in work-tdd/SKILL.md work-tdd/testing-anti-patterns.md design-committee/SKILL.md design-committee/design-workflow.js; do
    if [[ ! -f "$base/skills/$expected" ]]; then
      _fail "$name" "expected skills/$expected to be installed"
      return
    fi
  done

  local installed
  installed="$(find "$base/skills" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort | tr '\n' ' ')"
  if [[ "$installed" != "design-committee work-tdd " ]]; then
    _fail "$name" "expected only the two selected skills, found: $installed"
    return
  fi

  if grep -qF "skills/debug-investigation/" "$base/.elelem-manifest-claude"; then
    _fail "$name" "manifest records a skill that was not selected"
    return
  fi

  _pass "$name"
}

test_deselecting_a_skill_on_reinstall_prunes_it() {
  local name="deselecting_a_skill_on_reinstall_prunes_it"
  local base
  base="$(mktemp -d)"
  trap "rm -rf '$base'" RETURN

  local no_common=()
  local no_lang=()
  local first_entries=()
  local first_skills=("work-tdd" "debug-investigation")
  run_claude_install "$base" "$base/rules" "$base/skills" "$base/.elelem-manifest-claude" first_entries no_common no_lang first_skills

  local second_entries=()
  local second_skills=("work-tdd")
  run_claude_install "$base" "$base/rules" "$base/skills" "$base/.elelem-manifest-claude" second_entries no_common no_lang second_skills

  if [[ -e "$base/skills/debug-investigation" ]]; then
    _fail "$name" "debug-investigation should have been pruned once deselected"
    return
  fi

  if [[ ! -f "$base/skills/work-tdd/SKILL.md" ]]; then
    _fail "$name" "work-tdd should still be installed"
    return
  fi

  _pass "$name"
}

test_install_dot_sh_exists
test_install_dot_sh_executable
test_common_rule_basenames_returns_all_common_md_files
test_skill_basenames_returns_every_skill_folder
test_full_install_to_tmp_target
test_only_selected_skills_are_installed_with_all_their_files
test_deselecting_a_skill_on_reinstall_prunes_it
test_reinstall_prunes_stale_file_but_preserves_user_created_file

total=$(( passed + failed ))
echo
echo "${passed}/${total} tests passed"
(( failed == 0 )) || exit 1
