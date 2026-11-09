#!/usr/bin/env bash
set -uo pipefail

if [[ -z "${ELELEM_TEST_ROOT:-}" || ! -d "$ELELEM_TEST_ROOT" ]]; then
  printf 'ELELEM_TEST_ROOT must name an existing fixture directory\n' >&2
  exit 2
fi

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$repository_root/_install-common.sh"

fixture_root="$(mktemp -d "$ELELEM_TEST_ROOT/agent-manifest.XXXXXX")"
fixture_name="${fixture_root##*/}"
sort_fixture_directory="$ELELEM_TEST_ROOT/bin/$fixture_name"
mkdir -p "$sort_fixture_directory"

passed=0
failed=0

run_case() {
  local description="$1"
  local test_function="$2"
  if "$test_function"; then
    printf '[PASS] %s\n' "$description"
    passed=$((passed + 1))
  else
    printf '[FAIL] %s\n' "$description"
    failed=$((failed + 1))
  fi
}

manifest_entries_contain() {
  local expected_entry="$1"
  shift
  local entry
  for entry in "$@"; do
    [[ "$entry" == "$expected_entry" ]] && return 0
  done
  return 1
}

test_write_manifest_rejects_a_different_existing_base_without_changing_the_manifest() {
  local case_directory="$fixture_root/base-mismatch"
  local manifest_file="$case_directory/manifest"
  local expected_manifest="$case_directory/expected-manifest"
  local old_base="$case_directory/old-base"
  local new_base="$case_directory/new-base"
  local entries=("agents/new.md")
  local write_status=0

  mkdir -p "$old_base" "$new_base"
  printf '%s\n%s\n' "$old_base" 'agents/old.md' > "$manifest_file"
  cp "$manifest_file" "$expected_manifest"

  if write_manifest "$manifest_file" "$new_base" entries 2>/dev/null; then
    write_status=0
  else
    write_status=$?
  fi

  (( write_status != 0 )) && cmp -s "$manifest_file" "$expected_manifest"
}

test_prune_stale_manifest_entries_preserves_omitted_agent_bundle_files() {
  local case_directory="$fixture_root/preserved-bundle"
  local base="$case_directory/base"
  local manifest_file="$case_directory/manifest"
  local old_bundle_file="$base/agents/old.md"
  local bundle_licence="$base/agents.LICENSE"
  local manifest_entries=()

  mkdir -p "$base/agents"
  printf '%s\n' "$base" 'agents/old.md' 'agents.LICENSE' > "$manifest_file"
  printf 'old agent bundle file\n' > "$old_bundle_file"
  printf 'old agent bundle licence\n' > "$bundle_licence"

  prune_stale_manifest_entries "$manifest_file" "$base" manifest_entries agents

  [[ -f "$old_bundle_file" ]] &&
    [[ -f "$bundle_licence" ]] &&
    manifest_entries_contain 'agents/old.md' "${manifest_entries[@]}" &&
    manifest_entries_contain 'agents.LICENSE' "${manifest_entries[@]}"
}

test_write_manifest_preserves_an_existing_manifest_when_staging_fails() {
  local case_directory="$fixture_root/staging-failure"
  local manifest_file="$case_directory/manifest"
  local expected_manifest="$case_directory/expected-manifest"
  local base="$case_directory/base"
  local entries=("agents/new.md")
  local original_path="$PATH"
  local write_status=0

  mkdir -p "$base" "$sort_fixture_directory"
  printf '%s\n%s\n' "$base" 'agents/old.md' > "$manifest_file"
  cp "$manifest_file" "$expected_manifest"
  cat > "$sort_fixture_directory/sort" <<'SORT'
#!/bin/sh
exit 1
SORT
  chmod +x "$sort_fixture_directory/sort"

  PATH="$sort_fixture_directory:$original_path"
  export PATH
  if write_manifest "$manifest_file" "$base" entries 2>/dev/null; then
    write_status=0
  else
    write_status=$?
  fi
  PATH="$original_path"
  export PATH

  (( write_status != 0 )) && cmp -s "$manifest_file" "$expected_manifest"
}

test_write_manifest_replaces_an_existing_manifest_for_the_same_base_with_sorted_entries() {
  local case_directory="$fixture_root/same-base-replacement"
  local base="$case_directory/base"
  local manifest_file="$case_directory/manifest"
  local expected_manifest="$case_directory/expected-manifest"
  local selected_manifest_entries=('agents/zeta.md' 'agents/alpha.md')

  mkdir -p "$base"
  printf '%s\n%s\n' "$base" 'agents/old.md' > "$manifest_file"
  printf '%s\n%s\n%s\n' "$base" 'agents/alpha.md' 'agents/zeta.md' > "$expected_manifest"

  write_manifest "$manifest_file" "$base" selected_manifest_entries || return 1

  cmp -s "$manifest_file" "$expected_manifest"
}

run_case 'write_manifest rejects a different existing base without changing the manifest' test_write_manifest_rejects_a_different_existing_base_without_changing_the_manifest
run_case 'prune_stale_manifest_entries preserves omitted agent bundle files' test_prune_stale_manifest_entries_preserves_omitted_agent_bundle_files
run_case 'write_manifest preserves an existing manifest when staging fails' test_write_manifest_preserves_an_existing_manifest_when_staging_fails
run_case 'write_manifest replaces an existing manifest for the same base with sorted entries' test_write_manifest_replaces_an_existing_manifest_for_the_same_base_with_sorted_entries

printf 'Tests: %d passed, %d failed\n' "$passed" "$failed"
[[ "$failed" -eq 0 ]]
