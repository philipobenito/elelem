#!/usr/bin/env bash
set -uo pipefail

if [[ -z "${ELELEM_TEST_ROOT:-}" || ! -d "$ELELEM_TEST_ROOT" ]]; then
  printf 'ELELEM_TEST_ROOT must name an existing fixture directory\n' >&2
  exit 2
fi

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

test_codex_installer_offers_the_default_off_agent_bundle_choice() {
  local fixture_root
  fixture_root="$(mktemp -d "$ELELEM_TEST_ROOT/default-off.XXXXXX")"
  mkdir -p "$fixture_root/invocation" "$fixture_root/project" "$fixture_root/home" "$fixture_root/xdg" "$fixture_root/tmp"
  ln -s "$repository_root/install-codex.sh" "$fixture_root/invocation/install-codex.sh"
  ln -s "$repository_root/_install-common.sh" "$fixture_root/invocation/_install-common.sh"
  cp -R "$repository_root/rules" "$fixture_root/invocation/rules"
  cp -R "$repository_root/skills" "$fixture_root/invocation/skills"
  cp -R "$repository_root/agents" "$fixture_root/invocation/agents"

  cat > "$fixture_root/tmp/run-installer.sh" <<'EOF'
#!/usr/bin/env bash
fixture_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$fixture_root/project" || exit 1
"$fixture_root/invocation/install-codex.sh"
status=$?
printf '\nCODEX_INSTALLER_EXIT=%s\n' "$status"
exit "$status"
EOF
  chmod +x "$fixture_root/tmp/run-installer.sh"
  HOME="$fixture_root/home" XDG_CONFIG_HOME="$fixture_root/xdg" TMPDIR="$fixture_root/tmp" TERM=dumb \
    /usr/bin/script -q "$fixture_root/session.log" "$fixture_root/tmp/run-installer.sh" <<EOF >/dev/null





EOF
  if ! sed 's/\r$//' "$fixture_root/session.log" | grep -Fqx 'CODEX_INSTALLER_EXIT=0'; then
    printf '[FAIL] default-off: installer did not exit normally\n'
    return 1
  fi
  if ! grep -Fq 'Elelem agent bundle (11 agents)' "$fixture_root/session.log"; then
    printf '[FAIL] default-off: optional agent bundle choice was not displayed\n'
    return 1
  fi
  if [[ -e "$fixture_root/home/.codex/agents" || -e "$fixture_root/home/.codex/agents.LICENSE" ]]; then
    printf '[FAIL] default-off: bundle files were installed\n'
    return 1
  fi
  printf '[PASS] default-off agent bundle choice\n'
}

create_bundle_fixture() {
  fixture_root="$(mktemp -d "$ELELEM_TEST_ROOT/$1.XXXXXX")"
  mkdir -p "$fixture_root/invocation" "$fixture_root/project" "$fixture_root/home" "$fixture_root/xdg" "$fixture_root/tmp"
  ln -s "$repository_root/install-codex.sh" "$fixture_root/invocation/install-codex.sh"
  ln -s "$repository_root/_install-common.sh" "$fixture_root/invocation/_install-common.sh"
  cp -R "$repository_root/rules" "$fixture_root/invocation/rules"
  cp -R "$repository_root/skills" "$fixture_root/invocation/skills"
  cp -R "$repository_root/agents" "$fixture_root/invocation/agents"
  cat > "$fixture_root/tmp/run-installer.sh" <<'EOF'
#!/usr/bin/env bash
fixture_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$fixture_root/project" || exit 1
"$fixture_root/invocation/install-codex.sh"
status=$?
printf '\nCODEX_INSTALLER_EXIT=%s\n' "$status"
exit "$status"
EOF
  chmod +x "$fixture_root/tmp/run-installer.sh"
}

run_bundle_installer() {
  local input="$1" session="$2"
  printf '%b' "$input" | HOME="$fixture_root/home" XDG_CONFIG_HOME="$fixture_root/xdg" TMPDIR="$fixture_root/tmp" TERM=dumb \
    /usr/bin/script -q "$fixture_root/$session.log" "$fixture_root/tmp/run-installer.sh" >/dev/null
}

