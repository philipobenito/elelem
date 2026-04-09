#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$REPO_ROOT/_install-common.sh"
source "$REPO_ROOT/install-codex.sh"

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

test_full_install_to_tmp_user_scope() {
  local name="full_install_to_tmp_user_scope"
  local tmphome agents_target skills_target payload_file
  tmphome="$(mktemp -d)"
  trap "rm -rf '$tmphome'" RETURN

  agents_target="$tmphome/.codex/AGENTS.md"
  skills_target="$tmphome/.agents/skills"
  payload_file="$(mktemp)"
  trap "rm -rf '$tmphome'; rm -f '$payload_file'" RETURN

  local common_files=()
  local f
  for f in "$REPO_ROOT/rules/common/"*.md; do
    common_files+=("$(basename "$f")")
  done

  local lang_dirs=("python")
  _codex_render_agents_payload "$payload_file" common_files lang_dirs
  _codex_upsert_managed_block "$agents_target" "$payload_file"
  _codex_scan_file_for_placeholders "$agents_target" || { _fail "$name" "AGENTS.md placeholder scan failed"; return; }

  mkdir -p "$skills_target"
  local manifest=()
  local skills_files=()
  while IFS= read -r -d '' f; do
    skills_files+=("${f#"$REPO_ROOT/skills"/}")
  done < <(find "$REPO_ROOT/skills" -type f -print0)
  install_files_from_dir "$REPO_ROOT/skills" "$skills_target" ".agents/skills" manifest skills_files _codex_skill_resolve_dst
  _codex_substitute_placeholders_tree "$skills_target"
  scan_no_unsubstituted_placeholders "$skills_target" || { _fail "$name" "skills placeholder scan failed"; return; }

  if [[ ! -f "$agents_target" ]]; then
    _fail "$name" "expected $agents_target to exist"
    return
  fi

  if ! grep -q 'elelem:codex:start' "$agents_target"; then
    _fail "$name" "managed block start marker missing from AGENTS.md"
    return
  fi

  if ! grep -q 'rules/common/coding-style.md' "$agents_target"; then
    _fail "$name" "expected common rule heading missing from AGENTS.md"
    return
  fi

  if ! grep -q 'rules/python/coding-style.md' "$agents_target"; then
    _fail "$name" "expected python rule heading missing from AGENTS.md"
    return
  fi

  if grep -q '^globs:' "$agents_target"; then
    _fail "$name" "language-pack frontmatter leaked into AGENTS.md"
    return
  fi

  local skill_md="$skills_target/debugging/SKILL.md"
  if [[ ! -f "$skill_md" ]]; then
    _fail "$name" "expected skills/debugging/SKILL.md not present"
    return
  fi

  if ! grep -q '^name: debugging$' "$skill_md"; then
    _fail "$name" "debugging SKILL.md lost its frontmatter"
    return
  fi

  if ! grep -RIlF '/skills or $skill-name' "$skills_target" >/dev/null 2>&1; then
    _fail "$name" "skills did not receive Codex INVOKE_SKILL_TOOL substitution"
    return
  fi

  if ! grep -RIlF 'request_user_input' "$skills_target" >/dev/null 2>&1; then
    _fail "$name" "skills did not receive Codex ASK_USER_QUESTION_TOOL substitution"
    return
  fi

  if ! grep -RIlF 'update_plan' "$skills_target" >/dev/null 2>&1; then
    _fail "$name" "skills did not receive Codex TASK_TRACKER_TOOL substitution"
    return
  fi

  if ! grep -RIlF 'spawn_agent' "$skills_target" >/dev/null 2>&1; then
    _fail "$name" "skills did not receive Codex DISPATCH_AGENT_TOOL substitution"
    return
  fi

  _pass "$name"
}

