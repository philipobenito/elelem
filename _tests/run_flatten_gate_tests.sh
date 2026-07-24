#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

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

test_no_unflattened_placeholder_tokens_remain_in_rules_or_skills() {
  local name="no_unflattened_placeholder_tokens_remain_in_rules_or_skills"
  local matches
  matches="$(grep -rEn '\{\{[A-Z_]+\}\}' "$REPO_ROOT/rules" "$REPO_ROOT/skills" 2>/dev/null || true)"

  if [[ -n "$matches" ]]; then
    _fail "$name" "unflattened {{TOKEN}} placeholder(s) found:
$matches"
    return
  fi

  _pass "$name"
}

test_no_todowrite_references_remain_in_rules_or_skills() {
  local name="no_todowrite_references_remain_in_rules_or_skills"
  local matches
  matches="$(grep -rn 'TodoWrite' "$REPO_ROOT/rules" "$REPO_ROOT/skills" 2>/dev/null || true)"

  if [[ -n "$matches" ]]; then
    _fail "$name" "TodoWrite reference(s) found (TodoWrite no longer exists; use the Task* family):
$matches"
    return
  fi

  _pass "$name"
}

test_no_unflattened_placeholder_tokens_remain_in_rules_or_skills
test_no_todowrite_references_remain_in_rules_or_skills

total=$(( passed + failed ))
echo
echo "$passed/$total tests passed"
(( failed == 0 ))