test_codex_installs_the_complete_user_agent_bundle() {
  create_bundle_fixture user-install
  run_bundle_installer '\n\n\n\n \n' session
  local source file manifest="$fixture_root/invocation/.elelem-manifest-codex"
  local count=0
  for source in "$fixture_root/invocation/agents/codex/"*.toml; do
    count=$((count + 1))
    file="${source##*/}"
    if ! cmp -s "$source" "$fixture_root/home/.codex/agents/$file"; then
      printf '[FAIL] user-install: missing or incorrect agent %s\n' "$file"
      return 1
    fi
    if ! grep -Fxq ".codex/agents/$file" "$manifest"; then
      printf '[FAIL] user-install: missing manifest entry %s\n' "$file"
      return 1
    fi
  done
  if [[ "$count" -ne 11 ]] || ! grep -Fq 'CODEX_INSTALLER_EXIT=0' "$fixture_root/session.log" ||
    ! cmp -s "$fixture_root/invocation/agents/LICENSE" "$fixture_root/home/.codex/agents.LICENSE" ||
    ! grep -Fxq '.codex/agents.LICENSE' "$manifest" ||
    [[ -e "$fixture_root/home/.codex/agents/LICENSE" || -e "$fixture_root/xdg/codex/agents" ]]; then
    printf '[FAIL] user-install: notice location, content or manifest is incorrect\n'
    return 1
  fi
  printf '[PASS] complete user agent bundle\n'
}

test_codex_installs_the_complete_project_agent_bundle() {
  create_bundle_fixture project-install
  run_bundle_installer '\033[A\n\n\n\n\n \n' session
  local source file manifest="$fixture_root/invocation/.elelem-manifest-codex"
  local count=0
  for source in "$fixture_root/invocation/agents/codex/"*.toml; do
    count=$((count + 1))
    file="${source##*/}"
    if ! cmp -s "$source" "$fixture_root/project/.codex/agents/$file" ||
      ! grep -Fxq ".codex/agents/$file" "$manifest"; then
      printf '[FAIL] project-install: missing agent or manifest entry %s\n' "$file"
      return 1
    fi
  done
  if [[ "$count" -ne 11 ]] || ! grep -Fq 'CODEX_INSTALLER_EXIT=0' "$fixture_root/session.log" ||
    ! cmp -s "$fixture_root/invocation/agents/LICENSE" "$fixture_root/project/.codex/agents.LICENSE" ||
    ! grep -Fxq '.codex/agents.LICENSE' "$manifest" ||
    [[ -e "$fixture_root/home/.codex/agents" || -e "$fixture_root/project/.codex/agents/LICENSE" ]]; then
    printf '[FAIL] project-install: incorrect notice or target\n'
    return 1
  fi
  printf '[PASS] complete project agent bundle\n'
}

test_codex_rejects_a_project_resolving_to_home() {
  create_bundle_fixture project-home
  run_bundle_installer "\033[A\n$fixture_root/home/.\n\n\n\n \n" session
  if ! grep -Fq 'refusing' "$fixture_root/session.log" ||
    ! grep -Fq 'CODEX_INSTALLER_EXIT=1' "$fixture_root/session.log" ||
    [[ -e "$fixture_root/home/.codex/agents" || -e "$fixture_root/home/.codex/agents.LICENSE" || -e "$fixture_root/invocation/.elelem-manifest-codex" ]]; then
    printf '[FAIL] project-home: project resolving to HOME was not rejected before bundle writes\n'
    return 1
  fi
  printf '[PASS] reject project resolving to HOME\n'
}

test_codex_rejects_a_manifest_scope_change_before_writes() {
  create_bundle_fixture scope-change
  printf '%s\n%s\n' "$fixture_root/home" '.codex/agents/existing.toml' > "$fixture_root/invocation/.elelem-manifest-codex"
  cp "$fixture_root/invocation/.elelem-manifest-codex" "$fixture_root/tmp/original-manifest"
  run_bundle_installer '\033[A\n\n\n\n\n \n' session
  if ! grep -Fq 'refusing to change install scope' "$fixture_root/session.log" ||
    ! grep -Fq 'CODEX_INSTALLER_EXIT=1' "$fixture_root/session.log" ||
    ! cmp -s "$fixture_root/tmp/original-manifest" "$fixture_root/invocation/.elelem-manifest-codex" ||
    [[ -e "$fixture_root/project/AGENTS.md" || -e "$fixture_root/project/.codex/agents" || -e "$fixture_root/project/.codex/agents.LICENSE" ]]; then
    printf '[FAIL] scope-change: manifest scope change was not rejected before writes\n'
    return 1
  fi
  printf '[PASS] reject manifest scope change\n'
}

test_codex_preserves_an_unmanaged_notice_when_replacement_is_refused() {
  create_bundle_fixture notice-refused
  mkdir -p "$fixture_root/home/.codex"
  printf 'original notice\n' > "$fixture_root/home/.codex/agents.LICENSE"
  cp "$fixture_root/home/.codex/agents.LICENSE" "$fixture_root/tmp/original-notice"
  run_bundle_installer '\n\n\n\n \nn\n' session
  if ! grep -Fq "Replace existing notice 'agents.LICENSE'" "$fixture_root/session.log" ||
    ! grep -Fq 'CODEX_INSTALLER_EXIT=1' "$fixture_root/session.log" ||
    ! cmp -s "$fixture_root/tmp/original-notice" "$fixture_root/home/.codex/agents.LICENSE" ||
    [[ -e "$fixture_root/invocation/.elelem-manifest-codex" || -e "$fixture_root/home/.codex/agents" ]]; then
    printf '[FAIL] notice-refused: unmanaged notice was replaced or claimed\n'
    return 1
  fi
  printf '[PASS] preserve refused unmanaged notice\n'
}

