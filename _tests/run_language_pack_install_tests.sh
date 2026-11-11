#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "$0")/.." && pwd -P)"
fixture_parent="${ELELEM_TEST_ROOT:?Set ELELEM_TEST_ROOT to a retained fixture directory}"
mkdir -p "$fixture_parent"
fixture_parent="$(cd "$fixture_parent" && pwd -P)"

prepare_fixture() {
  harness="$1"
  scope="$2"
  case_root="$(mktemp -d "$fixture_parent/$harness-$scope.XXXXXX")"
  mkdir -p "$case_root/invocation" "$case_root/project" "$case_root/home" "$case_root/tmp"
  cp "$repository_root/install-$harness.sh" "$repository_root/uninstall.sh" "$repository_root/_install-common.sh" "$case_root/invocation/"
  cp -R "$repository_root/rules" "$repository_root/skills" "$case_root/invocation/"
  mkdir -p "$case_root/invocation/agents"
  cp "$repository_root/agents/LICENSE" "$case_root/invocation/agents/"
  cp -R "$repository_root/agents/$harness" "$case_root/invocation/agents/"
  base="$case_root/home/.claude"
  [[ "$harness" != opencode ]] || base="$case_root/home/.config/opencode"
  [[ "$scope" != project ]] || base="$case_root/project/.$harness"
  manifest="$case_root/invocation/.elelem-manifest-$harness"
}

run_installer() {
  local common_count
  common_count="$(find "$case_root/invocation/rules/common" -name '*.md' | wc -l | tr -d ' ')"
  (cd "$case_root/project"; HOME="$case_root/home" TERM=xterm NO_COLOR=1 TMPDIR="$case_root/tmp" expect -f - "$case_root/invocation/install-$harness.sh" "$scope" "$common_count" "${1:-decline}" "${2:-decline}" "${3:-decline}" > "$case_root/install.log" 2>&1 <<'EOF'
set timeout 30
spawn /bin/bash [lindex $argv 0]
expect_before eof {set result [wait]; exit [lindex $result 3]}
expect "Use"
if {[lindex $argv 1] eq "project"} {send "\033\[A"}
send "\r"
if {[lindex $argv 1] eq "project"} {expect "Project path"; send "\r"}
expect "Common instruction files to install:"
expect "Select items"
if {[lindex $argv 3] eq "decline"} {
  for {set index 0} {$index < [lindex $argv 2]} {incr index} {send " \033\[B"}
  send "\r"
  expect "Continue with no common rules"
  send " \r"
} else {send "\r"}
expect {
  "Language packs to install" {send "\r"; exp_continue}
  -re {> \[x\] Install skills} {if {[lindex $argv 5] eq "install"} {send "\r"} else {send " \r"}; exp_continue}
  -re {> \[ \] Elelem agent bundle} {if {[lindex $argv 4] eq "install"} {send " \r"} else {send "\r"}; exp_continue}
  timeout {exit 124}
  eof {set result [wait]; exit [lindex $result 3]}
}
EOF
  )
}

assert_all_packs() {
  local source language wrapper read_tool=Read skill_tool=Skill
  [[ "$harness" != opencode ]] || { read_tool=read; skill_tool=skill; }
  [[ -f "$base/rules/elelem-language-packs.md" ]] || { echo 'Missing mandatory activation bootstrap'; return 1; }
  ! grep -Fq '{{' "$base/rules/elelem-language-packs.md"
  grep -Fq "with \`$skill_tool\`" "$base/rules/elelem-language-packs.md"
  [[ ! -d "$base/rules/common" && ! -d "$base/skills/workflow-coordinator" ]]
  for source in "$repository_root"/rules/*; do
    language="${source##*/}"
    [[ "$language" != common ]] || continue
    wrapper="$base/skills/elelem-language-$language/SKILL.md"
    [[ -f "$wrapper" ]] || { echo "Missing language skill: $language"; return 1; }
    grep -Fq "Use \`$read_tool\` to read" "$wrapper"
    [[ ! -d "$base/rules/$language" ]]
    assert_topic_references "$source" "$wrapper" "$language"
  done
  ! grep -R -Fq '{{' "$base/skills"
}

assert_topic_references() {
  local source="$1" wrapper="$2" language="$3" topic
  for topic in "$source"/*.md; do
    [[ -f "$base/skills/elelem-language-$language/references/${topic##*/}" ]]
    grep -Fq "references/${topic##*/}" "$wrapper"
    grep -Fxq "skills/elelem-language-$language/references/${topic##*/}" "$manifest"
  done
}

