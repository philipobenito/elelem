#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$REPO_ROOT/_install-common.sh"
source "$REPO_ROOT/install-cursor.sh"

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
  local tmpbase
  tmpbase="$(mktemp -d)"
  trap "rm -rf '$tmpbase'" RETURN

  cursor_assert_not_under_claude "$tmpbase" || { _fail "$name" "guard rejected benign tmpbase"; return; }

  mkdir -p "$tmpbase/rules"
  local manifest=()
  local common_files=()
  local f
  for f in "$REPO_ROOT/rules/common/"*.md; do
    common_files+=("$(basename "$f")")
  done
  CURSOR_RULE_GROUP_PREFIX="common"
  install_files_from_dir "$REPO_ROOT/rules/common" "$tmpbase/rules" "rules" manifest common_files _cursor_rule_resolve_dst _cursor_rule_transform
  CURSOR_RULE_GROUP_PREFIX=""

  local lang_files=()
  for f in "$REPO_ROOT/rules/python/"*.md; do
    lang_files+=("$(basename "$f")")
  done
  CURSOR_RULE_GROUP_PREFIX="python"
  install_files_from_dir "$REPO_ROOT/rules/python" "$tmpbase/rules" "rules" manifest lang_files _cursor_rule_resolve_dst _cursor_rule_transform
  CURSOR_RULE_GROUP_PREFIX=""

  mkdir -p "$tmpbase/skills"
  local skills_files=()
  while IFS= read -r -d '' f; do
    skills_files+=("${f#"$REPO_ROOT/skills"/}")
  done < <(find "$REPO_ROOT/skills" -type f -print0)
  install_files_from_dir "$REPO_ROOT/skills" "$tmpbase/skills" "skills" manifest skills_files _cursor_skill_resolve_dst _cursor_skill_transform

  if ! ls "$tmpbase/rules"/elelem-common-*.mdc >/dev/null 2>&1; then
    _fail "$name" "no elelem-common-*.mdc files at rules root"
    return
  fi

  if find "$tmpbase/rules" -mindepth 1 -type d | grep -q .; then
    _fail "$name" "rules tree contains nested subdirectories; expected flat layout"
    return
  fi

  local sample
  sample="$(ls "$tmpbase/rules"/elelem-common-*.mdc | head -1)"
  if ! head -5 "$sample" | grep -q 'alwaysApply: true'; then
    _fail "$name" "common rule missing alwaysApply: true in $sample"
    return
  fi

  local pyrule="$tmpbase/rules/elelem-python-coding-style.mdc"
  if [[ ! -f "$pyrule" ]]; then
    _fail "$name" "expected elelem-python-coding-style.mdc not present at rules root"
    return
  fi
  if ! head -10 "$pyrule" | grep -q 'globs:'; then
    _fail "$name" "python rule missing globs: line"
    return
  fi
  if ! head -10 "$pyrule" | grep -q 'alwaysApply: false'; then
    _fail "$name" "python rule missing alwaysApply: false"
    return
  fi

  local skill_md="$tmpbase/skills/debugging/SKILL.md"
  if [[ ! -f "$skill_md" ]]; then
    _fail "$name" "expected skills/debugging/SKILL.md not present"
    return
  fi
  if ! head -5 "$skill_md" | grep -q '^name: debugging$'; then
    _fail "$name" "debugging SKILL.md lost its name: frontmatter field"
    return
  fi

  local placeholder_hits
  placeholder_hits="$(find "$tmpbase" \( -name '*.mdc' -o -name 'SKILL.md' \) -type f -exec grep -l '{{' {} + 2>/dev/null || true)"
  if [[ -n "$placeholder_hits" ]]; then
    _fail "$name" "unsubstituted placeholders remain: $placeholder_hits"
    return
  fi

  if ! grep -RIl 'tracking tasks (no native task tracker in Cursor' "$tmpbase/skills" >/dev/null 2>&1; then
    _fail "$name" "skills did not receive cursor TASK_TRACKER_TOOL substitution"
    return
  fi
  if ! grep -RIl 'AskQuestion' "$tmpbase/skills" >/dev/null 2>&1; then
    _fail "$name" "skills did not receive cursor ASK_USER_QUESTION_TOOL substitution"
    return
  fi

  scan_no_unsubstituted_placeholders "$tmpbase/rules" || { _fail "$name" "scoped rules scan failed"; return; }
  scan_no_unsubstituted_placeholders "$tmpbase/skills" || { _fail "$name" "scoped skills scan failed"; return; }

  _pass "$name"
}