test_codex_preserves_an_unmanaged_agent_when_replacement_is_refused() {
  create_bundle_fixture replacement-refused
  mkdir -p "$fixture_root/home/.codex/agents"
  cp "$fixture_root/invocation/agents/codex/architect-reviewer.toml" "$fixture_root/home/.codex/agents/architect-reviewer.toml"
  printf '\n# locally modified\n' >> "$fixture_root/home/.codex/agents/architect-reviewer.toml"
  cp "$fixture_root/home/.codex/agents/architect-reviewer.toml" "$fixture_root/tmp/original-agent"
  run_bundle_installer '\n\n\n\n \nn\n' session
  if ! grep -Fq "Replace existing agent 'architect-reviewer.toml'" "$fixture_root/session.log" ||
    ! grep -Fq 'CODEX_INSTALLER_EXIT=0' "$fixture_root/session.log" ||
    ! cmp -s "$fixture_root/tmp/original-agent" "$fixture_root/home/.codex/agents/architect-reviewer.toml" ||
    grep -Fxq '.codex/agents/architect-reviewer.toml' "$fixture_root/invocation/.elelem-manifest-codex"; then
    printf '[FAIL] replacement-refused: unmanaged agent was replaced or claimed\n'
    return 1
  fi
  printf '[PASS] preserve refused unmanaged agent\n'
}

test_codex_replaces_conflicting_bundle_files_after_confirmation() {
  create_bundle_fixture agent-confirmed
  mkdir -p "$fixture_root/home/.codex/agents"
  printf 'name = "architect-reviewer"\n' > "$fixture_root/home/.codex/agents/architect-reviewer.toml"
  printf 'original notice\n' > "$fixture_root/home/.codex/agents.LICENSE"
  run_bundle_installer '\n\n\n\n \ny\ny\n' session
  if ! grep -Fq 'CODEX_INSTALLER_EXIT=0' "$fixture_root/session.log" ||
    ! grep -Fq "Replace existing agent 'architect-reviewer.toml'" "$fixture_root/session.log" ||
    ! grep -Fq "Replace existing notice 'agents.LICENSE'" "$fixture_root/session.log" ||
    ! cmp -s "$fixture_root/invocation/agents/codex/architect-reviewer.toml" "$fixture_root/home/.codex/agents/architect-reviewer.toml" ||
    ! cmp -s "$fixture_root/invocation/agents/LICENSE" "$fixture_root/home/.codex/agents.LICENSE" ||
    ! grep -Fxq '.codex/agents/architect-reviewer.toml' "$fixture_root/invocation/.elelem-manifest-codex" ||
    ! grep -Fxq '.codex/agents.LICENSE' "$fixture_root/invocation/.elelem-manifest-codex"; then
    printf '[FAIL] agent-confirmed: bundle files were not replaced or recorded\n'
    return 1
  fi
  printf '[PASS] confirm conflicting bundle file replacements\n'
}

test_codex_preserves_tracked_bundle_entries_when_deselected() {
  create_bundle_fixture deselected
  mkdir -p "$fixture_root/home/.codex/agents"
  printf 'tracked agent\n' > "$fixture_root/home/.codex/agents/architect-reviewer.toml"
  printf 'tracked notice\n' > "$fixture_root/home/.codex/agents.LICENSE"
  cp "$fixture_root/home/.codex/agents/architect-reviewer.toml" "$fixture_root/tmp/original-agent"
  cp "$fixture_root/home/.codex/agents.LICENSE" "$fixture_root/tmp/original-notice"
  printf '%s\n%s\n%s\n' "$fixture_root/home" '.codex/agents/architect-reviewer.toml' '.codex/agents.LICENSE' > "$fixture_root/invocation/.elelem-manifest-codex"
  run_bundle_installer '\n\n\n\n\n' session
  if ! grep -Fq 'CODEX_INSTALLER_EXIT=0' "$fixture_root/session.log" ||
    ! cmp -s "$fixture_root/tmp/original-agent" "$fixture_root/home/.codex/agents/architect-reviewer.toml" ||
    ! cmp -s "$fixture_root/tmp/original-notice" "$fixture_root/home/.codex/agents.LICENSE" ||
    ! grep -Fxq '.codex/agents/architect-reviewer.toml' "$fixture_root/invocation/.elelem-manifest-codex" ||
    ! grep -Fxq '.codex/agents.LICENSE' "$fixture_root/invocation/.elelem-manifest-codex"; then
    printf '[FAIL] deselected: tracked bundle entries were not preserved\n'
    return 1
  fi
  printf '[PASS] preserve deselected tracked bundle\n'
}

