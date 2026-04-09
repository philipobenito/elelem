#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../_install-common.sh
source "$REPO_ROOT/_install-common.sh"

# shellcheck source=../install-codex.sh
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

test_install_codex_exists() {
  local name="install_codex_exists"

  if [[ -f "$REPO_ROOT/install-codex.sh" ]]; then
    _pass "$name"
  else
    _fail "$name" "install-codex.sh does not exist"
  fi
}

test_install_codex_executable() {
  local name="install_codex_executable"

  if [[ -x "$REPO_ROOT/install-codex.sh" ]]; then
    _pass "$name"
  else
    _fail "$name" "install-codex.sh is not executable"
  fi
}

test_codex_resolve_targets_user_scope_populates_caller_variables() {
  local name="codex_resolve_targets_user_scope_populates_caller_variables"
  local original_singleselect
  original_singleselect="$(declare -f singleselect)"

  singleselect() {
    local result_var="$1"
    eval "${result_var}='user  ->  ~/.codex/AGENTS.md + ~/.agents/skills/'"
  }

  local base agents_target skills_target
  codex_resolve_targets base agents_target skills_target >/dev/null

  eval "$original_singleselect"

  if [[ "$base" == "$HOME" ]] && [[ "$agents_target" == "$HOME/.codex/AGENTS.md" ]] && [[ "$skills_target" == "$HOME/.agents/skills" ]]; then
    _pass "$name"
  else
    _fail "$name" "expected base=$HOME agents=$HOME/.codex/AGENTS.md skills=$HOME/.agents/skills, got base=$base agents=$agents_target skills=$skills_target"
  fi
}

test_codex_skill_resolve_dst_preserves_subdirectory_structure() {
  local name="codex_skill_resolve_dst_preserves_subdirectory_structure"
  local result

  result="$(_codex_skill_resolve_dst "$SKILLS_SOURCE/debugging/SKILL.md" /out)"

  if [[ "$result" == "/out/debugging/SKILL.md" ]]; then
    _pass "$name"
  else
    _fail "$name" "expected /out/debugging/SKILL.md, got $result"
  fi
}

test_codex_skill_resolve_dst_preserves_nested_files() {
  local name="codex_skill_resolve_dst_preserves_nested_files"
  local result

  result="$(_codex_skill_resolve_dst "$SKILLS_SOURCE/brainstorming/modes/standard.md" /out)"

  if [[ "$result" == "/out/brainstorming/modes/standard.md" ]]; then
    _pass "$name"
  else
    _fail "$name" "expected /out/brainstorming/modes/standard.md, got $result"
  fi
}

test_codex_render_agents_payload_strips_frontmatter_and_substitutes_placeholders() {
  local name="codex_render_agents_payload_strips_frontmatter_and_substitutes_placeholders"
  local tmpfile
  tmpfile="$(mktemp)"
  trap "rm -f '$tmpfile'" RETURN

  local common_files=("skills-policy.md")
  local lang_dirs=("python")

  _codex_render_agents_payload "$tmpfile" common_files lang_dirs

  if grep -q '^globs:' "$tmpfile"; then
    _fail "$name" "language-pack frontmatter was not stripped"
    return
  fi

  if grep -q '{{' "$tmpfile"; then
    _fail "$name" "unsubstituted placeholders remain in rendered payload"
    return
  fi

  if ! grep -Fq '/skills or $skill-name' "$tmpfile"; then
    _fail "$name" "expected Codex skill substitution not found"
    return
  fi

  if ! grep -q 'Language-pack behaviour' "$tmpfile"; then
    _fail "$name" "expected language-pack guidance missing"
    return
  fi

  _pass "$name"
}

test_codex_upsert_managed_block_preserves_user_content_and_replaces_existing_block() {
  local name="codex_upsert_managed_block_preserves_user_content_and_replaces_existing_block"
  local tmpdir target payload_one payload_two
  tmpdir="$(mktemp -d)"
  trap "rm -rf '$tmpdir'" RETURN

  target="$tmpdir/AGENTS.md"
  payload_one="$tmpdir/payload-one.md"
  payload_two="$tmpdir/payload-two.md"

  cat > "$target" <<'EOF'
# Project Instructions

Human-authored content stays here.
EOF

  cat > "$payload_one" <<'EOF'
# elelem for Codex

first block
EOF

  cat > "$payload_two" <<'EOF'
# elelem for Codex

second block
EOF

  _codex_upsert_managed_block "$target" "$payload_one"
  _codex_upsert_managed_block "$target" "$payload_two"

  if ! grep -q 'Human-authored content stays here.' "$target"; then
    _fail "$name" "user content was not preserved"
    return
  fi

  if grep -q 'first block' "$target"; then
    _fail "$name" "old managed block content was not replaced"
    return
  fi

  if ! grep -q 'second block' "$target"; then
    _fail "$name" "new managed block content missing"
    return
  fi

  if [[ "$(grep -c 'elelem:codex:start' "$target")" -ne 1 ]]; then
    _fail "$name" "expected exactly one managed block"
    return
  fi

  _pass "$name"
}

test_install_codex_exists
test_install_codex_executable
test_codex_resolve_targets_user_scope_populates_caller_variables
test_codex_skill_resolve_dst_preserves_subdirectory_structure
test_codex_skill_resolve_dst_preserves_nested_files
test_codex_render_agents_payload_strips_frontmatter_and_substitutes_placeholders
test_codex_upsert_managed_block_preserves_user_content_and_replaces_existing_block

total=$(( passed + failed ))
echo
echo "${passed}/${total} tests passed"
(( failed == 0 )) || exit 1
