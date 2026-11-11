#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export TMPDIR="${TMPDIR:-/tmp}"
source "$ROOT/_install-common.sh"
FIXTURE="$(mktemp -d "$TMPDIR/language-pack-tests.XXXXXX")" || exit 1
FIXTURE="$(cd "$FIXTURE" && pwd -P)" || exit 1
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

prepare_pack_fixture() {
  case_dir="$(mktemp -d "$FIXTURE/case.XXXXXX")"
  mkdir -p "$case_dir/source/alpha" "$case_dir/source/zeta" "$case_dir/source/common"
  printf '%s\n' '---' 'globs: **/*.alpha' '---' 'Alpha {{READ_TOOL}}' > "$case_dir/source/alpha/coding-style.md"
  printf '%s\n' '---' 'globs: **/*.test.alpha' '---' 'Test alpha' > "$case_dir/source/alpha/testing.md"
  printf '%s\n' '---' 'globs: **/alpha.json' '---' 'Tool alpha' > "$case_dir/source/alpha/tooling.md"
  printf '%s\n' '---' 'globs: **/*.zeta' '---' 'Zeta' > "$case_dir/source/zeta/coding-style.md"
  printf 'Never package common\n' > "$case_dir/source/common/coding-style.md"
  entries=()
  placeholders=(READ_TOOL READ_FILE_TOOL INVOKE_SKILL_TOOL)
  substitutions=('tools/read $HOME/@file & \\literal' 'read' 'skill')
}

install_fixture_packs() {
  install_language_packs "$case_dir/source" "$case_dir/base/skills" skills "$case_dir/old" entries placeholders substitutions
}

test_policy_activates_only_current_task_languages() {
  require_helper render_language_pack_policy
  local policy
  policy="$(render_language_pack_policy)"
  [[ "$policy" == *'elelem-language-'* && "$policy" == *'{{INVOKE_SKILL_TOOL}}'* ]]
  [[ "$policy" == *'reading'* && "$policy" == *'creating'* && "$policy" == *'reviewing'* ]]
  [[ "$policy" == *'scope grows'* && "$policy" == *'delegated'* ]]
  [[ "$policy" == *'incidental Markdown'* && "$policy" == *'repository language inventory'* ]]
  [[ "$policy" == *'ambiguous'* && "$policy" == *'block'* ]]
}

test_every_language_is_discoverable_without_eager_bodies() {
  require_helper install_language_packs
  local case_dir entries placeholders substitutions language source_file relative
  prepare_pack_fixture
  install_language_packs "$ROOT/rules" "$case_dir/base/skills" skills "$case_dir/old" entries placeholders substitutions
  for source_file in "$ROOT"/rules/*; do
    language="${source_file##*/}"
    [[ "$language" != common ]] || continue
    [[ -f "$case_dir/base/skills/elelem-language-$language/SKILL.md" ]]
    for source_file in "$ROOT/rules/$language"/*.md; do
      relative="skills/elelem-language-$language/references/${source_file##*/}"
      cmp "$source_file" "$case_dir/base/$relative"
      [[ " ${entries[*]} " == *" $relative "* ]]
    done
  done
  [[ ! -e "$case_dir/base/skills/elelem-language-common" ]]
  ! grep -R '^@' "$case_dir/base/skills"
  ! grep -R '{{' "$case_dir/base/skills"
}

test_wrappers_defer_applicable_relative_references() {
  require_helper install_language_packs
  local case_dir entries placeholders substitutions wrapper
  prepare_pack_fixture
  install_fixture_packs
  wrapper="$case_dir/base/skills/elelem-language-alpha/SKILL.md"
  grep -q '^name: elelem-language-alpha$' "$wrapper"
  grep '^description:' "$wrapper" | grep -F '**/*.alpha' | grep -Fq '**/alpha.json'
  grep -F 'references/coding-style.md' "$wrapper" | grep -Fq 'skill base'
  grep -F 'references/testing.md' "$wrapper" | grep -Fq 'test'
  grep -F 'references/tooling.md' "$wrapper" | grep -Fq 'tooling'
  grep -Fq 'actual task' "$wrapper"
  grep -Fq 'tools/read $HOME/@file & \\literal' "$case_dir/base/skills/elelem-language-alpha/references/coding-style.md"
}