assert_bundle_changes_are_reported_after_failure() {
  local source file report
  if ! grep -Fq 'Permission denied' "$fixture_root/session.log" ||
    ! grep -Fq 'CODEX_INSTALLER_EXIT=1' "$fixture_root/session.log" ||
    ! cmp -s "$fixture_root/invocation/agents/LICENSE" "$fixture_root/home/.codex/agents.LICENSE"; then
    printf '[FAIL] %s: expected permission failure and installed notice\n' "$1"
    return 1
  fi
  for source in "$fixture_root/invocation/agents/codex/"*.toml; do
    file="${source##*/}"
    if ! cmp -s "$source" "$fixture_root/home/.codex/agents/$file"; then
      printf '[FAIL] %s: partial bundle is missing %s\n' "$1" "$file"
      return 1
    fi
  done
  report="$(sed 's/\r$//' "$fixture_root/session.log" | sed -n '/^Changed paths:$/,$p')"
  if [[ -z "$report" ]] || ! printf '%s\n' "$report" | grep -Fxq "  $fixture_root/home/.codex/agents.LICENSE"; then
    printf '[FAIL] %s: changed-path report omitted the notice\n' "$1"
    return 1
  fi
  for source in "$fixture_root/invocation/agents/codex/"*.toml; do
    file="${source##*/}"
    if ! printf '%s\n' "$report" | grep -Fxq "  $fixture_root/home/.codex/agents/$file"; then
      printf '[FAIL] %s: changed-path report omitted %s\n' "$1" "$file"
      return 1
    fi
  done
}

test_codex_reports_bundle_changes_when_manifest_write_fails() {
  create_bundle_fixture manifest-write-failure
  chmod 500 "$fixture_root/invocation"
  if [[ -w "$fixture_root/invocation" ]]; then
    printf '[FAIL] manifest-write-failure: invocation directory remains writable\n'
    return 1
  fi
  run_bundle_installer '\n\n\n\n \n' session
  chmod 700 "$fixture_root/invocation"
  assert_bundle_changes_are_reported_after_failure manifest-write-failure || return 1
  printf '[PASS] report bundle changes after manifest write failure\n'
}

test_codex_reports_bundle_changes_when_stale_pruning_fails() {
  create_bundle_fixture prune-failure
  mkdir -p "$fixture_root/home/stale"
  printf 'stale file\n' > "$fixture_root/home/stale/file"
  printf '%s\n%s\n' "$fixture_root/home" 'stale/file' > "$fixture_root/invocation/.elelem-manifest-codex"
  chmod 500 "$fixture_root/home/stale"
  if [[ -w "$fixture_root/home/stale" ]]; then
    printf '[FAIL] prune-failure: stale directory remains writable\n'
    return 1
  fi
  run_bundle_installer '\n\n\n\n \n' session
  chmod 700 "$fixture_root/home/stale"
  if [[ ! -f "$fixture_root/home/stale/file" ]] || ! grep -Fq 'stale/file' "$fixture_root/session.log"; then
    printf '[FAIL] prune-failure: stale file removal was not attempted\n'
    return 1
  fi
  assert_bundle_changes_are_reported_after_failure prune-failure || return 1
  printf '[PASS] report bundle changes after stale pruning failure\n'
}

