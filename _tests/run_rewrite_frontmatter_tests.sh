#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FIXTURE_DIR="$SCRIPT_DIR/fixtures/rewrite_frontmatter"

# shellcheck source=../_install-common.sh
source "$REPO_ROOT/_install-common.sh"

passed=0
failed=0

run_positive_fixture() {
  local name="$1"
  local input="$FIXTURE_DIR/${name}.md"
  local expected="$FIXTURE_DIR/${name}.expected"
  local actual_file
  actual_file="$(mktemp)"

  local exit_code=0
  rewrite_frontmatter_for_cursor "$input" > "$actual_file" 2>/dev/null || exit_code=$?

  if [[ $exit_code -ne 0 ]]; then
    echo "[FAIL] $name: function returned non-zero ($exit_code)"
    rm -f "$actual_file"
    (( failed++ )) || true
    return
  fi

  local diff_output
  diff_output="$(diff "$actual_file" "$expected" 2>&1)" || true
  rm -f "$actual_file"

  if [[ -z "$diff_output" ]]; then
    echo "[PASS] $name"
    (( passed++ )) || true
  else
    echo "[FAIL] $name"
    echo "$diff_output"
    (( failed++ )) || true
  fi
}

run_positive_fixture "01_no_frontmatter"
run_positive_fixture "02_other_keys_only"
run_positive_fixture "03_globs_only"
run_positive_fixture "04_globs_with_comment"
run_positive_fixture "05_globs_plus_other_keys"

run_negative_fixture_06() {
  local name="06_empty_globs_negative"
  local input="$FIXTURE_DIR/${name}.md"

  local stderr_output
  local exit_code
  stderr_output="$(rewrite_frontmatter_for_cursor "$input" 2>&1 >/dev/null)" || exit_code=$?
  exit_code="${exit_code:-0}"

  if [[ $exit_code -eq 0 ]]; then
    echo "[FAIL] $name: expected non-zero exit but got 0"
    (( failed++ )) || true
    return
  fi

  if [[ "$stderr_output" != *"${name}.md"* ]]; then
    echo "[FAIL] $name: stderr does not contain '${name}.md': $stderr_output"
    (( failed++ )) || true
    return
  fi

  echo "[PASS] $name"
  (( passed++ )) || true
}

run_negative_fixture_06

total=$(( passed + failed ))
echo ""
echo "${passed}/${total} tests passed"

if (( failed > 0 )); then
  exit 1
fi
