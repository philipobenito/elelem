#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export TMPDIR="${TMPDIR:-/tmp}"
source "$ROOT/_install-common.sh"
FIXTURE="$(mktemp -d "$TMPDIR/opencode-ownership-tests.XXXXXX")" || exit 1
trap 'rm -rf "$FIXTURE"' EXIT
passed=0
failed=0

require_helper() {
  declare -F "$1" >/dev/null || { echo "Expected helper contract '$1' to be available"; return 1; }
}

run_test() {
  ( set -e; "$1" )
  local status=$?
  if (( status == 0 )); then
    echo "[PASS] $1"
    passed=$((passed + 1))
  else
    echo "[FAIL] $1"
    failed=$((failed + 1))
  fi
}

prepare_config_fixture() {
  case_dir="$(mktemp -d "$FIXTURE/case.XXXXXX")"
  target="$case_dir/opencode.json"
  ownership="$case_dir/.elelem-opencode-instructions.json"
  old="$case_dir/old"
  printf '%s\n' '{"instructions":["personal.md"],"permission":{"edit":"ask"},"model":"custom"}' > "$target"
}

record_config_ownership() {
  printf '%s\n' "$case_dir" "${ownership##*/}" > "$old"
}

assert_unmanifested_ownership_is_rejected() {
  local operation="$1" manifest_state="$2" case_dir target ownership old
  prepare_config_fixture
  printf '{"instructions":["personal.md"]}' > "$ownership"
  [[ "$manifest_state" != present ]] || printf '%s\n' "$case_dir" rules/common/testing.md > "$old"
  cp "$target" "$case_dir/config-before"
  cp "$ownership" "$case_dir/owner-before"
  if "$operation" "$target" "$old" "$ownership" rules/elelem-language-packs.md > "$case_dir/output" 2>&1; then
    echo "Expected $operation to reject unmanifested ownership ($manifest_state manifest)"
    return 1
  fi
  cmp "$target" "$case_dir/config-before"
  cmp "$ownership" "$case_dir/owner-before"
}

test_update_rejects_unmanifested_ownership() {
  assert_unmanifested_ownership_is_rejected update_opencode_instructions absent
}

test_update_rejects_metadata_absent_from_existing_manifest() {
  assert_unmanifested_ownership_is_rejected update_opencode_instructions present
}

test_removal_rejects_unmanifested_ownership() {
  assert_unmanifested_ownership_is_rejected remove_opencode_instructions absent
}

test_removal_rejects_metadata_absent_from_existing_manifest() {
  assert_unmanifested_ownership_is_rejected remove_opencode_instructions present
}

test_update_preserves_shared_configuration() {
  require_helper update_opencode_instructions
  local case_dir target ownership old
  prepare_config_fixture
  update_opencode_instructions "$target" "$old" "$ownership" 'rules/common/*.md'
  jq -e '.instructions == ["personal.md","rules/common/*.md"] and .model == "custom" and .permission.edit == "ask"' "$target" > /dev/null
  jq -e '.instructions == ["rules/common/*.md"]' "$ownership" > /dev/null
  record_config_ownership
  update_opencode_instructions "$target" "$old" "$ownership" 'rules/elelem-language-packs.md'
  jq -e '.instructions == ["personal.md","rules/elelem-language-packs.md"]' "$target" > /dev/null
}

test_uninstall_removes_exact_owned_entries_without_deleting_shared_config() {
  require_helper remove_opencode_instructions
  require_helper update_opencode_instructions
  local case_dir target ownership old
  prepare_config_fixture
  update_opencode_instructions "$target" "$old" "$ownership" 'rules/common/*.md'
  record_config_ownership
  remove_opencode_instructions "$target" "$old" "$ownership"
  jq -e '.instructions == ["personal.md"] and .model == "custom"' "$target" > /dev/null
  [[ -f "$ownership" ]]
  remove_opencode_instructions "$target" "$old" "$ownership"
  jq -e '.instructions == ["personal.md"]' "$target" > /dev/null
}

test_legacy_rule_paths_identify_only_their_exact_globs() {
  require_helper update_opencode_instructions
  local case_dir target ownership old
  prepare_config_fixture
  printf '%s\n' "$case_dir" opencode.json rules/common/coding-style.md rules/python/testing.md > "$old"
  printf '%s\n' '{"instructions":["personal.md","rules/common/*.md","rules/python/*.md","custom/rules/**/*.md"],"model":"custom"}' > "$target"
  update_opencode_instructions "$target" "$old" "$ownership" rules/elelem-language-packs.md 2> "$case_dir/warnings"
  jq -e '.instructions == ["personal.md","custom/rules/**/*.md","rules/elelem-language-packs.md"]' "$target" > /dev/null
  grep -q 'preserv' "$case_dir/warnings"
}

test_legacy_whole_config_without_rule_evidence_blocks_changes() {
  require_helper remove_opencode_instructions
  local case_dir target ownership old
  prepare_config_fixture
  printf '%s\n' "$case_dir" opencode.json > "$old"
  cp "$target" "$case_dir/before"
  if remove_opencode_instructions "$target" "$old" "$ownership" 2> "$case_dir/error"; then return 1; fi
  cmp "$target" "$case_dir/before"
  [[ -f "$old" && ! -e "$ownership" ]]
}