test_codex_rejects_a_standalone_identity_under_an_unrelated_filename() {
  create_bundle_fixture standalone-identity
  mkdir -p "$fixture_root/project/.codex/agents" "$fixture_root/home/.codex/agents" "$fixture_root/.codex"
  printf "name = 'architect-reviewer'\n" > "$fixture_root/project/.codex/agents/custom.toml"
  cat > "$fixture_root/project/.codex/agents/aaa.toml" <<'EOF'
name = "unrelated-agent"
description = "name = 'python-pro'"
# name = "python-pro"
developer_instructions = """
name = "python-pro"
[agents.python-pro]
"""
literal_instructions = '''
name = "python-pro"
[agents.python-pro]
'''
EOF
  printf 'name = "architect-reviewer"\n' > "$fixture_root/home/.codex/agents/architect-reviewer.toml"
  printf 'original notice\n' > "$fixture_root/home/.codex/agents.LICENSE"
  printf '[agents.architect-reviewer]\n' > "$fixture_root/.codex/config.toml"
  printf '%s\n%s\n%s\n' "$fixture_root/home" '.codex/agents/architect-reviewer.toml' '.codex/agents.LICENSE' > "$fixture_root/invocation/.elelem-manifest-codex"
  cp "$fixture_root/project/.codex/agents/custom.toml" "$fixture_root/tmp/original-candidate"
  cp "$fixture_root/project/.codex/agents/aaa.toml" "$fixture_root/tmp/original-decoy"
  cp "$fixture_root/home/.codex/agents/architect-reviewer.toml" "$fixture_root/tmp/original-agent"
  cp "$fixture_root/home/.codex/agents.LICENSE" "$fixture_root/tmp/original-notice"
  cp "$fixture_root/invocation/.elelem-manifest-codex" "$fixture_root/tmp/original-manifest"
  run_bundle_installer '\n\n\n\n \nn\n' session
  if ! grep -F 'identity conflict' "$fixture_root/session.log" | grep -F "$fixture_root/project/.codex/agents/custom.toml" | grep -Fq 'architect-reviewer' ||
    grep -Fq 'inspection error' "$fixture_root/session.log" ||
    grep -Fq "$fixture_root/.codex/config.toml" "$fixture_root/session.log" ||
    ! grep -Fq 'CODEX_INSTALLER_EXIT=1' "$fixture_root/session.log"; then
    printf '[FAIL] standalone-identity: missing conflict for the standalone name at custom.toml\n'
    return 1
  fi
  if ! cmp -s "$fixture_root/tmp/original-candidate" "$fixture_root/project/.codex/agents/custom.toml" ||
    ! cmp -s "$fixture_root/tmp/original-decoy" "$fixture_root/project/.codex/agents/aaa.toml" ||
    ! cmp -s "$fixture_root/tmp/original-agent" "$fixture_root/home/.codex/agents/architect-reviewer.toml" ||
    ! cmp -s "$fixture_root/tmp/original-notice" "$fixture_root/home/.codex/agents.LICENSE" ||
    ! cmp -s "$fixture_root/tmp/original-manifest" "$fixture_root/invocation/.elelem-manifest-codex"; then
    printf '[FAIL] standalone-identity: candidate or bundle destination changed\n'
    return 1
  fi
  local source file
  for source in "$fixture_root/invocation/agents/codex/"*.toml; do
    file="${source##*/}"
    if [[ "$file" != architect-reviewer.toml && -e "$fixture_root/home/.codex/agents/$file" ]]; then
      printf '[FAIL] standalone-identity: bundle agent %s was written\n' "$file"
      return 1
    fi
  done
  printf '[PASS] reject standalone identity under an unrelated filename\n'
}

prepare_preflight_destinations() {
  local base="$1"
  mkdir -p "$base/.codex/agents"
  printf 'name = "architect-reviewer"\n' > "$base/.codex/agents/architect-reviewer.toml"
  printf 'original notice\n' > "$base/.codex/agents.LICENSE"
  printf '%s\n%s\n%s\n' "$base" '.codex/agents/architect-reviewer.toml' '.codex/agents.LICENSE' > "$fixture_root/invocation/.elelem-manifest-codex"
  cp "$base/.codex/agents/architect-reviewer.toml" "$fixture_root/tmp/original-agent"
  cp "$base/.codex/agents.LICENSE" "$fixture_root/tmp/original-notice"
  cp "$fixture_root/invocation/.elelem-manifest-codex" "$fixture_root/tmp/original-manifest"
}

assert_preflight_rejection() {
  local base="$1" candidate="$2" diagnostic="$3" source file
  if ! grep -F "$diagnostic" "$fixture_root/session.log" | grep -Fq "$candidate" ||
    ! grep -Fq 'CODEX_INSTALLER_EXIT=1' "$fixture_root/session.log"; then
    printf '[FAIL] %s: missing %s for %s\n' "$case_name" "$diagnostic" "$candidate"
    return 1
  fi
  if [[ "$diagnostic" == 'inspection error' ]]; then
    if grep -Fq 'identity conflict' "$fixture_root/session.log" || grep -Fq 'Use of uninitialized value' "$fixture_root/session.log" || grep -Fq 'Permission denied' "$fixture_root/session.log" || ! grep -Fiq 'review' "$fixture_root/session.log"; then
      printf '[FAIL] %s: inspection error was misclassified or lacks an action\n' "$case_name"
      return 1
    fi
  elif grep -Fq 'inspection error' "$fixture_root/session.log" || ! grep -F "$diagnostic" "$fixture_root/session.log" | grep -F "$candidate" | grep -Fq 'architect-reviewer'; then
    printf '[FAIL] %s: conflict identity was not reported\n' "$case_name"
    return 1
  fi
  if compgen -G "$fixture_root/tmp/tmp.*" > /dev/null; then
    printf '[FAIL] %s: scanner left a temporary enumeration listing\n' "$case_name"
    return 1
  fi
  if ! cmp -s "$fixture_root/tmp/original-agent" "$base/.codex/agents/architect-reviewer.toml" ||
    ! cmp -s "$fixture_root/tmp/original-notice" "$base/.codex/agents.LICENSE" ||
    ! cmp -s "$fixture_root/tmp/original-manifest" "$fixture_root/invocation/.elelem-manifest-codex"; then
    printf '[FAIL] %s: a bundle destination or manifest changed\n' "$case_name"
    return 1
  fi
  for source in "$fixture_root/invocation/agents/codex/"*.toml; do
    file="${source##*/}"
    if [[ "$file" != architect-reviewer.toml && ( -e "$base/.codex/agents/$file" || -L "$base/.codex/agents/$file" ) ]]; then
      printf '[FAIL] %s: bundle agent %s was written\n' "$case_name" "$file"
      return 1
    fi
  done
}