test_coexistence_three_manifests() {
  local name="coexistence_three_manifests"
  local tmphome
  tmphome="$(mktemp -d)"
  trap "rm -rf '$tmphome'" RETURN

  local claude_base="$tmphome/.claude"
  local opencode_base="$tmphome/.config/opencode"
  local codex_base="$tmphome"

  mkdir -p "$claude_base/rules/common" "$opencode_base/rules/common" "$codex_base/.agents/skills/debugging"

  local manifest_claude=("rules/common/coding-style.md")
  local manifest_opencode=("rules/common/coding-style.md")
  local manifest_codex=(".agents/skills/debugging/SKILL.md")

  cp "$REPO_ROOT/rules/common/coding-style.md" "$claude_base/rules/common/"
  cp "$REPO_ROOT/rules/common/coding-style.md" "$opencode_base/rules/common/"
  cp "$REPO_ROOT/skills/debugging/SKILL.md" "$codex_base/.agents/skills/debugging/"

  local mf_claude="$tmphome/.elelem-manifest-claude"
  local mf_opencode="$tmphome/.elelem-manifest-opencode"
  local mf_codex="$tmphome/.elelem-manifest-codex"

  write_manifest "$mf_claude" "$claude_base" manifest_claude
  write_manifest "$mf_opencode" "$opencode_base" manifest_opencode
  write_manifest "$mf_codex" "$codex_base" manifest_codex

  if [[ ! -f "$mf_claude" ]] || [[ ! -f "$mf_opencode" ]] || [[ ! -f "$mf_codex" ]]; then
    _fail "$name" "expected three distinct manifest files"
    return
  fi

  _pass "$name"
}

test_install_codex_dot_sh_main_flow_syntax() {
  local name="install_codex_main_flow_syntax_clean"
  if bash -n "$REPO_ROOT/install-codex.sh" 2>/dev/null; then
    _pass "$name"
  else
    _fail "$name" "bash -n install-codex.sh failed"
  fi
}

test_install_dot_sh_offers_codex() {
  local name="front_controller_offers_codex"
  if grep -q '"Codex"' "$REPO_ROOT/install.sh"; then
    _pass "$name"
  else
    _fail "$name" "install.sh harness_items array does not include Codex"
  fi
}

test_post_install_scan_ignores_unrelated_files_under_skills_root() {
  local name="post_install_scan_ignores_unrelated_files_under_skills_root"
  local tmpbase
  tmpbase="$(mktemp -d)"
  trap "rm -rf '$tmpbase'" RETURN

  mkdir -p "$tmpbase/.agents/skills"
  mkdir -p "$tmpbase/third-party/plugin/skills/foo"

  cat > "$tmpbase/third-party/plugin/skills/foo/SKILL.md" <<'PLUGIN'
---
name: foo
description: third-party
---

TODO: this is fine, it belongs to a different installer.
PLUGIN

  local manifest=()
  local skills_files=("debugging/SKILL.md")
  install_files_from_dir "$REPO_ROOT/skills" "$tmpbase/.agents/skills" ".agents/skills" manifest skills_files _codex_skill_resolve_dst
  _codex_substitute_placeholders_tree "$tmpbase/.agents/skills"

  local scoped_exit=0
  ( scan_no_unsubstituted_placeholders "$tmpbase/.agents/skills" ) || scoped_exit=$?
  if (( scoped_exit != 0 )); then
    _fail "$name" "scoped scan tripped on a clean install"
    return
  fi

  local broad_exit=0
  ( scan_no_unsubstituted_placeholders "$tmpbase" ) || broad_exit=$?
  if (( broad_exit == 0 )); then
    _fail "$name" "broad scan against base did not trip on unrelated TODO marker; test setup is wrong"
    return
  fi

  _pass "$name"
}

test_install_codex_dot_sh_main_flow_syntax
test_install_dot_sh_offers_codex
test_full_install_to_tmp_user_scope
test_coexistence_three_manifests
test_post_install_scan_ignores_unrelated_files_under_skills_root

total=$(( passed + failed ))
echo
echo "${passed}/${total} tests passed"
(( failed == 0 )) || exit 1