test_mandatory_delivery() {
  local selected_harness selected_scope
  for selected_harness in claude opencode; do
    for selected_scope in user project; do
      prepare_fixture "$selected_harness" "$selected_scope"
      run_installer
      assert_all_packs
      assert_deferred_instructions
      ! grep -Fq 'Language packs to install' "$case_root/install.log"
    done
  done
}

assert_deferred_instructions() {
  [[ "$harness" == opencode ]] || return 0
  jq -e '.instructions == ["rules/elelem-language-packs.md"]' "$base/opencode.json" >/dev/null
  jq -e '.instructions == ["rules/elelem-language-packs.md"]' "$base/.elelem-opencode-instructions.json" >/dev/null
  ! grep -Fxq opencode.json "$manifest"
  grep -Fq '(rules/elelem-language-packs.md)' "$base/AGENTS.md"
  ! grep -Eq 'rules/(go|javascript|php|python|rust|typescript)/' "$base/AGENTS.md"
}

run_uninstaller() {
  (cd "$case_root/project"; HOME="$case_root/home" TERM=xterm NO_COLOR=1 TMPDIR="$case_root/tmp" PATH="${uninstall_command_path:-$PATH}" /usr/bin/expect -f - "$case_root/invocation/uninstall.sh" > "$case_root/uninstall.log" 2>&1 <<'EOF'
set timeout 30
spawn /bin/bash [lindex $argv 0]
expect_before eof {set result [wait]; exit [lindex $result 3]}
expect "Select manifests to uninstall:"
expect "Select items"
send " \r"
expect "Proceed with removal"
send " \r"
expect {
  timeout {exit 124}
  eof {set result [wait]; exit [lindex $result 3]}
}
EOF
  )
}

seed_shared_config() {
  mkdir -p "$base"
  printf '%s\n' '{"instructions":["personal.md"],"model":"custom","permission":{"edit":"ask"}}' > "$case_root/shared.json"
  ln -s "$case_root/shared.json" "$base/opencode.json"
}

test_uninstall_preserves_shared_config() {
  local selected_scope
  for selected_scope in user project; do
    prepare_fixture opencode "$selected_scope"
    seed_shared_config
    run_installer
    cp "$manifest" "$case_root/manifest.before"
    run_uninstaller
    [[ -L "$base/opencode.json" ]] || { echo 'Uninstall deleted shared config symlink'; return 1; }
    jq -e '.instructions == ["personal.md"] and .model == "custom" and .permission.edit == "ask"' "$base/opencode.json" >/dev/null || { echo 'Uninstall retained owned eager instructions'; return 1; }
    [[ ! -e "$manifest" && ! -e "$base/.elelem-opencode-instructions.json" ]]
    [[ ! -e "$base/skills/elelem-language-python/SKILL.md" && ! -e "$base/rules/elelem-language-packs.md" ]]
    assert_managed_files_absent
  done
}

assert_managed_files_absent() {
  local entry
  while IFS= read -r entry; do
    [[ "$entry" != opencode.json ]] || continue
    [[ ! -e "$base/$entry" && ! -L "$base/$entry" ]]
  done < <(tail -n +2 "$case_root/manifest.before")
}

corrupt_uninstall_input() {
  case "$1" in
    config) printf '{broken' > "$base/opencode.json" ;;
    ownership) printf '{broken' > "$base/.elelem-opencode-instructions.json" ;;
    unknown) printf '%s\n' "$base" opencode.json .elelem-opencode-instructions.json > "$manifest"; rm "$base/.elelem-opencode-instructions.json" ;;
    legacy_unknown) printf '%s\n' "$base" opencode.json > "$manifest"; rm "$base/.elelem-opencode-instructions.json" ;;
    manifest) printf '%s\n' "$base" ../outside > "$manifest" ;;
  esac
  cp "$manifest" "$case_root/manifest.before"
  cp "$base/opencode.json" "$case_root/config.before"
  [[ ! -f "$base/.elelem-opencode-instructions.json" ]] || cp "$base/.elelem-opencode-instructions.json" "$case_root/ownership.before"
}