test_config_symlink_survives_instruction_lifecycle() {
  require_helper update_opencode_instructions
  require_helper remove_opencode_instructions
  local case_dir target ownership old
  prepare_config_fixture
  mv "$target" "$case_dir/actual.json"
  ln -s "$case_dir/actual.json" "$target"
  update_opencode_instructions "$target" "$old" "$ownership" rules/elelem-language-packs.md
  record_config_ownership
  remove_opencode_instructions "$target" "$old" "$ownership"
  [[ -L "$target" ]]
  jq -e '.instructions == ["personal.md"] and .model == "custom"' "$case_dir/actual.json" > /dev/null
}

test_invalid_config_leaves_both_files_unchanged() {
  require_helper update_opencode_instructions
  local case_dir target ownership old invalid
  prepare_config_fixture
  record_config_ownership
  for invalid in '{broken' '[]' '{"instructions":"wrong"}' '{"instructions":[3]}' '{"instructions":null}'; do
    printf '%s' "$invalid" > "$target"
    printf '{"instructions":["owned"]}' > "$ownership"
    cp "$target" "$case_dir/config-before"
    cp "$ownership" "$case_dir/owner-before"
    if update_opencode_instructions "$target" "$old" "$ownership" new 2> "$case_dir/error"; then return 1; fi
    cmp "$target" "$case_dir/config-before"
    cmp "$ownership" "$case_dir/owner-before"
  done
}

test_invalid_ownership_leaves_both_files_unchanged() {
  require_helper update_opencode_instructions
  local case_dir target ownership old invalid
  prepare_config_fixture
  record_config_ownership
  printf '{"instructions":[]}' > "$target"
  for invalid in '{broken' '[]' '{}' '{"instructions":[false]}'; do
    printf '%s' "$invalid" > "$ownership"
    cp "$ownership" "$case_dir/owner-before"
    if update_opencode_instructions "$target" "$old" "$ownership" new 2> "$case_dir/error"; then return 1; fi
    [[ "$(cat "$target")" == '{"instructions":[]}' ]]
    cmp "$ownership" "$case_dir/owner-before"
  done
}

test_requested_instruction_order_is_preserved() {
  require_helper update_opencode_instructions
  local case_dir target ownership old
  prepare_config_fixture
  update_opencode_instructions "$target" "$old" "$ownership" rules/z-bootstrap.md 'rules/common/*.md'
  jq -e '.instructions == ["personal.md","rules/z-bootstrap.md","rules/common/*.md"]' "$target" > /dev/null
  jq -e '.instructions == ["rules/z-bootstrap.md","rules/common/*.md"]' "$ownership" > /dev/null
}

test_unowned_requested_entry_is_a_collision_not_new_ownership() {
  require_helper update_opencode_instructions
  local case_dir target ownership old
  prepare_config_fixture
  cp "$target" "$case_dir/before"
  if update_opencode_instructions "$target" "$old" "$ownership" personal.md 2> "$case_dir/error"; then return 1; fi
  cmp "$target" "$case_dir/before"
  [[ ! -e "$ownership" ]]
}

test_missing_jq_does_not_modify_config_or_retry_metadata() {
  require_helper remove_opencode_instructions
  local case_dir target ownership old
  prepare_config_fixture
  printf '{"instructions":["owned"]}' > "$ownership"
  record_config_ownership
  cp "$target" "$case_dir/before"
  if ( PATH="$case_dir/no-tools"; remove_opencode_instructions "$target" "$old" "$ownership" ) 2> "$case_dir/error"; then return 1; fi
  cmp "$target" "$case_dir/before"
  [[ "$(cat "$ownership")" == '{"instructions":["owned"]}' ]]
}

test_absent_config_is_created_with_exact_ownership() {
  require_helper update_opencode_instructions
  local case_dir target ownership old
  prepare_config_fixture
  rm "$target"
  update_opencode_instructions "$target" "$old" "$ownership" rules/elelem-language-packs.md
  jq -e '.instructions == ["rules/elelem-language-packs.md"] and ."$schema" == "https://opencode.ai/config.json"' "$target" > /dev/null
}

test_stale_prune_retains_legacy_shared_config() {
  local case_dir target ownership old entries=()
  prepare_config_fixture
  mkdir -p "$case_dir/rules/python"
  printf stale > "$case_dir/rules/python/testing.md"
  printf '%s\n' "$case_dir" opencode.json rules/python/testing.md > "$old"
  prune_stale_manifest_entries "$old" "$case_dir" entries
  [[ -f "$target" && ! -e "$case_dir/rules/python/testing.md" ]]
}

run_test test_update_preserves_shared_configuration
run_test test_uninstall_removes_exact_owned_entries_without_deleting_shared_config
run_test test_legacy_rule_paths_identify_only_their_exact_globs
run_test test_legacy_whole_config_without_rule_evidence_blocks_changes
run_test test_config_symlink_survives_instruction_lifecycle
run_test test_invalid_config_leaves_both_files_unchanged
run_test test_invalid_ownership_leaves_both_files_unchanged
run_test test_unowned_requested_entry_is_a_collision_not_new_ownership
run_test test_missing_jq_does_not_modify_config_or_retry_metadata
run_test test_absent_config_is_created_with_exact_ownership
run_test test_stale_prune_retains_legacy_shared_config
run_test test_requested_instruction_order_is_preserved
run_test test_update_rejects_unmanifested_ownership
run_test test_removal_rejects_unmanifested_ownership
run_test test_update_rejects_metadata_absent_from_existing_manifest
run_test test_removal_rejects_metadata_absent_from_existing_manifest
echo "$passed/$((passed + failed)) tests passed"
(( failed == 0 ))