test_codex_rejects_a_direct_config_identity() {
  local case_name="config-$1" base input candidate declaration
  create_bundle_fixture "$case_name"
  base="$fixture_root/home"
  input='\n\n\n\n \nn\n'
  case "$1" in
    user) candidate="$fixture_root/home/.codex/config.toml"; declaration='[agents.architect-reviewer]' ;;
    current) candidate="$fixture_root/project/.codex/config.toml"; declaration="[ 'agents' . \"architect-reviewer\" ]" ;;
    selected)
      mkdir -p "$fixture_root/selected"
      base="$fixture_root/selected"
      input="\033[A\n$base\n\n\n\n \nn\n"
      candidate="$base/.codex/config.toml"
      declaration="[ \"agents\" . 'architect-reviewer' ]"
      ;;
  esac
  prepare_preflight_destinations "$base"
  mkdir -p "$(dirname "$candidate")" "$fixture_root/.codex"
  cat > "$candidate" <<'EOF'
# [agents.python-pro]
message = "[agents.python-pro]"
instructions = """
[agents.python-pro]
"""
EOF
  printf '%s # direct declaration ]\n' "$declaration" >> "$candidate"
  printf '[agents.python-pro]\n' > "$fixture_root/.codex/config.toml"
  cp "$candidate" "$fixture_root/tmp/original-candidate"
  run_bundle_installer "$input" session
  assert_preflight_rejection "$base" "$candidate" 'identity conflict' || return 1
  if ! cmp -s "$fixture_root/tmp/original-candidate" "$candidate" ||
    grep -Fq "$fixture_root/.codex/config.toml" "$fixture_root/session.log"; then
    printf '[FAIL] %s: candidate changed or parent-only config was inspected\n' "$case_name"
    return 1
  fi
  printf '[PASS] reject direct %s config identity\n' "$1"
}

test_codex_rejects_a_noncanonical_identity_in_the_target_directory() {
  local case_name='standalone-target' base candidate
  create_bundle_fixture "$case_name"
  base="$fixture_root/home"
  prepare_preflight_destinations "$base"
  candidate="$base/.codex/agents/custom.toml"
  printf "name = 'architect-reviewer'\n" > "$candidate"
  cp "$candidate" "$fixture_root/tmp/original-candidate"
  run_bundle_installer '\n\n\n\n \nn\n' session
  assert_preflight_rejection "$base" "$candidate" 'identity conflict' || return 1
  cmp -s "$fixture_root/tmp/original-candidate" "$candidate" || return 1
  printf '[PASS] reject noncanonical identity in the target directory\n'
}

test_codex_rejects_a_noncanonical_identity_in_the_selected_project() {
  local case_name='standalone-selected' base candidate
  create_bundle_fixture "$case_name"
  base="$fixture_root/selected"
  mkdir -p "$base"
  prepare_preflight_destinations "$base"
  candidate="$base/.codex/agents/custom.toml"
  printf 'name = "architect-reviewer"\n' > "$candidate"
  cp "$candidate" "$fixture_root/tmp/original-candidate"
  run_bundle_installer "\033[A\n$base\n\n\n\n \nn\n" session
  assert_preflight_rejection "$base" "$candidate" 'identity conflict' || return 1
  cmp -s "$fixture_root/tmp/original-candidate" "$candidate" || return 1
  printf '[PASS] reject noncanonical identity in the selected project\n'
}

test_codex_ignores_indirect_agent_sources() {
  local source file
  create_bundle_fixture indirect-sources
  mkdir -p "$fixture_root/.codex" "$fixture_root/project/.codex/agents/nested"
  printf '[agents.architect-reviewer]\n' > "$fixture_root/.codex/config.toml"
  printf 'name = "architect-reviewer"\n' > "$fixture_root/project/.codex/agents/nested/custom.toml"
  cp "$fixture_root/.codex/config.toml" "$fixture_root/tmp/original-parent"
  cp "$fixture_root/project/.codex/agents/nested/custom.toml" "$fixture_root/tmp/original-nested"
  run_bundle_installer '\033[A\n\n\n\n\n \n' session
  if ! grep -Fq 'CODEX_INSTALLER_EXIT=0' "$fixture_root/session.log" ||
    ! cmp -s "$fixture_root/tmp/original-parent" "$fixture_root/.codex/config.toml" ||
    ! cmp -s "$fixture_root/tmp/original-nested" "$fixture_root/project/.codex/agents/nested/custom.toml"; then
    printf '[FAIL] indirect-sources: indirect source blocked installation or changed\n'
    return 1
  fi
  for source in "$fixture_root/invocation/agents/codex/"*.toml; do
    file="${source##*/}"
    cmp -s "$source" "$fixture_root/project/.codex/agents/$file" || return 1
  done
  printf '[PASS] ignore indirect agent sources\n'
}