test_uninstall_failure_retains_retry_evidence() {
  local corruption
  for corruption in config ownership unknown legacy_unknown manifest; do
    prepare_fixture opencode user
    seed_shared_config
    run_installer
    corrupt_uninstall_input "$corruption"
    if run_uninstaller; then echo "Uninstall unexpectedly succeeded with $corruption"; return 1; fi
    cmp "$manifest" "$case_root/manifest.before"
    cmp "$base/opencode.json" "$case_root/config.before"
    [[ ! -f "$case_root/ownership.before" ]] || cmp "$base/.elelem-opencode-instructions.json" "$case_root/ownership.before"
    [[ -f "$base/skills/elelem-language-python/SKILL.md" && -f "$base/rules/elelem-language-packs.md" ]]
    ! grep -Fq 'Done.' "$case_root/uninstall.log"
  done
}

test_missing_jq_retains_retry_evidence() {
  local uninstall_command_path command_name
  prepare_fixture opencode user
  run_installer
  cp "$manifest" "$case_root/manifest.before"
  cp "$base/opencode.json" "$case_root/config.before"
  cp "$base/.elelem-opencode-instructions.json" "$case_root/ownership.before"
  uninstall_command_path="$case_root/commands"
  mkdir "$uninstall_command_path"
  for command_name in dirname basename sort tr tput grep; do
    ln -s "$(command -v "$command_name")" "$uninstall_command_path/$command_name"
  done
  if run_uninstaller; then echo 'Uninstall succeeded without jq'; return 1; fi
  grep -Fq 'jq is required for safe instruction ownership updates' "$case_root/uninstall.log"
  cmp "$manifest" "$case_root/manifest.before"
  cmp "$base/opencode.json" "$case_root/config.before"
  cmp "$base/.elelem-opencode-instructions.json" "$case_root/ownership.before"
  [[ -f "$base/rules/elelem-language-packs.md" && -f "$base/skills/elelem-language-python/SKILL.md" ]]
}

test_legacy_uninstall_retains_shared_config() {
  prepare_fixture opencode project
  seed_shared_config
  mkdir -p "$base/rules/python"
  printf 'managed legacy rule\n' > "$base/rules/python/testing.md"
  printf '%s\n' '{"instructions":["personal.md","rules/python/*.md"],"model":"custom"}' > "$base/opencode.json"
  printf '%s\n' "$base" opencode.json rules/python/testing.md > "$manifest"
  run_uninstaller
  [[ -L "$base/opencode.json" ]] || { echo 'Legacy manifest deleted shared config'; return 1; }
  jq -e '.instructions == ["personal.md"] and .model == "custom"' "$base/opencode.json" >/dev/null
  [[ ! -e "$manifest" && ! -e "$base/rules/python/testing.md" ]]
}

test_unmanaged_bootstrap_is_preserved() {
  local selected_harness
  for selected_harness in claude opencode; do
    prepare_fixture "$selected_harness" user
    mkdir -p "$base/rules"
    printf 'personal activation policy\n' > "$base/rules/elelem-language-packs.md"
    if run_installer; then echo 'Installer overwrote unmanaged activation bootstrap'; return 1; fi
    grep -Fxq 'personal activation policy' "$base/rules/elelem-language-packs.md"
    [[ ! -e "$manifest" ]]
  done
}

test_unmanaged_rule_remains_unchanged() {
  local selected_harness
  for selected_harness in claude opencode; do
    prepare_fixture "$selected_harness" user
    mkdir -p "$base/rules"
    printf 'Personal {{READ_FILE_TOOL}} rule\n' > "$base/rules/personal.md"
    cp "$base/rules/personal.md" "$case_root/personal.before"
    run_installer
    cmp "$base/rules/personal.md" "$case_root/personal.before"
  done
}

test_migration_is_idempotent() {
  local selected_harness
  for selected_harness in claude opencode; do
    prepare_fixture "$selected_harness" project
    mkdir -p "$base/rules/python"
    printf 'legacy managed language\n' > "$base/rules/python/testing.md"
    printf '%s\n' "$base" rules/python/testing.md > "$manifest"
    if [[ "$harness" == opencode ]]; then seed_legacy_config; fi
    run_installer
    assert_all_packs
    [[ ! -e "$base/rules/python/testing.md" ]]
    cp "$manifest" "$case_root/manifest.before"
    run_installer
    cmp "$manifest" "$case_root/manifest.before"
    assert_all_packs
    if [[ "$harness" == opencode ]]; then jq -e '.instructions == ["personal.md","rules/elelem-language-packs.md"] and .model == "custom"' "$base/opencode.json" >/dev/null; fi
    run_uninstaller
    [[ ! -e "$manifest" && ! -e "$base/rules/elelem-language-packs.md" ]]
  done
}

seed_legacy_config() {
  printf '%s\n' opencode.json >> "$manifest"
  printf '%s\n' '{"instructions":["personal.md","rules/python/*.md"],"model":"custom"}' > "$base/opencode.json"
}