test_coexistence_three_manifests() {
  local name="coexistence_three_manifests"
  local tmphome
  tmphome="$(mktemp -d)"
  trap "rm -rf '$tmphome'" RETURN

  local claude_base="$tmphome/.claude"
  local opencode_base="$tmphome/.config/opencode"
  local cursor_base="$tmphome/.cursor"

  mkdir -p "$claude_base/rules/common" "$opencode_base/rules/common" "$cursor_base/rules/common"

  local manifest_claude=("rules/common/coding-style.md")
  local manifest_opencode=("rules/common/coding-style.md")
  local manifest_cursor=()

  cp "$REPO_ROOT/rules/common/coding-style.md" "$claude_base/rules/common/"
  cp "$REPO_ROOT/rules/common/coding-style.md" "$opencode_base/rules/common/"

  mkdir -p "$cursor_base/rules"
  local cursor_files=("coding-style.md")
  CURSOR_RULE_GROUP_PREFIX="common"
  install_files_from_dir "$REPO_ROOT/rules/common" "$cursor_base/rules" "rules" manifest_cursor cursor_files _cursor_rule_resolve_dst _cursor_rule_transform
  CURSOR_RULE_GROUP_PREFIX=""

  local mf_claude="$tmphome/.elelem-manifest-claude"
  local mf_opencode="$tmphome/.elelem-manifest-opencode"
  local mf_cursor="$tmphome/.elelem-manifest-cursor"

  write_manifest "$mf_claude" "$claude_base" manifest_claude
  write_manifest "$mf_opencode" "$opencode_base" manifest_opencode
  write_manifest "$mf_cursor" "$cursor_base" manifest_cursor

  if [[ ! -f "$mf_claude" ]] || [[ ! -f "$mf_opencode" ]] || [[ ! -f "$mf_cursor" ]]; then
    _fail "$name" "expected three distinct manifest files"
    return
  fi

  if [[ ! -f "$claude_base/rules/common/coding-style.md" ]]; then
    _fail "$name" "claude tree missing"; return
  fi
  if [[ ! -f "$opencode_base/rules/common/coding-style.md" ]]; then
    _fail "$name" "opencode tree missing"; return
  fi
  if [[ ! -f "$cursor_base/rules/elelem-common-coding-style.mdc" ]]; then
    _fail "$name" "cursor .mdc tree missing"; return
  fi

  _pass "$name"
}

test_install_cursor_dot_sh_main_flow_syntax() {
  local name="install_cursor_main_flow_syntax_clean"
  if bash -n "$REPO_ROOT/install-cursor.sh" 2>/dev/null; then
    _pass "$name"
  else
    _fail "$name" "bash -n install-cursor.sh failed"
  fi
}

test_install_dot_sh_offers_cursor() {
  local name="front_controller_offers_cursor"
  if grep -q '"Cursor"' "$REPO_ROOT/install.sh"; then
    _pass "$name"
  else
    _fail "$name" "install.sh harness_items array does not include Cursor"
  fi
}

test_post_install_scan_ignores_unrelated_files_under_base() {
  local name="post_install_scan_ignores_unrelated_files_under_base"
  local tmpbase
  tmpbase="$(mktemp -d)"
  trap "rm -rf '$tmpbase'" RETURN

  mkdir -p "$tmpbase/rules/common"
  mkdir -p "$tmpbase/skills"
  mkdir -p "$tmpbase/plugins/cache/third-party/skills/foo"

  cat > "$tmpbase/plugins/cache/third-party/skills/foo/SKILL.md" <<'PLUGIN'
---
name: foo
description: third-party
---

TODO: this is fine, it belongs to a different installer.
PLUGIN

  local manifest=()
  local common_files=("coding-style.md")
  install_files_from_dir "$REPO_ROOT/rules/common" "$tmpbase/rules/common" "rules/common" manifest common_files _cursor_rule_resolve_dst _cursor_rule_transform

  local rules_exit=0
  local skills_exit=0
  ( scan_no_unsubstituted_placeholders "$tmpbase/rules" ) || rules_exit=$?
  ( scan_no_unsubstituted_placeholders "$tmpbase/skills" ) || skills_exit=$?

  if (( rules_exit != 0 )) || (( skills_exit != 0 )); then
    _fail "$name" "scoped scan tripped on a clean install (rules=$rules_exit skills=$skills_exit)"
    return
  fi

  local broad_exit=0
  ( scan_no_unsubstituted_placeholders "$tmpbase" ) || broad_exit=$?
  if (( broad_exit == 0 )); then
    _fail "$name" "broad scan against \$base did not trip on a TODO marker that lives outside elelem's directories; the test setup is wrong"
    return
  fi

  _pass "$name"
}

test_install_cursor_dot_sh_main_flow_syntax
test_install_dot_sh_offers_cursor
test_full_install_to_tmp_user_scope
test_coexistence_three_manifests
test_post_install_scan_ignores_unrelated_files_under_base

total=$(( passed + failed ))
echo
echo "${passed}/${total} tests passed"
(( failed == 0 )) || exit 1