test_codex_rejects_unsafe_direct_toml() {
  local case_name="inspection-$1" base candidate original_mode input
  create_bundle_fixture "$case_name"
  base="$fixture_root/home"
  input='\n\n\n\n \nn\n'
  prepare_preflight_destinations "$base"
  mkdir -p "$fixture_root/project/.codex/agents"
  printf 'model = "safe"\n' > "$fixture_root/home/.codex/config.toml"
  cp "$fixture_root/home/.codex/config.toml" "$fixture_root/tmp/original-earlier-config"
  candidate="$fixture_root/project/.codex/agents/competitor.toml"
  case "$1" in
    missing) printf '[metadata]\nname = "architect-reviewer"\n' > "$candidate" ;;
    multiline-name) printf 'name = """\narchitect-reviewer\n"""\n' > "$candidate" ;;
    duplicate) printf 'name = "other"\nname = "other"\n' > "$candidate" ;;
    nonstring) printf 'name = 42\n' > "$candidate" ;;
    escaped) printf 'name = "arch\\u0069tect-reviewer"\n' > "$candidate" ;;
    malformed) printf 'name = "unterminated\n' > "$candidate" ;;
    canonical-malformed)
      candidate="$base/.codex/agents/architect-reviewer.toml"
      printf '%s\n%s\n' "$base" '.codex/agents.LICENSE' > "$fixture_root/invocation/.elelem-manifest-codex"
      cp "$fixture_root/invocation/.elelem-manifest-codex" "$fixture_root/tmp/original-manifest"
      printf 'name = "unterminated\n' > "$candidate"
      cp "$candidate" "$fixture_root/tmp/original-agent"
      ;;
    invalid-utf8) printf 'name = "other"\ndescription = "\377"\n' > "$candidate" ;;
    table-collision) printf 'name = "other"\n[name]\n' > "$candidate" ;;
    dotted) candidate="$fixture_root/project/.codex/config.toml"; printf 'agents.architect-reviewer.model = "x"\n' > "$candidate" ;;
    inline-alternative) candidate="$fixture_root/project/.codex/config.toml"; printf 'agents = { architect-reviewer = {} }\n' > "$candidate" ;;
    section-alternative) candidate="$fixture_root/project/.codex/config.toml"; printf '[agents]\narchitect-reviewer = {}\n' > "$candidate" ;;
    nested-alternative) candidate="$fixture_root/project/.codex/config.toml"; printf '[agents.architect-reviewer.extra]\nmodel = "x"\n' > "$candidate" ;;
    escaped-key) candidate="$fixture_root/project/.codex/config.toml"; printf '[agents."architect\\u002dreviewer"]\n' > "$candidate" ;;
    array-table) candidate="$fixture_root/project/.codex/config.toml"; printf '[[agents.architect-reviewer]]\n' > "$candidate" ;;
    unreadable) printf 'name = "other"\n' > "$candidate"; chmod 000 "$candidate" ;;
    symlink)
      printf 'name = "other"\n' > "$fixture_root/tmp/symlink-target"
      ln -s "$fixture_root/tmp/symlink-target" "$candidate"
      readlink "$candidate" > "$fixture_root/tmp/original-symlink-destination" || return 1
      cp "$fixture_root/tmp/symlink-target" "$fixture_root/tmp/original-symlink-target" || return 1
      ;;
    nonregular) mkdir "$candidate" ;;
    enumeration)
      candidate="$fixture_root/project/.codex/agents"
      printf 'name = "other"\n' > "$candidate/competitor.toml"
      cp "$candidate/competitor.toml" "$fixture_root/tmp/original-candidate"
      original_mode="$(stat -f '%Lp' "$candidate")"
      chmod 0300 "$candidate"
      if /usr/bin/find "$candidate" -maxdepth 1 -name '*.toml' -print > "$fixture_root/find.stdout" 2> "$fixture_root/find.stderr"; then
        chmod "$original_mode" "$candidate"
        printf '[FAIL] %s: real directory enumeration unexpectedly succeeded\n' "$case_name"
        return 1
      fi
      ;;
  esac
  if [[ -f "$candidate" && ! -L "$candidate" && "$1" != unreadable ]]; then
    cp "$candidate" "$fixture_root/tmp/original-candidate"
  elif [[ "$1" == unreadable ]]; then
    chmod 600 "$candidate"
    cp "$candidate" "$fixture_root/tmp/original-candidate"
    chmod 000 "$candidate"
  fi
  run_bundle_installer "$input" session
  [[ "$1" != unreadable ]] || chmod 600 "$candidate"
  [[ "$1" != enumeration ]] || chmod "$original_mode" "$candidate"
  assert_preflight_rejection "$base" "$candidate" 'inspection error' || return 1
  if [[ "$1" == canonical-malformed ]] && { grep -Fq "Replace existing agent 'architect-reviewer.toml'" "$fixture_root/session.log" || grep -Fq "Replace existing notice 'agents.LICENSE'" "$fixture_root/session.log"; }; then
    printf '[FAIL] %s: replacement consent was requested before inspection\n' "$case_name"
    return 1
  fi
  cmp -s "$fixture_root/tmp/original-earlier-config" "$fixture_root/home/.codex/config.toml" || return 1
  case "$1" in
    symlink)
      [[ -L "$candidate" ]] || return 1
      readlink "$candidate" > "$fixture_root/tmp/current-symlink-destination" || return 1
      cmp -s "$fixture_root/tmp/original-symlink-destination" "$fixture_root/tmp/current-symlink-destination" || return 1
      cmp -s "$fixture_root/tmp/original-symlink-target" "$fixture_root/tmp/symlink-target" || return 1
      ;;
    nonregular) [[ -d "$candidate" ]] || return 1 ;;
    enumeration) cmp -s "$fixture_root/tmp/original-candidate" "$candidate/competitor.toml" || return 1 ;;
    *) cmp -s "$fixture_root/tmp/original-candidate" "$candidate" || return 1 ;;
  esac
  printf '[PASS] reject unsafe direct TOML %s\n' "$1"
}