test_unmanaged_pack_collision_is_preserved() {
  local selected_harness
  for selected_harness in claude opencode; do
    prepare_fixture "$selected_harness" user
    if [[ "$harness" == opencode ]]; then
      seed_shared_config
      cp "$base/opencode.json" "$case_root/config.before"
    fi
    mkdir -p "$base/skills/elelem-language-typescript"
    printf 'personal skill\n' > "$base/skills/elelem-language-typescript/SKILL.md"
    if run_installer; then echo 'Installer accepted an unmanaged language skill collision'; return 1; fi
    grep -Fxq 'personal skill' "$base/skills/elelem-language-typescript/SKILL.md"
    [[ ! -e "$base/skills/elelem-language-go" && ! -e "$manifest" ]]
    grep -Fq 'unmanaged language pack collision' "$case_root/install.log"
    if [[ "$harness" == opencode ]]; then
      cmp "$base/opencode.json" "$case_root/config.before"
      [[ -L "$base/opencode.json" && ! -e "$base/.elelem-opencode-instructions.json" ]]
    fi
  done
}

test_selected_common_rules_remain_eager() {
  local selected_harness
  for selected_harness in claude opencode; do
    prepare_fixture "$selected_harness" user
    run_installer common
    [[ -f "$base/rules/common/workflow.md" && -f "$base/rules/elelem-language-packs.md" ]]
    [[ -f "$base/skills/elelem-language-typescript/SKILL.md" ]]
    ! grep -R -Fq '{{' "$base/rules"
    if [[ "$harness" == opencode ]]; then
      jq -e '.instructions == ["rules/common/*.md","rules/elelem-language-packs.md"]' "$base/opencode.json" >/dev/null
      grep -Fq '(rules/common/workflow.md)' "$base/AGENTS.md"
    fi
  done
}

seed_opencode_preflight_failure() {
  mkdir -p "$base"
  printf '%s\n' '{"instructions":["personal.md"],"model":"custom"}' > "$base/opencode.json"
  case "$1" in
    config) printf '{broken' > "$base/opencode.json" ;;
    ownership) printf '%s\n' '{"instructions":[]}' > "$base/.elelem-opencode-instructions.json" ;;
    bootstrap_collision) printf '%s\n' '{"instructions":["rules/elelem-language-packs.md"]}' > "$base/opencode.json" ;;
    common_collision) printf '%s\n' '{"instructions":["rules/common/*.md"]}' > "$base/opencode.json" ;;
    writable) chmod a-w "$base/opencode.json" ;;
  esac
  cp "$base/opencode.json" "$case_root/config.before"
}

assert_opencode_preflight_allows_retry() {
  local failure="$1" selection="$2" selected_scope="$3"
  prepare_fixture opencode "$selected_scope"
  seed_opencode_preflight_failure "$failure"
  if run_installer "$selection"; then echo "Installer accepted invalid preflight: $failure"; return 1; fi
  cp "$case_root/install.log" "$case_root/rejected-install.log"
  cmp "$base/opencode.json" "$case_root/config.before"
  [[ ! -e "$manifest" && ! -e "$base/rules/elelem-language-packs.md" && ! -e "$base/skills" ]] || { echo "Preflight failure published orphan mandatory files: $failure"; return 1; }
  if [[ "$failure" == ownership ]]; then
    grep -Fxq '{"instructions":[]}' "$base/.elelem-opencode-instructions.json"
    rm "$base/.elelem-opencode-instructions.json"
  else
    [[ ! -e "$base/.elelem-opencode-instructions.json" ]]
  fi
  chmod u+w "$base/opencode.json"
  printf '%s\n' '{}' > "$base/opencode.json"
  run_installer "$selection"
  [[ -f "$manifest" && -f "$base/rules/elelem-language-packs.md" && -f "$base/skills/elelem-language-python/SKILL.md" ]]
  jq -e '.instructions | index("rules/elelem-language-packs.md") != null' "$base/opencode.json" >/dev/null
}

test_malformed_opencode_config_allows_corrected_retry() {
  local selected_scope selection
  for selected_scope in user project; do
    for selection in decline common; do
      assert_opencode_preflight_allows_retry config "$selection" "$selected_scope"
    done
  done
}

test_opencode_ownership_preflight_allows_corrected_retry() {
  assert_opencode_preflight_allows_retry ownership decline user
}

test_opencode_collision_preflight_allows_corrected_retry() {
  assert_opencode_preflight_allows_retry bootstrap_collision decline user
  assert_opencode_preflight_allows_retry common_collision common project
}