test_all_unmanaged_collisions_are_checked_before_any_pack_write() {
  require_helper install_language_packs
  local case_dir entries placeholders substitutions
  prepare_pack_fixture
  mkdir -p "$case_dir/base/skills/elelem-language-zeta"
  printf 'user content\n' > "$case_dir/base/skills/elelem-language-zeta/SKILL.md"
  if install_fixture_packs > "$case_dir/log" 2>&1; then return 1; fi
  [[ ! -e "$case_dir/base/skills/elelem-language-alpha" ]]
  [[ "$(cat "$case_dir/base/skills/elelem-language-zeta/SKILL.md")" == 'user content' ]]
  [[ ${#entries[@]} == 0 ]]
  grep -q 'move or remove' "$case_dir/log"
}

test_symlinked_destination_parents_are_not_followed() {
  require_helper install_language_packs
  local case_dir entries placeholders substitutions
  prepare_pack_fixture
  mkdir -p "$case_dir/base" "$case_dir/elsewhere"
  ln -s "$case_dir/elsewhere" "$case_dir/base/skills"
  if install_fixture_packs > "$case_dir/log" 2>&1; then return 1; fi
  [[ -z "$(ls -A "$case_dir/elsewhere")" ]]
}

test_managed_files_can_be_replaced_without_claiming_unmanaged_files() {
  require_helper install_language_packs
  local case_dir entries placeholders substitutions
  prepare_pack_fixture
  install_fixture_packs
  printf '%s\n' "$case_dir/base" "${entries[@]}" > "$case_dir/old"
  printf 'modified managed\n' > "$case_dir/base/skills/elelem-language-alpha/SKILL.md"
  entries=()
  install_fixture_packs
  grep -q '^name: elelem-language-alpha$' "$case_dir/base/skills/elelem-language-alpha/SKILL.md"
  printf 'unmanaged\n' > "$case_dir/base/skills/elelem-language-zeta/notes.md"
  printf 'sentinel\n' > "$case_dir/base/skills/elelem-language-alpha/SKILL.md"
  if install_fixture_packs > "$case_dir/log" 2>&1; then return 1; fi
  [[ "$(cat "$case_dir/base/skills/elelem-language-alpha/SKILL.md")" == sentinel ]]
}

test_unexpanded_reference_placeholders_block_publication() {
  require_helper install_language_packs
  local case_dir entries placeholders substitutions
  prepare_pack_fixture
  printf '{{UNKNOWN_TOOL}}\n' >> "$case_dir/source/zeta/coding-style.md"
  if install_fixture_packs > "$case_dir/log" 2>&1; then return 1; fi
  [[ ! -e "$case_dir/base/skills/elelem-language-alpha/SKILL.md" ]]
  [[ ${#entries[@]} == 0 ]]
}

assert_runner_honours_caller_temporary_root() {
  local directory runner="$1"
  directory="$(mktemp -d "$FIXTURE/caller-root.XXXXXX")"
  TMPDIR="$directory" ELELEM_TEST_RUNNER_CHILD=1 bash -x "$ROOT/_tests/$runner" > "$directory/$runner.log" 2>&1 || true
  if ! grep -Fq "++ mktemp -d $directory/" "$directory/$runner.log"; then
    echo "Expected $runner to create its fixture under caller TMPDIR"
    return 1
  fi
}

assert_runner_stops_when_temporary_root_is_missing() {
  local directory runner="$1" status
  directory="$(mktemp -d "$FIXTURE/missing-root.XXXXXX")"
  if TMPDIR="$directory/absent" ELELEM_TEST_RUNNER_CHILD=1 bash "$ROOT/_tests/$runner" > "$directory/$runner.log" 2>&1; then
    status=0
  else
    status=$?
  fi
  if (( status == 0 )) || grep -Eq '^\[(PASS|FAIL)\]' "$directory/$runner.log"; then
    echo "Expected $runner to abort fixture creation before running any tests"
    return 1
  fi
  grep -q 'mktemp' "$directory/$runner.log"
  [[ ! -e "$directory/absent" ]]
}

test_language_runner_honours_caller_temporary_root() {
  assert_runner_honours_caller_temporary_root run_language_pack_helpers_tests.sh
}

test_ownership_runner_honours_caller_temporary_root() {
  assert_runner_honours_caller_temporary_root run_opencode_instruction_ownership_tests.sh
}

test_language_runner_stops_when_temporary_root_is_missing() {
  assert_runner_stops_when_temporary_root_is_missing run_language_pack_helpers_tests.sh
}

test_ownership_runner_stops_when_temporary_root_is_missing() {
  assert_runner_stops_when_temporary_root_is_missing run_opencode_instruction_ownership_tests.sh
}

run_test test_policy_activates_only_current_task_languages
run_test test_every_language_is_discoverable_without_eager_bodies
run_test test_wrappers_defer_applicable_relative_references
run_test test_all_unmanaged_collisions_are_checked_before_any_pack_write
run_test test_symlinked_destination_parents_are_not_followed
run_test test_managed_files_can_be_replaced_without_claiming_unmanaged_files
run_test test_unexpanded_reference_placeholders_block_publication
if [[ "${ELELEM_TEST_RUNNER_CHILD:-0}" != 1 ]]; then
  run_test test_language_runner_honours_caller_temporary_root
  run_test test_ownership_runner_honours_caller_temporary_root
  run_test test_language_runner_stops_when_temporary_root_is_missing
  run_test test_ownership_runner_stops_when_temporary_root_is_missing
fi
echo "$passed/$((passed + failed)) tests passed"
(( failed == 0 ))