case "${1:-all}" in
  default-off) test_codex_installer_offers_the_default_off_agent_bundle_choice ;;
  user-install) test_codex_installs_the_complete_user_agent_bundle ;;
  project-install) test_codex_installs_the_complete_project_agent_bundle ;;
  project-home) test_codex_rejects_a_project_resolving_to_home ;;
  scope-change) test_codex_rejects_a_manifest_scope_change_before_writes ;;
  notice-refused) test_codex_preserves_an_unmanaged_notice_when_replacement_is_refused ;;
  replacement-refused) test_codex_preserves_an_unmanaged_agent_when_replacement_is_refused ;;
  agent-confirmed) test_codex_replaces_conflicting_bundle_files_after_confirmation ;;
  deselected) test_codex_preserves_tracked_bundle_entries_when_deselected ;;
  manifest-write-failure) test_codex_reports_bundle_changes_when_manifest_write_fails ;;
  prune-failure) test_codex_reports_bundle_changes_when_stale_pruning_fails ;;
  standalone-identity) test_codex_rejects_a_standalone_identity_under_an_unrelated_filename ;;
  config-user|config-current|config-selected) test_codex_rejects_a_direct_config_identity "${1#config-}" ;;
  standalone-target) test_codex_rejects_a_noncanonical_identity_in_the_target_directory ;;
  standalone-selected) test_codex_rejects_a_noncanonical_identity_in_the_selected_project ;;
  indirect-sources) test_codex_ignores_indirect_agent_sources ;;
  inspection-*) test_codex_rejects_unsafe_direct_toml "${1#inspection-}" ;;
  all)
    test_codex_installer_offers_the_default_off_agent_bundle_choice || exit 1
    test_codex_installs_the_complete_user_agent_bundle || exit 1
    test_codex_installs_the_complete_project_agent_bundle || exit 1
    test_codex_rejects_a_project_resolving_to_home || exit 1
    test_codex_rejects_a_manifest_scope_change_before_writes || exit 1
    test_codex_preserves_an_unmanaged_notice_when_replacement_is_refused || exit 1
    test_codex_preserves_an_unmanaged_agent_when_replacement_is_refused || exit 1
    test_codex_replaces_conflicting_bundle_files_after_confirmation || exit 1
    test_codex_preserves_tracked_bundle_entries_when_deselected || exit 1
    test_codex_reports_bundle_changes_when_manifest_write_fails || exit 1
    test_codex_reports_bundle_changes_when_stale_pruning_fails || exit 1
    test_codex_rejects_a_standalone_identity_under_an_unrelated_filename || exit 1
    test_codex_rejects_a_noncanonical_identity_in_the_target_directory || exit 1
    test_codex_rejects_a_noncanonical_identity_in_the_selected_project || exit 1
    test_codex_ignores_indirect_agent_sources || exit 1
    for root in user current selected; do test_codex_rejects_a_direct_config_identity "$root" || exit 1; done
    for form in missing multiline-name duplicate nonstring escaped malformed canonical-malformed invalid-utf8 table-collision dotted inline-alternative section-alternative nested-alternative escaped-key array-table unreadable symlink nonregular enumeration; do test_codex_rejects_unsafe_direct_toml "$form" || exit 1; done
    ;;
esac