test_opencode_writable_preflight_allows_corrected_retry() {
  assert_opencode_preflight_allows_retry writable decline user
}

seed_bundle_conflict() {
  local failure="$1"
  mkdir -p "$base"
  if [[ "$harness" == claude ]]; then
    mkdir -p "$case_root/home/.claude/agents"
    conflict_file="$case_root/home/.claude/agents/competing.md"
    cp "$case_root/invocation/agents/claude/typescript-pro.md" "$conflict_file"
  else
    printf '%s\n' '{"instructions":["personal.md"],"model":"custom"}' > "$base/opencode.json"
    conflict_file="$base/opencode.json"
    if [[ "$failure" == jsonc ]]; then
      conflict_file="$base/opencode.jsonc"
      printf '%s\n' '{}' > "$conflict_file"
    else
      printf '%s\n' '{"instructions":["personal.md"],"model":"custom","agent":{"typescript-pro":{}}}' > "$conflict_file"
    fi
    cp "$base/opencode.json" "$case_root/config.before"
  fi
  cp "$conflict_file" "$case_root/conflict.before"
}

repair_bundle_conflict() {
  if [[ "$harness" == opencode && "$1" != jsonc ]]; then
    printf '%s\n' '{"instructions":["personal.md"],"model":"custom"}' > "$base/opencode.json"
  else
    rm "$conflict_file"
  fi
}

assert_bundle_conflict_allows_retry() {
  local selected_harness="$1" selected_scope="$2" workflow="$3" failure="${4:-identity}"
  prepare_fixture "$selected_harness" "$selected_scope"
  seed_bundle_conflict "$failure"
  if run_installer decline install "$workflow"; then echo 'Installer accepted conflicting agent configuration'; return 1; fi
  cp "$case_root/install.log" "$case_root/rejected-install.log"
  cmp "$conflict_file" "$case_root/conflict.before"
  [[ "$harness" != opencode ]] || cmp "$base/opencode.json" "$case_root/config.before"
  [[ ! -e "$manifest" ]]
  find "$base" -type f > "$case_root/rejected-files.txt"
  repair_bundle_conflict "$failure"
  if ! run_installer decline install "$workflow"; then echo "Corrected $harness bundle retry failed"; return 1; fi
  ! grep -Eq '/rules/elelem-language-packs\.md$|/skills/elelem-language-[^/]+/' "$case_root/rejected-files.txt" || { echo 'Bundle rejection published orphan mandatory files'; return 1; }
  [[ -f "$base/rules/elelem-language-packs.md" && -f "$base/skills/elelem-language-python/SKILL.md" ]]
  [[ -f "$base/agents/typescript-pro.md" && -f "$base/agents.LICENSE" ]]
  grep -Fxq agents/typescript-pro.md "$manifest"
}

test_claude_bundle_conflict_allows_corrected_retry() {
  local selected_scope workflow
  for selected_scope in user project; do
    for workflow in decline install; do
      assert_bundle_conflict_allows_retry claude "$selected_scope" "$workflow"
    done
  done
}

test_opencode_bundle_conflict_allows_corrected_retry() {
  local selected_scope workflow
  for selected_scope in user project; do
    for workflow in decline install; do
      assert_bundle_conflict_allows_retry opencode "$selected_scope" "$workflow"
    done
  done
}

test_opencode_jsonc_refusal_allows_corrected_retry() {
  assert_bundle_conflict_allows_retry opencode project decline jsonc
}

test_names=(test_mandatory_delivery test_uninstall_preserves_shared_config test_uninstall_failure_retains_retry_evidence test_missing_jq_retains_retry_evidence test_legacy_uninstall_retains_shared_config test_unmanaged_bootstrap_is_preserved test_unmanaged_rule_remains_unchanged test_migration_is_idempotent test_unmanaged_pack_collision_is_preserved test_selected_common_rules_remain_eager test_malformed_opencode_config_allows_corrected_retry test_opencode_ownership_preflight_allows_corrected_retry test_opencode_collision_preflight_allows_corrected_retry test_opencode_writable_preflight_allows_corrected_retry test_claude_bundle_conflict_allows_corrected_retry test_opencode_bundle_conflict_allows_corrected_retry test_opencode_jsonc_refusal_allows_corrected_retry)
(( $# == 0 )) || test_names=("$@")
for test_name in "${test_names[@]}"; do
  "$test_name"
  printf '[PASS] %s\n' "$test_name"
done
