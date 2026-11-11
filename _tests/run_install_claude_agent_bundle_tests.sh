#!/usr/bin/env bash
set -uo pipefail

if [[ -z "${ELELEM_TEST_ROOT:-}" || ! -d "$ELELEM_TEST_ROOT" ]]; then
  printf 'ELELEM_TEST_ROOT must name an existing fixture directory\n' >&2
  exit 2
fi

ELELEM_TEST_ROOT="$(cd "$ELELEM_TEST_ROOT" && pwd -P)"

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

passed=0
failed=0

create_claude_fixture() {
  fixture_root="$(mktemp -d "$ELELEM_TEST_ROOT/claude-agent-bundle.XXXXXX")"
  invocation_dir="$fixture_root/invocation"
  home_directory="$fixture_root/home"
  xdg_directory="$fixture_root/xdg"
  session_log="$fixture_root/session.log"

  mkdir -p "$invocation_dir" "$home_directory" "$xdg_directory" "$fixture_root/project"
  ln -s "$repository_root/install-claude.sh" "$invocation_dir/install-claude.sh"
  ln -s "$repository_root/_install-common.sh" "$invocation_dir/_install-common.sh"
  cp -R "$repository_root/rules" "$invocation_dir/rules"
  cp -R "$repository_root/skills" "$invocation_dir/skills"
  cp -R "$repository_root/agents" "$invocation_dir/agents"

  cat > "$fixture_root/run-installer.sh" <<'EOF'
#!/usr/bin/env bash
fixture_directory="$(cd "$(dirname "$0")" && pwd -P)"
cd "$fixture_directory/project" || exit 1
"$fixture_directory/invocation/install-claude.sh"
installer_status=$?
printf '\nCLAUDE_INSTALLER_EXIT=%s\n' "$installer_status"
exit "$installer_status"
EOF
  chmod +x "$fixture_root/run-installer.sh"
}

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

test_claude_installer_offers_the_default_off_agent_bundle_choice() {
  local name="claude_installer_offers_the_default_off_agent_bundle_choice"

  create_claude_fixture
  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  export HOME XDG_CONFIG_HOME
  printf '\n\n\n\n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Fqx 'CLAUDE_INSTALLER_EXIT=0'; then
    printf '[FAIL] %s: installer did not exit with status 0\n' "$name"
    return 1
  fi

  if ! grep -Fq 'Elelem agent bundle (11 agents)' "$session_log"; then
    printf '[FAIL] %s: optional agent bundle menu label was not displayed\n' "$name"
    return 1
  fi

  if [[ -e "$home_directory/.claude/agents" || -L "$home_directory/.claude/agents" || -e "$home_directory/.claude/agents.LICENSE" || -L "$home_directory/.claude/agents.LICENSE" ]]; then
    printf '[FAIL] %s: confirming the default-off choice installed bundle files\n' "$name"
    return 1
  fi

  return 0
}



test_claude_installer_installs_all_agents_when_selected_in_project_scope() {
  local name="claude_installer_installs_all_agents_when_selected_in_project_scope"
  local project_agents_directory
  local manifest_file
  local source_agent
  local destination_agent
  local agent_count

  create_claude_fixture
  project_agents_directory="$fixture_root/project/.claude/agents"
  manifest_file="$invocation_dir/.elelem-manifest-claude"
  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  export HOME XDG_CONFIG_HOME
  printf '\033[A\n\n\n\n \n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Fqx 'CLAUDE_INSTALLER_EXIT=0'; then
    printf '[FAIL] %s: installer did not exit with status 0\n' "$name"
    return 1
  fi

  if [[ ! -d "$project_agents_directory" ]]; then
    printf '[FAIL] %s: project agent bundle directory is missing\n' "$name"
    return 1
  fi

  agent_count="$(find "$project_agents_directory" -maxdepth 1 -type f -name '*.md' | wc -l | tr -d ' ')"
  if [[ "$agent_count" -ne 11 ]]; then
    printf '[FAIL] %s: project agent bundle contains %s flat markdown definitions, expected 11\n' "$name" "$agent_count"
    return 1
  fi

  if [[ ! -f "$manifest_file" ]]; then
    printf '[FAIL] %s: Claude installer manifest is missing\n' "$name"
    return 1
  fi

  for source_agent in "$invocation_dir"/agents/claude/*.md; do
    destination_agent="$project_agents_directory/${source_agent##*/}"
    if [[ ! -f "$destination_agent" ]]; then
      printf '[FAIL] %s: project agent definition is missing: %s\n' "$name" "${destination_agent##*/}"
      return 1
    fi
    if ! cmp -s "$source_agent" "$destination_agent"; then
      printf '[FAIL] %s: project agent definition differs from source: %s\n' "$name" "${destination_agent##*/}"
      return 1
    fi
    if ! grep -Fqx "agents/${source_agent##*/}" "$manifest_file"; then
      printf '[FAIL] %s: manifest entry is missing: agents/%s\n' "$name" "${source_agent##*/}"
      return 1
    fi
  done

  if [[ ! -f "$fixture_root/project/.claude/agents.LICENSE" ]]; then
    printf '[FAIL] %s: project agent bundle licence is missing\n' "$name"
    return 1
  fi
  if ! cmp -s "$invocation_dir/agents/LICENSE" "$fixture_root/project/.claude/agents.LICENSE"; then
    printf '[FAIL] %s: project agent bundle licence differs from source\n' "$name"
    return 1
  fi

  if ! grep -Fqx 'agents.LICENSE' "$manifest_file"; then
    printf '[FAIL] %s: manifest entry is missing: agents.LICENSE\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_reinstalling_with_bundle_deselected_preserves_installed_agents() {
  local name="claude_installer_reinstalling_with_bundle_deselected_preserves_installed_agents"
  local user_agents_directory
  local manifest_file
  local source_agent
  local destination_agent
  local edited_agent
  local expected_edited_agent

  create_claude_fixture
  user_agents_directory="$home_directory/.claude/agents"
  manifest_file="$invocation_dir/.elelem-manifest-claude"
  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  export HOME XDG_CONFIG_HOME
  printf '\n\n\n \n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Fqx 'CLAUDE_INSTALLER_EXIT=0'; then
    printf '[FAIL] %s: initial installer run did not exit with status 0\n' "$name"
    return 1
  fi

  edited_agent="$user_agents_directory/architect-reviewer.md"
  expected_edited_agent="$fixture_root/expected-architect-reviewer.md"
  printf 'User-edited architect reviewer\n' > "$edited_agent"
  cp "$edited_agent" "$expected_edited_agent"

  printf '\n\n\n\n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Fqx 'CLAUDE_INSTALLER_EXIT=0'; then
    printf '[FAIL] %s: deselected reinstall did not exit with status 0\n' "$name"
    return 1
  fi

  for source_agent in "$invocation_dir"/agents/claude/*.md; do
    destination_agent="$user_agents_directory/${source_agent##*/}"
    if [[ ! -f "$destination_agent" ]]; then
      printf '[FAIL] %s: previously installed agent is missing after deselected reinstall: %s\n' "$name" "${destination_agent##*/}"
      return 1
    fi
    if ! grep -Fqx "agents/${source_agent##*/}" "$manifest_file"; then
      printf '[FAIL] %s: manifest entry is missing after deselected reinstall: agents/%s\n' "$name" "${source_agent##*/}"
      return 1
    fi
  done

  if ! cmp -s "$expected_edited_agent" "$edited_agent"; then
    printf '[FAIL] %s: user-edited agent was changed after deselected reinstall\n' "$name"
    return 1
  fi

  if ! cmp -s "$invocation_dir/agents/LICENSE" "$home_directory/.claude/agents.LICENSE"; then
    printf '[FAIL] %s: previously installed agent licence is missing or differs after deselected reinstall\n' "$name"
    return 1
  fi
  if ! grep -Fqx 'agents.LICENSE' "$manifest_file"; then
    printf '[FAIL] %s: manifest entry is missing after deselected reinstall: agents.LICENSE\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_preserves_an_edited_notice_when_bundle_is_deselected() {
  local name="claude_installer_preserves_an_edited_notice_when_bundle_is_deselected"
  local existing_notice
  local expected_notice
  local manifest_file

  create_claude_fixture
  existing_notice="$home_directory/.claude/agents.LICENSE"
  expected_notice="$fixture_root/expected-agents.LICENSE"
  manifest_file="$invocation_dir/.elelem-manifest-claude"
  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  export HOME XDG_CONFIG_HOME
  printf '\n\n\n \n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Fqx 'CLAUDE_INSTALLER_EXIT=0'; then
    printf '[FAIL] %s: initial installer run did not exit with status 0\n' "$name"
    return 1
  fi

  if [[ ! -f "$existing_notice" ]]; then
    printf '[FAIL] %s: initial installer did not install the notice\n' "$name"
    return 1
  fi
  if ! cmp -s "$invocation_dir/agents/LICENSE" "$existing_notice"; then
    printf '[FAIL] %s: initial notice differs from the bundled licence\n' "$name"
    return 1
  fi
  if ! grep -Fqx 'agents.LICENSE' "$manifest_file"; then
    printf '[FAIL] %s: initial manifest entry is missing: agents.LICENSE\n' "$name"
    return 1
  fi

  printf 'User-edited agents notice that must be preserved.\n' > "$existing_notice"
  cp "$existing_notice" "$expected_notice"
  printf '\n\n\n\n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Fqx 'CLAUDE_INSTALLER_EXIT=0'; then
    printf '[FAIL] %s: deselected reinstall did not exit with status 0\n' "$name"
    return 1
  fi

  if ! cmp -s "$expected_notice" "$existing_notice"; then
    printf '[FAIL] %s: user-edited notice changed after deselected reinstall\n' "$name"
    return 1
  fi
  if ! grep -Fqx 'agents.LICENSE' "$manifest_file"; then
    printf '[FAIL] %s: manifest entry is missing after deselected reinstall: agents.LICENSE\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_rejects_a_manifest_base_change_before_writes() {
  local name="claude_installer_rejects_a_manifest_base_change_before_writes"
  local claude_directory
  local manifest_file
  local expected_manifest_file
  local previous_base

  create_claude_fixture
  claude_directory="$home_directory/.claude"
  manifest_file="$invocation_dir/.elelem-manifest-claude"
  expected_manifest_file="$fixture_root/expected-manifest"
  previous_base="$fixture_root/previous-claude-base"
  printf '%s\n%s\n' "$previous_base" 'rules/retained.md' > "$manifest_file"
  cp "$manifest_file" "$expected_manifest_file"
  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  export HOME XDG_CONFIG_HOME
  printf '\n\n\n\n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Fqx 'CLAUDE_INSTALLER_EXIT=1'; then
    printf '[FAIL] %s: installer did not exit with status 1\n' "$name"
    return 1
  fi

  if ! cmp -s "$expected_manifest_file" "$manifest_file"; then
    printf '[FAIL] %s: existing Claude installer manifest was changed\n' "$name"
    return 1
  fi

  if [[ -e "$claude_directory" || -L "$claude_directory" ]]; then
    printf '[FAIL] %s: install target was created before the scope change was rejected\n' "$name"
    return 1
  fi

  if ! grep -Fq "manifest '$manifest_file' records base '$previous_base', not '$claude_directory'; refusing to change install scope." "$session_log"; then
    printf '[FAIL] %s: actionable manifest scope-change diagnostic was not displayed\n' "$name"
    return 1
  fi

  return 0
}


test_claude_installer_refuses_an_unrecognised_agent_replacement_response() {
  local name="claude_installer_refuses_an_unrecognised_agent_replacement_response"
  local user_agent
  local expected_agent
  local manifest_file

  create_claude_fixture
  user_agent="$home_directory/.claude/agents/architect-reviewer.md"
  expected_agent="$fixture_root/expected-architect-reviewer.md"
  manifest_file="$invocation_dir/.elelem-manifest-claude"
  mkdir -p "$(dirname "$user_agent")"
  cat > "$user_agent" <<'EOF'
---
name: architect-reviewer
description: User-authored canonical reviewer for invalid response test
---

Preserve these user-authored bytes when replacement consent is invalid.
EOF
  cp "$user_agent" "$expected_agent"
  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  export HOME XDG_CONFIG_HOME
  printf '\n\n\n \nyes\n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Fqx 'CLAUDE_INSTALLER_EXIT=0'; then
    printf '[FAIL] %s: installer did not exit with status 0\n' "$name"
    return 1
  fi

  if ! grep -Fq 'Replace existing agent' "$session_log" || ! grep -Fq 'architect-reviewer.md' "$session_log" || ! grep -Fq '[y/n]' "$session_log"; then
    printf '[FAIL] %s: replacement prompt did not name the canonical agent and offer [y/n] consent\n' "$name"
    return 1
  fi

  if ! cmp -s "$expected_agent" "$user_agent"; then
    printf '[FAIL] %s: existing unmanaged canonical agent was not preserved byte-for-byte\n' "$name"
    return 1
  fi

  if [[ -f "$manifest_file" ]] && grep -Fqx 'agents/architect-reviewer.md' "$manifest_file"; then
    printf '[FAIL] %s: unmanaged canonical agent was added to the manifest\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_refuses_an_unrecognised_notice_replacement_response() {
  local name="claude_installer_refuses_an_unrecognised_notice_replacement_response"
  local existing_notice
  local expected_notice
  local user_agents_directory
  local manifest_file

  create_claude_fixture
  existing_notice="$home_directory/.claude/agents.LICENSE"
  expected_notice="$fixture_root/expected-agents.LICENSE"
  user_agents_directory="$home_directory/.claude/agents"
  manifest_file="$invocation_dir/.elelem-manifest-claude"
  mkdir -p "$(dirname "$existing_notice")"
  printf 'Distinct user-authored notice for invalid replacement response.\n' > "$existing_notice"
  cp "$existing_notice" "$expected_notice"
  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  export HOME XDG_CONFIG_HOME
  printf '\n\n\n \nyes\n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Eq '^CLAUDE_INSTALLER_EXIT=[1-9][0-9]*$'; then
    printf '[FAIL] %s: installer did not exit with a positive status\n' "$name"
    return 1
  fi

  if ! grep -Fq 'Replace existing notice' "$session_log" || ! grep -Fq 'agents.LICENSE' "$session_log" || ! grep -Fq '[y/n]' "$session_log"; then
    printf '[FAIL] %s: notice replacement prompt did not name agents.LICENSE and offer [y/n] consent\n' "$name"
    return 1
  fi

  if ! cmp -s "$expected_notice" "$existing_notice"; then
    printf '[FAIL] %s: existing notice was not preserved byte-for-byte\n' "$name"
    return 1
  fi
  if [[ -e "$user_agents_directory" || -L "$user_agents_directory" ]]; then
    printf '[FAIL] %s: agent bundle was installed despite invalid notice consent\n' "$name"
    return 1
  fi
  if [[ -f "$manifest_file" ]] && grep -Fqx 'agents.LICENSE' "$manifest_file"; then
    printf '[FAIL] %s: notice was added to the manifest despite invalid replacement consent\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_refuses_to_replace_a_managed_canonical_agent() {
  local name="claude_installer_refuses_to_replace_a_managed_canonical_agent"
  local user_agent
  local expected_agent
  local manifest_file

  create_claude_fixture
  user_agent="$home_directory/.claude/agents/architect-reviewer.md"
  expected_agent="$fixture_root/expected-architect-reviewer.md"
  manifest_file="$invocation_dir/.elelem-manifest-claude"
  mkdir -p "$(dirname "$user_agent")"
  printf '%s' 'Managed canonical agent bytes to preserve.' > "$user_agent"
  cp "$user_agent" "$expected_agent"
  printf '%s\n%s\n' "$home_directory/.claude" 'agents/architect-reviewer.md' > "$manifest_file"
  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  export HOME XDG_CONFIG_HOME
  printf '\n\n\n \nn\n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Fqx 'CLAUDE_INSTALLER_EXIT=0'; then
    printf '[FAIL] %s: installer did not exit with status 0\n' "$name"
    return 1
  fi

  if ! grep -Fq 'Replace existing agent' "$session_log" || ! grep -Fq 'architect-reviewer.md' "$session_log" || ! grep -Fq '[y/n]' "$session_log"; then
    printf '[FAIL] %s: replacement prompt did not name the canonical agent and offer [y/n] consent\n' "$name"
    return 1
  fi

  if ! cmp -s "$expected_agent" "$user_agent"; then
    printf '[FAIL] %s: existing managed canonical agent was not preserved byte-for-byte\n' "$name"
    return 1
  fi

  if [[ ! -f "$manifest_file" ]] || ! grep -Fqx 'agents/architect-reviewer.md' "$manifest_file"; then
    printf '[FAIL] %s: existing managed canonical agent entry was not preserved in the manifest\n' "$name"
    return 1
  fi

  return 0
}


test_claude_installer_refuses_to_replace_a_managed_notice() {
  local name="claude_installer_refuses_to_replace_a_managed_notice"
  local existing_notice
  local expected_notice
  local canonical_agent
  local manifest_file
  local expected_manifest_file

  create_claude_fixture
  existing_notice="$home_directory/.claude/agents.LICENSE"
  expected_notice="$fixture_root/expected-agents.LICENSE"
  canonical_agent="$home_directory/.claude/agents/architect-reviewer.md"
  manifest_file="$invocation_dir/.elelem-manifest-claude"
  expected_manifest_file="$fixture_root/expected-manifest"
  mkdir -p "$(dirname "$existing_notice")"
  printf 'Managed notice bytes that must remain unchanged.\n' > "$existing_notice"
  cp "$existing_notice" "$expected_notice"
  printf '%s\n%s\n' "$home_directory/.claude" 'agents.LICENSE' > "$manifest_file"
  cp "$manifest_file" "$expected_manifest_file"
  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  export HOME XDG_CONFIG_HOME
  printf '\n\n\n \nn\n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Fqx 'CLAUDE_INSTALLER_EXIT=1'; then
    printf '[FAIL] %s: installer did not exit with status 1\n' "$name"
    return 1
  fi

  if ! grep -Fq 'Replace existing notice' "$session_log" || ! grep -Fq 'agents.LICENSE' "$session_log" || ! grep -Fq '[y/n]' "$session_log"; then
    printf '[FAIL] %s: notice replacement prompt did not name agents.LICENSE and offer [y/n] consent\n' "$name"
    return 1
  fi

  if ! cmp -s "$expected_notice" "$existing_notice"; then
    printf '[FAIL] %s: existing managed notice was not preserved byte-for-byte\n' "$name"
    return 1
  fi

  if [[ ! -f "$manifest_file" ]] || ! cmp -s "$expected_manifest_file" "$manifest_file" || ! grep -Fqx 'agents.LICENSE' "$manifest_file"; then
    printf '[FAIL] %s: existing managed notice manifest was not preserved byte-for-byte\n' "$name"
    return 1
  fi

  if [[ -e "$canonical_agent" || -L "$canonical_agent" ]]; then
    printf '[FAIL] %s: canonical agent was written despite notice replacement refusal\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_allows_refusing_an_exact_existing_notice_without_claiming_it() {
  local name="claude_installer_allows_refusing_an_exact_existing_notice_without_claiming_it"
  local existing_notice
  local user_agents_directory
  local manifest_file
  local temporary_directory
  local source_agent
  local destination_agent
  local agent_count

  create_claude_fixture
  existing_notice="$home_directory/.claude/agents.LICENSE"
  user_agents_directory="$home_directory/.claude/agents"
  manifest_file="$invocation_dir/.elelem-manifest-claude"
  temporary_directory="$fixture_root/tmp"
  mkdir -p "$(dirname "$existing_notice")" "$temporary_directory"
  cp "$invocation_dir/agents/LICENSE" "$existing_notice"

  if [[ -e "$user_agents_directory" || -L "$user_agents_directory" ]]; then
    printf '[FAIL] %s: canonical agent directory exists before installation\n' "$name"
    return 1
  fi

  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  TMPDIR="$temporary_directory"
  export HOME XDG_CONFIG_HOME TMPDIR
  printf '\n\n\n \nn\n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Fqx 'CLAUDE_INSTALLER_EXIT=0'; then
    printf '[FAIL] %s: installer did not exit with status 0\n' "$name"
    return 1
  fi

  if ! grep -Fq 'Replace existing notice' "$session_log" || ! grep -Fq 'agents.LICENSE' "$session_log" || ! grep -Fq '[y/n]' "$session_log"; then
    printf '[FAIL] %s: notice replacement prompt did not name agents.LICENSE and offer [y/n] consent\n' "$name"
    return 1
  fi

  if ! cmp -s "$invocation_dir/agents/LICENSE" "$existing_notice"; then
    printf '[FAIL] %s: existing notice differs from the bundled licence after refusal\n' "$name"
    return 1
  fi

  agent_count="$(find "$user_agents_directory" -maxdepth 1 -type f -name '*.md' | wc -l | tr -d ' ')"
  if [[ "$agent_count" -ne 11 ]]; then
    printf '[FAIL] %s: user agent bundle contains %s flat markdown definitions, expected 11\n' "$name" "$agent_count"
    return 1
  fi

  for source_agent in "$invocation_dir"/agents/claude/*.md; do
    destination_agent="$user_agents_directory/${source_agent##*/}"
    if [[ ! -f "$destination_agent" ]]; then
      printf '[FAIL] %s: user agent definition is missing: %s\n' "$name" "${destination_agent##*/}"
      return 1
    fi
    if ! cmp -s "$source_agent" "$destination_agent"; then
      printf '[FAIL] %s: user agent definition differs from source: %s\n' "$name" "${destination_agent##*/}"
      return 1
    fi
  done

  if [[ ! -f "$manifest_file" ]]; then
    printf '[FAIL] %s: Claude installer manifest is missing\n' "$name"
    return 1
  fi
  for source_agent in "$invocation_dir"/agents/claude/*.md; do
    if ! grep -Fqx "agents/${source_agent##*/}" "$manifest_file"; then
      printf '[FAIL] %s: manifest entry is missing: agents/%s\n' "$name" "${source_agent##*/}"
      return 1
    fi
  done
  if grep -Fqx 'agents.LICENSE' "$manifest_file"; then
    printf '[FAIL] %s: refused existing notice was added to the manifest\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_replaces_a_mismatched_notice_when_user_confirms() {
  local name="claude_installer_replaces_a_mismatched_notice_when_user_confirms"
  local existing_notice
  local expected_notice
  local user_agents_directory
  local manifest_file
  local source_agent
  local destination_agent
  local agent_count

  create_claude_fixture
  existing_notice="$home_directory/.claude/agents.LICENSE"
  expected_notice="$fixture_root/expected-agents.LICENSE"
  user_agents_directory="$home_directory/.claude/agents"
  manifest_file="$invocation_dir/.elelem-manifest-claude"
  mkdir -p "$(dirname "$existing_notice")"
  printf 'Distinct user-authored agents notice.\n' > "$existing_notice"
  cp "$existing_notice" "$expected_notice"
  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  export HOME XDG_CONFIG_HOME
  printf '\n\n\n \ny\n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Fqx 'CLAUDE_INSTALLER_EXIT=0'; then
    printf '[FAIL] %s: installer did not exit with status 0\n' "$name"
    return 1
  fi

  if ! grep -Fq 'Replace existing notice' "$session_log" || ! grep -Fq 'agents.LICENSE' "$session_log" || ! grep -Fq '[y/n]' "$session_log"; then
    printf '[FAIL] %s: notice replacement prompt did not name agents.LICENSE and offer [y/n] consent\n' "$name"
    return 1
  fi

  if cmp -s "$expected_notice" "$existing_notice"; then
    printf '[FAIL] %s: accepted replacement preserved the original notice instead of replacing it\n' "$name"
    return 1
  fi
  if ! cmp -s "$invocation_dir/agents/LICENSE" "$existing_notice"; then
    printf '[FAIL] %s: accepted replacement does not match the bundled notice\n' "$name"
    return 1
  fi

  agent_count="$(find "$user_agents_directory" -maxdepth 1 -type f -name '*.md' | wc -l | tr -d ' ')"
  if [[ "$agent_count" -ne 11 ]]; then
    printf '[FAIL] %s: user agent bundle contains %s flat markdown definitions, expected 11\n' "$name" "$agent_count"
    return 1
  fi

  for source_agent in "$invocation_dir"/agents/claude/*.md; do
    destination_agent="$user_agents_directory/${source_agent##*/}"
    if [[ ! -f "$destination_agent" ]]; then
      printf '[FAIL] %s: user agent definition is missing: %s\n' "$name" "${destination_agent##*/}"
      return 1
    fi
    if ! cmp -s "$source_agent" "$destination_agent"; then
      printf '[FAIL] %s: user agent definition differs from source: %s\n' "$name" "${destination_agent##*/}"
      return 1
    fi
  done

  if [[ ! -f "$manifest_file" ]]; then
    printf '[FAIL] %s: Claude installer manifest is missing\n' "$name"
    return 1
  fi
  for source_agent in "$invocation_dir"/agents/claude/*.md; do
    if ! grep -Fqx "agents/${source_agent##*/}" "$manifest_file"; then
      printf '[FAIL] %s: manifest entry is missing: agents/%s\n' "$name" "${source_agent##*/}"
      return 1
    fi
  done
  if ! grep -Fqx 'agents.LICENSE' "$manifest_file"; then
    printf '[FAIL] %s: manifest entry is missing: agents.LICENSE\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_replaces_a_mismatched_notice_when_user_confirms_with_uppercase_y() {
  local name="claude_installer_replaces_a_mismatched_notice_when_user_confirms_with_uppercase_y"
  local existing_notice
  local expected_notice
  local user_agents_directory
  local manifest_file
  local source_agent
  local destination_agent
  local agent_count

  create_claude_fixture
  existing_notice="$home_directory/.claude/agents.LICENSE"
  expected_notice="$fixture_root/expected-agents.LICENSE"
  user_agents_directory="$home_directory/.claude/agents"
  manifest_file="$invocation_dir/.elelem-manifest-claude"
  mkdir -p "$(dirname "$existing_notice")"
  printf 'Distinct user-authored agents notice for uppercase-Y confirmation.\n' > "$existing_notice"
  cp "$existing_notice" "$expected_notice"
  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  export HOME XDG_CONFIG_HOME
  printf '\n\n\n \nY\n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Fqx 'CLAUDE_INSTALLER_EXIT=0'; then
    printf '[FAIL] %s: installer did not exit with status 0\n' "$name"
    return 1
  fi

  if ! grep -Fq 'Replace existing notice' "$session_log" || ! grep -Fq 'agents.LICENSE' "$session_log" || ! grep -Fq '[y/n]' "$session_log"; then
    printf '[FAIL] %s: notice replacement prompt did not name agents.LICENSE and offer [y/n] consent\n' "$name"
    return 1
  fi

  if cmp -s "$expected_notice" "$existing_notice"; then
    printf '[FAIL] %s: accepted uppercase-Y replacement preserved the original notice instead of replacing it\n' "$name"
    return 1
  fi
  if ! cmp -s "$invocation_dir/agents/LICENSE" "$existing_notice"; then
    printf '[FAIL] %s: accepted uppercase-Y replacement does not match the bundled notice\n' "$name"
    return 1
  fi

  agent_count="$(find "$user_agents_directory" -maxdepth 1 -type f -name '*.md' | wc -l | tr -d ' ')"
  if [[ "$agent_count" -ne 11 ]]; then
    printf '[FAIL] %s: user agent bundle contains %s flat markdown definitions, expected 11\n' "$name" "$agent_count"
    return 1
  fi

  for source_agent in "$invocation_dir"/agents/claude/*.md; do
    destination_agent="$user_agents_directory/${source_agent##*/}"
    if [[ ! -f "$destination_agent" ]]; then
      printf '[FAIL] %s: user agent definition is missing: %s\n' "$name" "${destination_agent##*/}"
      return 1
    fi
    if ! cmp -s "$source_agent" "$destination_agent"; then
      printf '[FAIL] %s: user agent definition differs from source: %s\n' "$name" "${destination_agent##*/}"
      return 1
    fi
  done

  if [[ ! -f "$manifest_file" ]]; then
    printf '[FAIL] %s: Claude installer manifest is missing\n' "$name"
    return 1
  fi
  for source_agent in "$invocation_dir"/agents/claude/*.md; do
    if ! grep -Fqx "agents/${source_agent##*/}" "$manifest_file"; then
      printf '[FAIL] %s: manifest entry is missing: agents/%s\n' "$name" "${source_agent##*/}"
      return 1
    fi
  done
  if ! grep -Fqx 'agents.LICENSE' "$manifest_file"; then
    printf '[FAIL] %s: manifest entry is missing: agents.LICENSE\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_cleans_a_failed_notice_stage_copy() {
  local name="claude_installer_cleans_a_failed_notice_stage_copy"
  local existing_notice
  local expected_notice
  local marker_file
  local stage_destination

  create_claude_fixture
  existing_notice="$home_directory/.claude/agents.LICENSE"
  expected_notice="$fixture_root/expected-agents.LICENSE"
  marker_file="$fixture_root/notice-stage-copy-destination"
  mkdir -p "$(dirname "$existing_notice")" "$fixture_root/bin" "$fixture_root/tmp"
  printf 'Distinct user-authored notice before failed stage copy.\n' > "$existing_notice"
  cp "$existing_notice" "$expected_notice"
  cat > "$fixture_root/bin/cp" <<'EOF'
#!/usr/bin/env bash
if [[ "${2:-}" == *agents.LICENSE.tmp.* ]]; then
  printf '%s\n' "$2" > "$CLAUDE_NOTICE_STAGE_MARKER"
  printf 'partial stage bytes\n' > "$2"
  exit 1
fi
exec /bin/cp "$@"
EOF
  chmod +x "$fixture_root/bin/cp"
  (
    HOME="$home_directory"
    XDG_CONFIG_HOME="$xdg_directory"
    TMPDIR="$fixture_root/tmp"
    PATH="$fixture_root/bin:$PATH"
    CLAUDE_NOTICE_STAGE_MARKER="$marker_file"
    export HOME XDG_CONFIG_HOME TMPDIR PATH CLAUDE_NOTICE_STAGE_MARKER
    printf '\n\n\n \ny\n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null
  )

  if ! sed 's/\r$//' "$session_log" | grep -Fqx 'CLAUDE_INSTALLER_EXIT=1'; then
    printf '[FAIL] %s: installer did not exit with status 1\n' "$name"
    return 1
  fi

  if ! cmp -s "$expected_notice" "$existing_notice"; then
    printf '[FAIL] %s: existing user-authored notice was not preserved byte-for-byte\n' "$name"
    return 1
  fi

  if [[ -e "$home_directory/.claude/agents/architect-reviewer.md" || -L "$home_directory/.claude/agents/architect-reviewer.md" ]]; then
    printf '[FAIL] %s: canonical agent was written despite the failed notice stage copy\n' "$name"
    return 1
  fi

  if [[ ! -f "$marker_file" ]]; then
    printf '[FAIL] %s: fake cp did not record a notice stage destination\n' "$name"
    return 1
  fi
  stage_destination="$(cat "$marker_file")"
  case "$stage_destination" in
    "$home_directory/.claude"/agents.LICENSE.tmp.*) ;;
    *)
      printf '[FAIL] %s: fake cp intercepted an unexpected destination: %s\n' "$name" "$stage_destination"
      return 1
      ;;
  esac

  if [[ -e "$stage_destination" || -L "$stage_destination" ]]; then
    printf '[FAIL] %s: failed notice stage file remains after installer exit\n' "$name"
    return 1
  fi

  if ! grep -Fq -- "failed to stage notice at '$stage_destination' for destination '$existing_notice'." "$session_log"; then
    printf '[FAIL] %s: notice stage-copy diagnostic did not identify the stage path and agents.LICENSE destination\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_cleans_a_failed_notice_stage_comparison() {
  local name="claude_installer_cleans_a_failed_notice_stage_comparison"
  local existing_notice
  local expected_notice
  local marker_file
  local stage_destination

  create_claude_fixture
  existing_notice="$home_directory/.claude/agents.LICENSE"
  expected_notice="$fixture_root/expected-agents.LICENSE"
  marker_file="$fixture_root/notice-stage-comparison-destination"
  mkdir -p "$(dirname "$existing_notice")" "$fixture_root/bin" "$fixture_root/tmp"
  printf 'Distinct user-authored notice before failed stage comparison.\n' > "$existing_notice"
  cp "$existing_notice" "$expected_notice"
  cat > "$fixture_root/bin/cmp" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == -s ]]; then
  source_file="${2:-}"
  stage_file="${3:-}"
else
  source_file="${1:-}"
  stage_file="${2:-}"
fi
if [[ "$source_file" == */agents/LICENSE && "$stage_file" == *agents.LICENSE.tmp.* ]]; then
  printf '%s\n' "$stage_file" > "$CLAUDE_NOTICE_COMPARE_MARKER"
  exit 1
fi
exec /usr/bin/cmp "$@"
EOF
  chmod +x "$fixture_root/bin/cmp"
  (
    HOME="$home_directory"
    XDG_CONFIG_HOME="$xdg_directory"
    TMPDIR="$fixture_root/tmp"
    PATH="$fixture_root/bin:$PATH"
    CLAUDE_NOTICE_COMPARE_MARKER="$marker_file"
    export HOME XDG_CONFIG_HOME TMPDIR PATH CLAUDE_NOTICE_COMPARE_MARKER
    printf '\n\n\n \ny\n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null
  )

  if ! sed 's/\r$//' "$session_log" | grep -Fqx 'CLAUDE_INSTALLER_EXIT=1'; then
    printf '[FAIL] %s: installer did not exit with status 1\n' "$name"
    return 1
  fi

  if ! cmp -s "$expected_notice" "$existing_notice"; then
    printf '[FAIL] %s: existing user-authored notice was not preserved byte-for-byte\n' "$name"
    return 1
  fi

  if [[ -e "$home_directory/.claude/agents/architect-reviewer.md" || -L "$home_directory/.claude/agents/architect-reviewer.md" ]]; then
    printf '[FAIL] %s: canonical agent was written despite the failed notice stage comparison\n' "$name"
    return 1
  fi

  if [[ ! -f "$marker_file" ]]; then
    printf '[FAIL] %s: fake cmp did not record a notice stage destination\n' "$name"
    return 1
  fi
  stage_destination="$(cat "$marker_file")"
  case "$stage_destination" in
    "$home_directory/.claude"/agents.LICENSE.tmp.*) ;;
    *)
      printf '[FAIL] %s: fake cmp intercepted an unexpected destination: %s\n' "$name" "$stage_destination"
      return 1
      ;;
  esac

  if [[ -e "$stage_destination" || -L "$stage_destination" ]]; then
    printf '[FAIL] %s: failed notice stage file remains after installer exit\n' "$name"
    return 1
  fi

  if ! grep -Fq -- "verification comparison failed for 'agents.LICENSE' at staged path '$stage_destination'." "$session_log"; then
    printf '[FAIL] %s: notice stage-comparison diagnostic did not identify agents.LICENSE and the exact stage path\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_cleans_a_failed_notice_stage_rename() {
  local name="claude_installer_cleans_a_failed_notice_stage_rename"
  local existing_notice
  local expected_notice
  local marker_file
  local stage_source
  local stage_destination

  create_claude_fixture
  existing_notice="$home_directory/.claude/agents.LICENSE"
  expected_notice="$fixture_root/expected-agents.LICENSE"
  marker_file="$fixture_root/notice-stage-rename-paths"
  mkdir -p "$(dirname "$existing_notice")" "$fixture_root/bin" "$fixture_root/tmp"
  printf 'Distinct user-authored notice before failed stage rename.\n' > "$existing_notice"
  cp "$existing_notice" "$expected_notice"
  cat > "$fixture_root/bin/mv" <<'EOF'
#!/usr/bin/env bash
if [[ "${2:-}" == *agents.LICENSE.tmp.* && "${3:-}" == "$CLAUDE_NOTICE_DESTINATION" ]]; then
  printf '%s\n%s\n' "$2" "$3" > "$CLAUDE_NOTICE_RENAME_MARKER"
  exit 1
fi
exec /bin/mv "$@"
EOF
  chmod +x "$fixture_root/bin/mv"
  (
    HOME="$home_directory"
    XDG_CONFIG_HOME="$xdg_directory"
    TMPDIR="$fixture_root/tmp"
    PATH="$fixture_root/bin:$PATH"
    CLAUDE_NOTICE_DESTINATION="$existing_notice"
    CLAUDE_NOTICE_RENAME_MARKER="$marker_file"
    export HOME XDG_CONFIG_HOME TMPDIR PATH CLAUDE_NOTICE_DESTINATION CLAUDE_NOTICE_RENAME_MARKER
    printf '\n\n\n \ny\n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null
  )

  if ! sed 's/\r$//' "$session_log" | grep -Fqx 'CLAUDE_INSTALLER_EXIT=1'; then
    printf '[FAIL] %s: installer did not exit with status 1\n' "$name"
    return 1
  fi

  if ! cmp -s "$expected_notice" "$existing_notice"; then
    printf '[FAIL] %s: existing user-authored notice was not preserved byte-for-byte\n' "$name"
    return 1
  fi

  if [[ -e "$home_directory/.claude/agents/architect-reviewer.md" || -L "$home_directory/.claude/agents/architect-reviewer.md" ]]; then
    printf '[FAIL] %s: canonical agent was installed despite the failed notice stage rename\n' "$name"
    return 1
  fi

  if [[ ! -f "$marker_file" ]]; then
    printf '[FAIL] %s: fake mv did not record a notice stage-to-destination rename\n' "$name"
    return 1
  fi
  stage_source="$(sed -n '1p' "$marker_file")"
  stage_destination="$(sed -n '2p' "$marker_file")"
  case "$stage_source" in
    "$home_directory/.claude"/agents.LICENSE.tmp.*) ;;
    *)
      printf '[FAIL] %s: fake mv intercepted an unexpected stage source: %s\n' "$name" "$stage_source"
      return 1
      ;;
  esac
  if [[ "$stage_destination" != "$existing_notice" ]]; then
    printf '[FAIL] %s: fake mv intercepted an unexpected destination: %s\n' "$name" "$stage_destination"
    return 1
  fi

  if [[ -e "$stage_source" || -L "$stage_source" ]]; then
    printf '[FAIL] %s: failed notice stage source remains after installer exit\n' "$name"
    return 1
  fi

  if ! grep -Fq -- "failed to rename/move staged notice '$stage_source' to agents.LICENSE destination '$stage_destination'." "$session_log"; then
    printf '[FAIL] %s: notice stage-rename diagnostic did not identify the exact paths\n' "$name"
    return 1
  fi

  return 0
}


test_claude_installer_blocks_a_project_agent_conflict_before_user_bundle_writes() {
  local name="claude_installer_blocks_a_project_agent_conflict_before_user_bundle_writes"
  local competing_agent
  local expected_agent
  local canonical_agent
  local licence_file

  create_claude_fixture
  competing_agent="$fixture_root/project/.claude/agents/team-reviewer.md"
  expected_agent="$fixture_root/expected-team-reviewer.md"
  canonical_agent="$home_directory/.claude/agents/architect-reviewer.md"
  licence_file="$home_directory/.claude/agents.LICENSE"
  mkdir -p "$(dirname "$competing_agent")"
  cat > "$competing_agent" <<'EOF'
---
name: architect-reviewer
description: Project-authored team reviewer with a competing identity
---

Preserve this project-authored file-backed team reviewer.
EOF
  cp "$competing_agent" "$expected_agent"
  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  export HOME XDG_CONFIG_HOME
  printf '\n\n\n \n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Fqx 'CLAUDE_INSTALLER_EXIT=1'; then
    printf '[FAIL] %s: installer did not exit with status 1\n' "$name"
    return 1
  fi

  if ! cmp -s "$expected_agent" "$competing_agent"; then
    printf '[FAIL] %s: project competitor was changed\n' "$name"
    return 1
  fi

  if [[ -e "$canonical_agent" || -L "$canonical_agent" ]]; then
    printf '[FAIL] %s: canonical user agent was installed despite the project identity conflict\n' "$name"
    return 1
  fi

  if [[ -e "$licence_file" || -L "$licence_file" ]]; then
    printf '[FAIL] %s: user bundle licence was written despite the project identity conflict\n' "$name"
    return 1
  fi

  if ! grep -Fq 'team-reviewer.md' "$session_log" || ! grep -Fq 'architect-reviewer' "$session_log"; then
    printf '[FAIL] %s: conflict diagnostic did not identify the project file and identity\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_blocks_a_conflict_with_a_double_quoted_agent_identity_value() {
  local name="claude_installer_blocks_a_conflict_with_a_double_quoted_agent_identity_value"
  local candidate_agent
  local expected_agent
  local canonical_agent
  local licence_file

  create_claude_fixture
  candidate_agent="$fixture_root/project/.claude/agents/team-reviewer.md"
  expected_agent="$fixture_root/expected-team-reviewer.md"
  canonical_agent="$home_directory/.claude/agents/architect-reviewer.md"
  licence_file="$home_directory/.claude/agents.LICENSE"
  mkdir -p "$(dirname "$candidate_agent")"
  cat > "$candidate_agent" <<'EOF'
---
name: "architect-reviewer"
description: Project-authored reviewer with a double-quoted identity value
---

Preserve this project-authored file-backed team reviewer.
EOF
  cp "$candidate_agent" "$expected_agent"
  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  export HOME XDG_CONFIG_HOME
  printf '\n\n\n \n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Fqx 'CLAUDE_INSTALLER_EXIT=1'; then
    printf '[FAIL] %s: installer did not exit with status 1\n' "$name"
    return 1
  fi

  if ! grep -Fq "competing agent definition at $candidate_agent claims bundled identity architect-reviewer" "$session_log"; then
    printf '[FAIL] %s: conflict diagnostic did not identify the exact candidate and identity\n' "$name"
    return 1
  fi

  if ! cmp -s "$expected_agent" "$candidate_agent"; then
    printf '[FAIL] %s: project competitor was changed\n' "$name"
    return 1
  fi

  if [[ -e "$canonical_agent" || -L "$canonical_agent" ]]; then
    printf '[FAIL] %s: canonical user agent was installed despite the project identity conflict\n' "$name"
    return 1
  fi
  if [[ -e "$licence_file" || -L "$licence_file" ]]; then
    printf '[FAIL] %s: user bundle licence was written despite the project identity conflict\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_blocks_a_conflict_with_a_single_quoted_agent_identity_value() {
  local name="claude_installer_blocks_a_conflict_with_a_single_quoted_agent_identity_value"
  local candidate_agent
  local expected_agent
  local canonical_agent
  local licence_file

  create_claude_fixture
  candidate_agent="$fixture_root/project/.claude/agents/team-reviewer.md"
  expected_agent="$fixture_root/expected-team-reviewer.md"
  canonical_agent="$home_directory/.claude/agents/architect-reviewer.md"
  licence_file="$home_directory/.claude/agents.LICENSE"
  mkdir -p "$(dirname "$candidate_agent")"
  cat > "$candidate_agent" <<'EOF'
---
name: 'architect-reviewer'
description: Project-authored reviewer with a single-quoted identity value
---

Preserve this project-authored file-backed team reviewer.
EOF
  cp "$candidate_agent" "$expected_agent"
  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  export HOME XDG_CONFIG_HOME
  printf '\n\n\n \n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Fqx 'CLAUDE_INSTALLER_EXIT=1'; then
    printf '[FAIL] %s: installer did not exit with status 1\n' "$name"
    return 1
  fi

  if ! grep -Fq "competing agent definition at $candidate_agent claims bundled identity architect-reviewer" "$session_log"; then
    printf '[FAIL] %s: conflict diagnostic did not identify the exact candidate and identity\n' "$name"
    return 1
  fi

  if ! cmp -s "$expected_agent" "$candidate_agent"; then
    printf '[FAIL] %s: project competitor was changed\n' "$name"
    return 1
  fi

  if [[ -e "$canonical_agent" || -L "$canonical_agent" ]]; then
    printf '[FAIL] %s: canonical user agent was installed despite the project identity conflict\n' "$name"
    return 1
  fi
  if [[ -e "$licence_file" || -L "$licence_file" ]]; then
    printf '[FAIL] %s: user bundle licence was written despite the project identity conflict\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_fails_closed_for_a_single_quoted_agent_identity_key() {
  local name="claude_installer_fails_closed_for_a_single_quoted_agent_identity_key"
  local candidate_agent
  local expected_agent
  local canonical_agent
  local licence_file

  create_claude_fixture
  candidate_agent="$fixture_root/project/.claude/agents/team-reviewer.md"
  expected_agent="$fixture_root/expected-team-reviewer.md"
  canonical_agent="$home_directory/.claude/agents/architect-reviewer.md"
  licence_file="$home_directory/.claude/agents.LICENSE"
  mkdir -p "$(dirname "$candidate_agent")"
  cat > "$candidate_agent" <<'EOF'
---
'name': architect-reviewer
description: Project-authored reviewer with a single-quoted identity key
---

Preserve this project-authored file-backed team reviewer.
EOF
  cp "$candidate_agent" "$expected_agent"
  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  export HOME XDG_CONFIG_HOME
  printf '\n\n\n \n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Eq '^CLAUDE_INSTALLER_EXIT=[1-9][0-9]*$'; then
    printf '[FAIL] %s: installer did not exit with a positive status\n' "$name"
    return 1
  fi

  if ! grep -Fq "cannot inspect agent identity in '$candidate_agent'; its name field is unreadable or malformed." "$session_log"; then
    printf '[FAIL] %s: malformed identity diagnostic did not identify the exact candidate path\n' "$name"
    return 1
  fi

  if ! cmp -s "$expected_agent" "$candidate_agent"; then
    printf '[FAIL] %s: candidate bytes changed after identity inspection failed\n' "$name"
    return 1
  fi

  if [[ -e "$canonical_agent" || -L "$canonical_agent" ]]; then
    printf '[FAIL] %s: canonical agent was written despite the malformed identity\n' "$name"
    return 1
  fi
  if [[ -e "$licence_file" || -L "$licence_file" ]]; then
    printf '[FAIL] %s: bundle licence was written despite the malformed identity\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_blocks_a_user_agent_conflict_before_project_bundle_writes() {
  local name="claude_installer_blocks_a_user_agent_conflict_before_project_bundle_writes"
  local competing_agent
  local expected_agent
  local project_agents_directory
  local project_licence_file

  create_claude_fixture
  competing_agent="$home_directory/.claude/agents/team-reviewer.md"
  expected_agent="$fixture_root/expected-team-reviewer.md"
  project_agents_directory="$fixture_root/project/.claude/agents"
  project_licence_file="$fixture_root/project/.claude/agents.LICENSE"
  mkdir -p "$(dirname "$competing_agent")"
  cat > "$competing_agent" <<'EOF'
---
name: architect-reviewer
description: User-authored team reviewer with a competing identity
---

Preserve this user-authored team reviewer during project installation.
EOF
  cp "$competing_agent" "$expected_agent"
  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  export HOME XDG_CONFIG_HOME
  printf '\033[A\n\n\n\n \n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Fqx 'CLAUDE_INSTALLER_EXIT=1'; then
    printf '[FAIL] %s: installer did not exit with status 1\n' "$name"
    return 1
  fi

  if ! cmp -s "$expected_agent" "$competing_agent"; then
    printf '[FAIL] %s: user-root competing file was changed\n' "$name"
    return 1
  fi

  if ! grep -Fq "$competing_agent" "$session_log" || ! grep -Fq 'architect-reviewer' "$session_log"; then
    printf '[FAIL] %s: conflict diagnostic did not identify the user-root path and bundled identity\n' "$name"
    return 1
  fi

  if [[ -e "$project_agents_directory" || -L "$project_agents_directory" ]]; then
    printf '[FAIL] %s: project agent bundle directory was written despite the user identity conflict\n' "$name"
    return 1
  fi

  if [[ -e "$project_licence_file" || -L "$project_licence_file" ]]; then
    printf '[FAIL] %s: project bundle licence was written despite the user identity conflict\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_blocks_a_conflict_in_an_explicit_project_path() {
  local name="claude_installer_blocks_a_conflict_in_an_explicit_project_path"
  local selected_project_path
  local competing_agent
  local expected_agent
  local canonical_agent
  local licence_file

  create_claude_fixture
  selected_project_path="$fixture_root/selected-project"
  competing_agent="$selected_project_path/.claude/agents/team-reviewer.md"
  expected_agent="$fixture_root/expected-team-reviewer.md"
  canonical_agent="$selected_project_path/.claude/agents/architect-reviewer.md"
  licence_file="$selected_project_path/.claude/agents.LICENSE"
  mkdir -p "$(dirname "$competing_agent")"
  cat > "$competing_agent" <<'EOF'
---
name: architect-reviewer # local agent
---
EOF
  cp "$competing_agent" "$expected_agent"
  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  export HOME XDG_CONFIG_HOME
  printf '\033[A\n%s\n\n\n \n' "$selected_project_path" | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Fqx 'CLAUDE_INSTALLER_EXIT=1'; then
    printf '[FAIL] %s: installer did not exit with status 1\n' "$name"
    return 1
  fi

  if ! grep -Fq "competing agent definition at $competing_agent claims bundled identity architect-reviewer" "$session_log"; then
    printf '[FAIL] %s: conflict diagnostic did not identify the exact selected-project path and identity\n' "$name"
    return 1
  fi

  if ! cmp -s "$expected_agent" "$competing_agent"; then
    printf '[FAIL] %s: selected-project competing file was changed\n' "$name"
    return 1
  fi

  if [[ -e "$canonical_agent" || -L "$canonical_agent" ]]; then
    printf '[FAIL] %s: selected-project canonical agent was installed despite the identity conflict\n' "$name"
    return 1
  fi

  if [[ -e "$licence_file" || -L "$licence_file" ]]; then
    printf '[FAIL] %s: selected-project bundle licence was written despite the identity conflict\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_blocks_a_nested_agent_identity_conflict_before_bundle_writes() {
  local name="claude_installer_blocks_a_nested_agent_identity_conflict_before_bundle_writes"
  local competing_agent
  local expected_agent
  local canonical_agent
  local licence_file

  create_claude_fixture
  competing_agent="$home_directory/.claude/agents/review/architect-reviewer.md"
  expected_agent="$fixture_root/expected-architect-reviewer.md"
  canonical_agent="$home_directory/.claude/agents/architect-reviewer.md"
  licence_file="$home_directory/.claude/agents.LICENSE"
  mkdir -p "$(dirname "$competing_agent")"
  cat > "$competing_agent" <<'EOF'
---
name: architect-reviewer
description: Nested user-authored reviewer with a bundled identity
---

Preserve this nested file-backed reviewer.
EOF
  cp "$competing_agent" "$expected_agent"
  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  export HOME XDG_CONFIG_HOME
  printf '\n\n\n \n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Eq '^CLAUDE_INSTALLER_EXIT=[1-9][0-9]*$'; then
    printf '[FAIL] %s: installer did not exit with a positive status\n' "$name"
    return 1
  fi

  if ! grep -Fq "competing agent definition at $competing_agent claims bundled identity architect-reviewer" "$session_log"; then
    printf '[FAIL] %s: conflict diagnostic did not identify the exact nested path and identity\n' "$name"
    return 1
  fi

  if ! cmp -s "$expected_agent" "$competing_agent"; then
    printf '[FAIL] %s: nested competing file was changed\n' "$name"
    return 1
  fi

  if [[ -e "$canonical_agent" || -L "$canonical_agent" ]]; then
    printf '[FAIL] %s: canonical user agent was written despite the nested identity conflict\n' "$name"
    return 1
  fi
  if [[ -e "$licence_file" || -L "$licence_file" ]]; then
    printf '[FAIL] %s: user bundle licence was written despite the nested identity conflict\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_fails_closed_when_a_target_agent_cannot_be_inspected() {
  local name="claude_installer_fails_closed_when_a_target_agent_cannot_be_inspected"
  local unreadable_agent
  local expected_agent
  local canonical_agent
  local licence_file

  create_claude_fixture
  unreadable_agent="$home_directory/.claude/agents/team-reviewer.md"
  expected_agent="$fixture_root/expected-team-reviewer.md"
  canonical_agent="$home_directory/.claude/agents/architect-reviewer.md"
  licence_file="$home_directory/.claude/agents.LICENSE"
  mkdir -p "$(dirname "$unreadable_agent")"
  cat > "$unreadable_agent" <<'EOF'
---
name: team-reviewer
description: User-authored team reviewer
---

Preserve this unreadable team reviewer definition.
EOF
  cp "$unreadable_agent" "$expected_agent"
  chmod 000 "$unreadable_agent"
  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  export HOME XDG_CONFIG_HOME
  printf '\n\n\n \n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null
  chmod 600 "$unreadable_agent"

  if ! sed 's/\r$//' "$session_log" | grep -Eq '^CLAUDE_INSTALLER_EXIT=[1-9][0-9]*$'; then
    printf '[FAIL] %s: installer did not exit with a positive status\n' "$name"
    return 1
  fi

  if [[ -e "$canonical_agent" || -L "$canonical_agent" ]]; then
    printf '[FAIL] %s: canonical agent was written despite the unreadable target agent\n' "$name"
    return 1
  fi

  if [[ -e "$licence_file" || -L "$licence_file" ]]; then
    printf '[FAIL] %s: bundle licence was written despite the unreadable target agent\n' "$name"
    return 1
  fi

  if ! cmp -s "$expected_agent" "$unreadable_agent"; then
    printf '[FAIL] %s: unreadable target agent was changed\n' "$name"
    return 1
  fi

  if ! grep -Fq 'cannot be inspected' "$session_log" || ! grep -Fq 'team-reviewer.md' "$session_log"; then
    printf '[FAIL] %s: inspectability diagnostic did not identify the unreadable target agent\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_fails_closed_when_agent_tree_traversal_errors() {
  local name="claude_installer_fails_closed_when_agent_tree_traversal_errors"
  local user_agents_directory
  local candidate_agent
  local expected_agent
  local canonical_agent
  local licence_file
  local interception_marker

  create_claude_fixture
  user_agents_directory="$home_directory/.claude/agents"
  candidate_agent="$user_agents_directory/review/team-reviewer.md"
  expected_agent="$fixture_root/expected-team-reviewer.md"
  canonical_agent="$user_agents_directory/architect-reviewer.md"
  licence_file="$home_directory/.claude/agents.LICENSE"
  interception_marker="$fixture_root/find-interception"
  mkdir -p "$(dirname "$candidate_agent")" "$fixture_root/bin"
  cat > "$candidate_agent" <<'EOF'
---
name: team-reviewer
description: User-authored nested team reviewer
---

Preserve this nested candidate when agent traversal fails.
EOF
  cp "$candidate_agent" "$expected_agent"
  cat > "$fixture_root/bin/find" <<'EOF'
#!/usr/bin/env bash
for argument in "$@"; do
  if [[ "$argument" == "$CLAUDE_FIND_FAILURE_ROOT" ]]; then
    printf '%s\n' "$argument" > "$CLAUDE_FIND_INTERCEPTION_MARKER"
    exit 1
  fi
done
exec /usr/bin/find "$@"
EOF
  chmod +x "$fixture_root/bin/find"
  (
    HOME="$home_directory"
    XDG_CONFIG_HOME="$xdg_directory"
    PATH="$fixture_root/bin:$PATH"
    CLAUDE_FIND_FAILURE_ROOT="$user_agents_directory"
    CLAUDE_FIND_INTERCEPTION_MARKER="$interception_marker"
    export HOME XDG_CONFIG_HOME PATH CLAUDE_FIND_FAILURE_ROOT CLAUDE_FIND_INTERCEPTION_MARKER
    printf '\n\n\n \n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null
  )

  if ! sed 's/\r$//' "$session_log" | grep -Eq '^CLAUDE_INSTALLER_EXIT=[1-9][0-9]*$'; then
    printf '[FAIL] %s: installer did not exit with a positive status\n' "$name"
    return 1
  fi
  if [[ ! -f "$interception_marker" ]] || [[ "$(cat "$interception_marker")" != "$user_agents_directory" ]]; then
    printf '[FAIL] %s: find shim did not intercept the intended agent scan root\n' "$name"
    return 1
  fi
  if ! grep -Fq "cannot inspect agent scan root '$user_agents_directory'" "$session_log"; then
    printf '[FAIL] %s: fail-closed diagnostic did not identify the uninspectable agent scan root\n' "$name"
    return 1
  fi
  if ! cmp -s "$expected_agent" "$candidate_agent"; then
    printf '[FAIL] %s: candidate bytes changed after traversal failed\n' "$name"
    return 1
  fi
  if [[ -e "$canonical_agent" || -L "$canonical_agent" ]]; then
    printf '[FAIL] %s: canonical agent was written despite the failed traversal\n' "$name"
    return 1
  fi
  if [[ -e "$licence_file" || -L "$licence_file" ]]; then
    printf '[FAIL] %s: bundle licence was written despite the failed traversal\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_fails_closed_when_an_agent_root_cannot_be_enumerated() {
  local name="claude_installer_fails_closed_when_an_agent_root_cannot_be_enumerated"
  local user_agents_directory
  local competing_agent
  local expected_agent
  local canonical_agent
  local licence_file
  local interception_marker

  create_claude_fixture
  user_agents_directory="$home_directory/.claude/agents"
  competing_agent="$user_agents_directory/team-reviewer.md"
  expected_agent="$fixture_root/expected-team-reviewer.md"
  canonical_agent="$user_agents_directory/architect-reviewer.md"
  licence_file="$home_directory/.claude/agents.LICENSE"
  interception_marker="$fixture_root/ls-interception"
  mkdir -p "$user_agents_directory" "$fixture_root/bin"
  cat > "$competing_agent" <<'EOF'
---
name: architect-reviewer
description: User-authored team reviewer with a competing identity
---

Preserve this user-authored team reviewer.
EOF
  cp "$competing_agent" "$expected_agent"
  cat > "$fixture_root/bin/ls" <<'EOF'
#!/usr/bin/env bash
if [[ "$#" -eq 2 && "$1" == "-a" && "$2" == "$CLAUDE_LS_FAILURE_ROOT" ]]; then
  printf '%s\n' "$2" > "$CLAUDE_LS_INTERCEPTION_MARKER"
  exit 1
fi
exec /bin/ls "$@"
EOF
  chmod +x "$fixture_root/bin/ls"
  (
    HOME="$home_directory"
    XDG_CONFIG_HOME="$xdg_directory"
    PATH="$fixture_root/bin:$PATH"
    CLAUDE_LS_FAILURE_ROOT="$user_agents_directory"
    CLAUDE_LS_INTERCEPTION_MARKER="$interception_marker"
    export HOME XDG_CONFIG_HOME PATH CLAUDE_LS_FAILURE_ROOT CLAUDE_LS_INTERCEPTION_MARKER
    printf '\n\n\n \n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null
  )

  if [[ ! -f "$interception_marker" ]] || [[ "$(cat "$interception_marker")" != "$user_agents_directory" ]]; then
    printf '[FAIL] %s: ls shim did not intercept the intended agent root\n' "$name"
    return 1
  fi
  if ! sed 's/\r$//' "$session_log" | grep -Eq '^CLAUDE_INSTALLER_EXIT=[1-9][0-9]*$'; then
    printf '[FAIL] %s: installer did not exit with a positive status\n' "$name"
    return 1
  fi
  if ! grep -Fq "cannot inspect agent scan root '$user_agents_directory'" "$session_log"; then
    printf '[FAIL] %s: fail-closed diagnostic did not identify the uninspectable agent root\n' "$name"
    return 1
  fi
  if [[ -e "$licence_file" || -L "$licence_file" ]]; then
    printf '[FAIL] %s: bundle licence was written despite the uninspectable agent root\n' "$name"
    return 1
  fi
  if [[ -e "$canonical_agent" || -L "$canonical_agent" ]]; then
    printf '[FAIL] %s: canonical agent was written despite the uninspectable agent root\n' "$name"
    return 1
  fi
  if ! cmp -s "$expected_agent" "$competing_agent"; then
    printf '[FAIL] %s: competing agent bytes changed\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_fails_closed_when_agent_identity_inspection_errors() {
  local name="claude_installer_fails_closed_when_agent_identity_inspection_errors"
  local competing_agent
  local canonical_agent
  local licence_file
  local interception_marker

  create_claude_fixture
  competing_agent="$home_directory/.claude/agents/team-reviewer.md"
  canonical_agent="$home_directory/.claude/agents/architect-reviewer.md"
  licence_file="$home_directory/.claude/agents.LICENSE"
  interception_marker="$fixture_root/awk-interception"
  mkdir -p "$(dirname "$competing_agent")" "$fixture_root/bin"
  cat > "$competing_agent" <<'EOF'
---
name: architect-reviewer
description: User-authored team reviewer with a competing identity
---

Preserve this user-authored team reviewer.
EOF
  cat > "$fixture_root/bin/awk" <<'EOF'
#!/usr/bin/env bash
for argument in "$@"; do
  case "$argument" in
    */team-reviewer.md)
      printf '%s\n' "$argument" > "$CLAUDE_AWK_INTERCEPTION_MARKER"
      exit 1
      ;;
  esac
done
exec /usr/bin/awk "$@"
EOF
  chmod +x "$fixture_root/bin/awk"
  (
    HOME="$home_directory"
    XDG_CONFIG_HOME="$xdg_directory"
    PATH="$fixture_root/bin:$PATH"
    CLAUDE_AWK_INTERCEPTION_MARKER="$interception_marker"
    export HOME XDG_CONFIG_HOME PATH CLAUDE_AWK_INTERCEPTION_MARKER
    printf '\n\n\n \n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null
  )

  if [[ ! -f "$interception_marker" ]] || [[ "$(cat "$interception_marker")" != "$competing_agent" ]]; then
    printf '[FAIL] %s: awk shim did not intercept candidate identity inspection\n' "$name"
    return 1
  fi
  if ! sed 's/\r$//' "$session_log" | grep -Eq '^CLAUDE_INSTALLER_EXIT=[1-9][0-9]*$'; then
    printf '[FAIL] %s: installer did not exit with a positive status\n' "$name"
    return 1
  fi
  if ! grep -Fq "$competing_agent" "$session_log" || ! grep -Eiq 'inspect' "$session_log"; then
    printf '[FAIL] %s: inspection failure diagnostic did not identify the candidate path\n' "$name"
    return 1
  fi
  if [[ -e "$licence_file" || -L "$licence_file" ]]; then
    printf '[FAIL] %s: bundle licence was written despite failed identity inspection\n' "$name"
    return 1
  fi
  if [[ -e "$canonical_agent" || -L "$canonical_agent" ]]; then
    printf '[FAIL] %s: canonical agent was written despite failed identity inspection\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_rejects_a_directory_at_a_canonical_agent_path() {
  local name="claude_installer_rejects_a_directory_at_a_canonical_agent_path"
  local canonical_agent
  local sentinel_file
  local expected_sentinel
  local changed_path_report

  create_claude_fixture
  canonical_agent="$home_directory/.claude/agents/architect-reviewer.md"
  sentinel_file="$canonical_agent/sentinel"
  expected_sentinel="$fixture_root/expected-sentinel"
  mkdir -p "$canonical_agent"
  printf 'Preserve the canonical-agent directory sentinel.\n' > "$sentinel_file"
  cp "$sentinel_file" "$expected_sentinel"
  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  export HOME XDG_CONFIG_HOME
  printf '\n\n\n \ny\n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Eq '^CLAUDE_INSTALLER_EXIT=[1-9][0-9]*$'; then
    printf '[FAIL] %s: installer did not exit with a positive status\n' "$name"
    return 1
  fi
  if ! grep -Fq "$canonical_agent" "$session_log"; then
    printf '[FAIL] %s: failure diagnostic did not name the directory destination\n' "$name"
    return 1
  fi
  if ! cmp -s "$expected_sentinel" "$sentinel_file"; then
    printf '[FAIL] %s: canonical-agent directory sentinel changed\n' "$name"
    return 1
  fi
  if [[ -e "$canonical_agent/architect-reviewer.md" || -L "$canonical_agent/architect-reviewer.md" ]]; then
    printf '[FAIL] %s: canonical agent was copied inside the destination directory\n' "$name"
    return 1
  fi
  changed_path_report="$(sed -n '/Changed paths:/,$p' "$session_log")"
  if ! grep -Fq "$home_directory/.claude/agents.LICENSE" <<< "$changed_path_report"; then
    printf '[FAIL] %s: changed-path report omitted the installed notice destination\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_rejects_a_directory_at_the_notice_path() {
  local name="claude_installer_rejects_a_directory_at_the_notice_path"
  local notice_directory
  local sentinel_file
  local expected_sentinel
  local remaining_entry_count

  create_claude_fixture
  notice_directory="$home_directory/.claude/agents.LICENSE"
  sentinel_file="$notice_directory/sentinel"
  expected_sentinel="$fixture_root/expected-sentinel"
  mkdir -p "$notice_directory"
  printf 'Preserve the notice-directory sentinel.\n' > "$sentinel_file"
  cp "$sentinel_file" "$expected_sentinel"
  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  export HOME XDG_CONFIG_HOME
  printf '\n\n\n \ny\n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Eq '^CLAUDE_INSTALLER_EXIT=[1-9][0-9]*$'; then
    printf '[FAIL] %s: installer did not exit with a positive status\n' "$name"
    return 1
  fi
  if ! grep -Fq "$notice_directory" "$session_log"; then
    printf '[FAIL] %s: failure diagnostic did not name the notice directory\n' "$name"
    return 1
  fi
  if ! cmp -s "$expected_sentinel" "$sentinel_file"; then
    printf '[FAIL] %s: notice-directory sentinel changed\n' "$name"
    return 1
  fi
  remaining_entry_count="$(find "$notice_directory" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')"
  if [[ "$remaining_entry_count" -ne 1 ]]; then
    printf '[FAIL] %s: notice directory contains entries beyond its original sentinel\n' "$name"
    return 1
  fi
  if [[ -e "$home_directory/.claude/agents/architect-reviewer.md" || -L "$home_directory/.claude/agents/architect-reviewer.md" ]]; then
    printf '[FAIL] %s: canonical agent was installed despite the notice destination directory\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_reports_prior_changes_when_agent_directory_creation_fails() {
  local name="claude_installer_reports_prior_changes_when_agent_directory_creation_fails"
  local agents_path
  local interception_marker
  local canonical_agent
  local changed_path_report

  create_claude_fixture
  agents_path="$home_directory/.claude/agents"
  interception_marker="$fixture_root/mkdir-interception"
  canonical_agent="$agents_path/architect-reviewer.md"
  mkdir -p "$(dirname "$agents_path")"
  mkdir -p "$fixture_root/bin"
  cat > "$fixture_root/bin/mkdir" <<'EOF'
#!/usr/bin/env bash
if [[ "$#" -eq 2 && "$1" == "-p" && "$2" == "$CLAUDE_MKDIR_FAILURE_TARGET" ]]; then
  printf '%s\n' "$2" > "$CLAUDE_MKDIR_INTERCEPTION_MARKER"
  exit 1
fi
exec /bin/mkdir "$@"
EOF
  chmod +x "$fixture_root/bin/mkdir"
  (
    HOME="$home_directory"
    XDG_CONFIG_HOME="$xdg_directory"
    PATH="$fixture_root/bin:$PATH"
    CLAUDE_MKDIR_FAILURE_TARGET="$agents_path"
    CLAUDE_MKDIR_INTERCEPTION_MARKER="$interception_marker"
    export HOME XDG_CONFIG_HOME PATH CLAUDE_MKDIR_FAILURE_TARGET CLAUDE_MKDIR_INTERCEPTION_MARKER
    printf '\n\n\n \n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null
  )

  if [[ ! -f "$interception_marker" ]] || [[ "$(cat "$interception_marker")" != "$agents_path" ]]; then
    printf '[FAIL] %s: mkdir shim did not intercept the intended agent output path\n' "$name"
    return 1
  fi
  if ! sed 's/\r$//' "$session_log" | grep -Eq '^CLAUDE_INSTALLER_EXIT=[1-9][0-9]*$'; then
    printf '[FAIL] %s: installer did not exit with a positive status\n' "$name"
    return 1
  fi
  if ! grep -Fq "failed to create agent output directory '$agents_path'" "$session_log"; then
    printf '[FAIL] %s: directory creation diagnostic did not name the agent output path\n' "$name"
    return 1
  fi
  changed_path_report="$(sed -n '/Changed paths:/,$p' "$session_log")"
  if ! grep -Fq "$home_directory/.claude/agents.LICENSE" <<< "$changed_path_report"; then
    printf '[FAIL] %s: changed-path report omitted the previously installed notice\n' "$name"
    return 1
  fi
  if [[ -e "$canonical_agent" || -L "$canonical_agent" ]]; then
    printf '[FAIL] %s: canonical agent was installed despite directory creation failure\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_replaces_a_canonical_agent_when_user_confirms() {
  local name="claude_installer_replaces_a_canonical_agent_when_user_confirms"
  local user_agent
  local expected_agent
  local bundled_agent
  local manifest_file

  create_claude_fixture
  user_agent="$home_directory/.claude/agents/architect-reviewer.md"
  expected_agent="$fixture_root/expected-architect-reviewer.md"
  bundled_agent="$invocation_dir/agents/claude/architect-reviewer.md"
  manifest_file="$invocation_dir/.elelem-manifest-claude"
  mkdir -p "$(dirname "$user_agent")"
  cat > "$user_agent" <<'EOF'
---
name: architect-reviewer
description: User-modified canonical reviewer
---

Replace this user-modified canonical agent when consent is given.
EOF
  cp "$user_agent" "$expected_agent"
  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  export HOME XDG_CONFIG_HOME
  printf '\n\n\n \ny\n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Fqx 'CLAUDE_INSTALLER_EXIT=0'; then
    printf '[FAIL] %s: installer did not exit with status 0\n' "$name"
    return 1
  fi

  if ! grep -Fq 'Replace existing agent' "$session_log" || ! grep -Fq 'architect-reviewer.md' "$session_log" || ! grep -Fq '[y/n]' "$session_log"; then
    printf '[FAIL] %s: replacement prompt did not name the canonical agent and offer [y/n] consent\n' "$name"
    return 1
  fi

  if cmp -s "$expected_agent" "$user_agent"; then
    printf '[FAIL] %s: accepted replacement preserved the original canonical agent instead of replacing it\n' "$name"
    return 1
  fi
  if ! cmp -s "$bundled_agent" "$user_agent"; then
    printf '[FAIL] %s: accepted replacement does not match the bundled canonical agent\n' "$name"
    return 1
  fi

  if [[ ! -f "$manifest_file" ]] || ! grep -Fqx 'agents/architect-reviewer.md' "$manifest_file"; then
    printf '[FAIL] %s: accepted canonical agent is missing from the installer manifest\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_replaces_a_canonical_agent_when_user_confirms_with_uppercase_y() {
  local name="claude_installer_replaces_a_canonical_agent_when_user_confirms_with_uppercase_y"
  local user_agent
  local expected_agent
  local bundled_agent
  local manifest_file

  create_claude_fixture
  user_agent="$home_directory/.claude/agents/architect-reviewer.md"
  expected_agent="$fixture_root/expected-architect-reviewer.md"
  bundled_agent="$invocation_dir/agents/claude/architect-reviewer.md"
  manifest_file="$invocation_dir/.elelem-manifest-claude"
  mkdir -p "$(dirname "$user_agent")"
  cat > "$user_agent" <<'EOF'
---
name: architect-reviewer
description: User-modified canonical reviewer
---

Replace this user-modified canonical agent when consent is given.
EOF
  cp "$user_agent" "$expected_agent"
  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  export HOME XDG_CONFIG_HOME
  printf '\n\n\n \nY\n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Fqx 'CLAUDE_INSTALLER_EXIT=0'; then
    printf '[FAIL] %s: installer did not exit with status 0\n' "$name"
    return 1
  fi

  if ! grep -Fq 'Replace existing agent' "$session_log" || ! grep -Fq 'architect-reviewer.md' "$session_log" || ! grep -Fq '[y/n]' "$session_log"; then
    printf '[FAIL] %s: replacement prompt did not name the canonical agent and offer [y/n] consent\n' "$name"
    return 1
  fi

  if cmp -s "$expected_agent" "$user_agent"; then
    printf '[FAIL] %s: accepted uppercase-Y replacement preserved the original canonical agent instead of replacing it\n' "$name"
    return 1
  fi
  if ! cmp -s "$bundled_agent" "$user_agent"; then
    printf '[FAIL] %s: accepted uppercase-Y replacement does not match the bundled canonical agent\n' "$name"
    return 1
  fi

  if [[ ! -f "$manifest_file" ]] || ! grep -Fqx 'agents/architect-reviewer.md' "$manifest_file"; then
    printf '[FAIL] %s: accepted canonical agent is missing from the installer manifest\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_reports_partial_agent_copy_failure_with_prior_changes() {
  local name="claude_installer_reports_partial_agent_copy_failure_with_prior_changes"
  local notice_target
  local earlier_agent_target
  local later_agent_target
  local marker_file
  local expected_partial_file
  local changed_path_report

  create_claude_fixture
  notice_target="$home_directory/.claude/agents.LICENSE"
  earlier_agent_target="$home_directory/.claude/agents/architect-reviewer.md"
  later_agent_target="$home_directory/.claude/agents/csharp-developer.md"
  marker_file="$fixture_root/partial-agent-copy-destination"
  expected_partial_file="$fixture_root/expected-partial-agent-bytes"
  mkdir -p "$(dirname "$notice_target")" "$(dirname "$earlier_agent_target")" "$(dirname "$later_agent_target")" "$fixture_root/bin" "$fixture_root/tmp"
  printf '%s' 'partial bytes at failed agent target' > "$expected_partial_file"
  cat > "$fixture_root/bin/cp" <<'EOF'
#!/usr/bin/env bash
if [[ "${2:-}" == "$CLAUDE_PARTIAL_AGENT_TARGET" ]]; then
  printf '%s\n' "$2" > "$CLAUDE_PARTIAL_AGENT_MARKER"
  printf '%s' 'partial bytes at failed agent target' > "$2"
  exit 1
fi
exec /bin/cp "$@"
EOF
  chmod +x "$fixture_root/bin/cp"
  (
    HOME="$home_directory"
    XDG_CONFIG_HOME="$xdg_directory"
    TMPDIR="$fixture_root/tmp"
    PATH="$fixture_root/bin:$PATH"
    CLAUDE_PARTIAL_AGENT_TARGET="$later_agent_target"
    CLAUDE_PARTIAL_AGENT_MARKER="$marker_file"
    export HOME XDG_CONFIG_HOME TMPDIR PATH CLAUDE_PARTIAL_AGENT_TARGET CLAUDE_PARTIAL_AGENT_MARKER
    printf '\n\n\n \n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null
  )

  if ! sed 's/\r$//' "$session_log" | grep -Fqx 'CLAUDE_INSTALLER_EXIT=1'; then
    printf '[FAIL] %s: installer did not exit with status 1\n' "$name"
    return 1
  fi

  if [[ ! -f "$marker_file" ]] || [[ "$(cat "$marker_file")" != "$later_agent_target" ]]; then
    printf '[FAIL] %s: fake cp did not record the csharp-developer.md target\n' "$name"
    return 1
  fi

  if ! cmp -s "$expected_partial_file" "$later_agent_target"; then
    printf '[FAIL] %s: csharp-developer.md does not contain the expected partial bytes\n' "$name"
    return 1
  fi

  if ! cmp -s "$invocation_dir/agents/LICENSE" "$notice_target"; then
    printf '[FAIL] %s: installed notice does not match the bundled licence\n' "$name"
    return 1
  fi

  if [[ ! -f "$earlier_agent_target" ]] || ! cmp -s "$invocation_dir/agents/claude/architect-reviewer.md" "$earlier_agent_target"; then
    printf '[FAIL] %s: earlier architect-reviewer.md was not copied byte-for-byte\n' "$name"
    return 1
  fi

  changed_path_report="$(sed -n '/Changed paths:/,$p' "$session_log")"
  if ! sed 's/\r$//' "$session_log" | grep -Eiq 'csharp-developer\.md.*(partial|incomplete)|(partial|incomplete).*csharp-developer\.md' || [[ -z "$changed_path_report" ]] || ! grep -Fq "$notice_target" <<< "$changed_path_report" || ! grep -Fq "$earlier_agent_target" <<< "$changed_path_report"; then
    printf '[FAIL] %s: partial-copy diagnostics or changed-path report omitted the partial target, notice, or earlier agent path\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_reports_manifest_write_failure_with_all_bundle_changes() {
  local name="claude_installer_reports_manifest_write_failure_with_all_bundle_changes"
  local notice_target
  local user_agents_directory
  local manifest_file
  local marker_file
  local sort_destination
  local source_agent
  local destination_agent
  local agent_count=0
  local changed_path_report

  create_claude_fixture
  notice_target="$home_directory/.claude/agents.LICENSE"
  user_agents_directory="$home_directory/.claude/agents"
  manifest_file="$invocation_dir/.elelem-manifest-claude"
  marker_file="$fixture_root/manifest-sort-destination"
  mkdir -p "$fixture_root/bin" "$fixture_root/tmp"
  cat > "$fixture_root/bin/sort" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == *.elelem-manifest-claude.entries.* ]]; then
  printf '%s\n' "$1" > "$CLAUDE_MANIFEST_SORT_MARKER"
  exit 1
fi
exec /usr/bin/sort "$@"
EOF
  chmod +x "$fixture_root/bin/sort"
  (
    HOME="$home_directory"
    XDG_CONFIG_HOME="$xdg_directory"
    TMPDIR="$fixture_root/tmp"
    PATH="$fixture_root/bin:$PATH"
    CLAUDE_MANIFEST_SORT_MARKER="$marker_file"
    export HOME XDG_CONFIG_HOME TMPDIR PATH CLAUDE_MANIFEST_SORT_MARKER
    printf '\n\n\n \n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null
  )

  if ! sed 's/\r$//' "$session_log" | grep -Fqx 'CLAUDE_INSTALLER_EXIT=1'; then
    printf '[FAIL] %s: installer did not exit with status 1\n' "$name"
    return 1
  fi

  if [[ ! -f "$marker_file" ]]; then
    printf '[FAIL] %s: fake sort did not record a manifest entries destination\n' "$name"
    return 1
  fi
  sort_destination="$(cat "$marker_file")"
  case "$sort_destination" in
    "$manifest_file".entries.*) ;;
    *)
      printf '[FAIL] %s: fake sort intercepted an unexpected destination: %s\n' "$name" "$sort_destination"
      return 1
      ;;
  esac

  if [[ -e "$manifest_file" || -L "$manifest_file" ]]; then
    printf '[FAIL] %s: final Claude installer manifest exists after the failed write\n' "$name"
    return 1
  fi

  if ! cmp -s "$invocation_dir/agents/LICENSE" "$notice_target"; then
    printf '[FAIL] %s: installed notice does not match the bundled licence\n' "$name"
    return 1
  fi

  for source_agent in "$invocation_dir"/agents/claude/*.md; do
    destination_agent="$user_agents_directory/${source_agent##*/}"
    if [[ ! -f "$destination_agent" ]]; then
      printf '[FAIL] %s: installed agent is missing: %s\n' "$name" "${destination_agent##*/}"
      return 1
    fi
    if ! cmp -s "$source_agent" "$destination_agent"; then
      printf '[FAIL] %s: installed agent differs from source: %s\n' "$name" "${destination_agent##*/}"
      return 1
    fi
    agent_count=$((agent_count + 1))
  done
  if [[ "$agent_count" -ne 11 ]]; then
    printf '[FAIL] %s: user agent bundle contains %s flat markdown definitions, expected 11\n' "$name" "$agent_count"
    return 1
  fi

  changed_path_report="$(sed -n '/Changed paths:/,$p' "$session_log")"
  if ! grep -Fq -- "$notice_target" <<< "$changed_path_report"; then
    printf '[FAIL] %s: changed-path report omitted destination: %s\n' "$name" "$notice_target"
    return 1
  fi
  for source_agent in "$invocation_dir"/agents/claude/*.md; do
    destination_agent="$user_agents_directory/${source_agent##*/}"
    if ! grep -Fq -- "$destination_agent" <<< "$changed_path_report"; then
      printf '[FAIL] %s: changed-path report omitted destination: %s\n' "$name" "$destination_agent"
      return 1
    fi
  done

  return 0
}

test_claude_installer_reports_stale_prune_failure_with_all_bundle_changes() {
  local name="claude_installer_reports_stale_prune_failure_with_all_bundle_changes"
  local invocation_dir
  local home_directory
  local xdg_directory
  local session_log
  local second_session_log
  local fixture_root
  local manifest_file
  local stale_rule
  local expected_stale_rule
  local marker_file
  local expected_manifest
  local first_input
  local second_input
  local agent_count=0
  local source_agent
  local destination_agent
  local changed_path_report
  local agent_replacement_prompt_count

  fixture_root="$(mktemp -d "$ELELEM_TEST_ROOT/claude-stale-prune.XXXXXX")"
  invocation_dir="$fixture_root/invocation"
  home_directory="$fixture_root/home"
  xdg_directory="$fixture_root/xdg"
  session_log="$fixture_root/session.log"
  second_session_log="$fixture_root/second-session.log"
  manifest_file="$invocation_dir/.elelem-manifest-claude"
  stale_rule="$home_directory/.claude/rules/common/stale.md"
  expected_stale_rule="$fixture_root/expected-stale-rule"
  marker_file="$fixture_root/stale-remove-target"
  expected_manifest="$fixture_root/expected-manifest"
  mkdir -p "$invocation_dir/rules/common" "$invocation_dir/agents/claude" "$home_directory" "$xdg_directory" "$fixture_root/tmp" "$fixture_root/project" "$fixture_root/bin"
  ln -s "$repository_root/install-claude.sh" "$invocation_dir/install-claude.sh"
  ln -s "$repository_root/_install-common.sh" "$invocation_dir/_install-common.sh"
  printf 'Baseline common rule.\n' > "$invocation_dir/rules/common/baseline.md"
  cp -R "$repository_root/agents/claude/." "$invocation_dir/agents/claude/"
  cp "$repository_root/agents/LICENSE" "$invocation_dir/agents/LICENSE"
  cat > "$fixture_root/run-installer.sh" <<'EOF'
#!/usr/bin/env bash
fixture_directory="$(cd "$(dirname "$0")" && pwd -P)"
cd "$fixture_directory/project" || exit 1
"$fixture_directory/invocation/install-claude.sh"
installer_status=$?
printf '\nCLAUDE_INSTALLER_EXIT=%s\n' "$installer_status"
exit "$installer_status"
EOF
  chmod +x "$fixture_root/run-installer.sh"

  first_input=$'\n\n \n'
  (
    HOME="$home_directory"
    XDG_CONFIG_HOME="$xdg_directory"
    TMPDIR="$fixture_root/tmp"
    export HOME XDG_CONFIG_HOME TMPDIR
    printf '%s' "$first_input" | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null
  )

  if ! sed 's/\r$//' "$session_log" | grep -Fqx 'CLAUDE_INSTALLER_EXIT=0'; then
    printf '[FAIL] %s: initial installer run did not exit with status 0\n' "$name"
    return 1
  fi

  if [[ ! -f "$manifest_file" ]] || [[ ! -f "$home_directory/.claude/agents.LICENSE" ]]; then
    printf '[FAIL] %s: initial install did not create the manifest and notice\n' "$name"
    return 1
  fi
  if ! cmp -s "$invocation_dir/agents/LICENSE" "$home_directory/.claude/agents.LICENSE"; then
    printf '[FAIL] %s: initial notice differs from the invocation source\n' "$name"
    return 1
  fi
  for source_agent in "$invocation_dir"/agents/claude/*.md; do
    destination_agent="$home_directory/.claude/agents/${source_agent##*/}"
    if [[ ! -f "$destination_agent" ]] || ! cmp -s "$source_agent" "$destination_agent"; then
      printf '[FAIL] %s: initial bundle output is missing or differs from its source: %s\n' "$name" "${destination_agent##*/}"
      return 1
    fi
    if ! grep -Fqx "agents/${source_agent##*/}" "$manifest_file"; then
      printf '[FAIL] %s: initial manifest entry is missing: agents/%s\n' "$name" "${source_agent##*/}"
      return 1
    fi
    agent_count=$((agent_count + 1))
  done
  if [[ "$agent_count" -ne 11 ]]; then
    printf '[FAIL] %s: initial bundle contains %s agent definitions, expected 11\n' "$name" "$agent_count"
    return 1
  fi
  if ! grep -Fqx 'agents.LICENSE' "$manifest_file"; then
    printf '[FAIL] %s: initial manifest entry is missing: agents.LICENSE\n' "$name"
    return 1
  fi

  printf 'stale rule.\n' > "$stale_rule"
  cp "$stale_rule" "$expected_stale_rule"
  printf '%s\n' 'rules/common/stale.md' >> "$manifest_file"
  cp "$manifest_file" "$expected_manifest"
  cat > "$fixture_root/bin/rm" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "$CLAUDE_STALE_RULE_PATH" ]]; then
  printf '%s\n' "$1" > "$CLAUDE_STALE_REMOVE_MARKER"
  exit 1
fi
exec /bin/rm "$@"
EOF
  chmod +x "$fixture_root/bin/rm"

  second_input=$'\n\n \ny\n'
  for source_agent in "$invocation_dir"/agents/claude/*.md; do
    second_input="${second_input}y"$'\n'
  done
  (
    HOME="$home_directory"
    XDG_CONFIG_HOME="$xdg_directory"
    TMPDIR="$fixture_root/tmp"
    PATH="$fixture_root/bin:$PATH"
    CLAUDE_STALE_RULE_PATH="$stale_rule"
    CLAUDE_STALE_REMOVE_MARKER="$marker_file"
    export HOME XDG_CONFIG_HOME TMPDIR PATH CLAUDE_STALE_RULE_PATH CLAUDE_STALE_REMOVE_MARKER
    printf '%s' "$second_input" | /usr/bin/script -q "$second_session_log" "$fixture_root/run-installer.sh" >/dev/null
  )

  if ! sed 's/\r$//' "$second_session_log" | grep -Fqx 'CLAUDE_INSTALLER_EXIT=1'; then
    printf '[FAIL] %s: second installer run did not exit with status 1\n' "$name"
    return 1
  fi

  if ! grep -Fq 'Replace existing notice' "$second_session_log"; then
    printf '[FAIL] %s: notice replacement prompt was not displayed on the second run\n' "$name"
    return 1
  fi
  agent_replacement_prompt_count="$(grep -oF 'Replace existing agent' "$second_session_log" | wc -l | tr -d ' ')"
  if [[ "$agent_replacement_prompt_count" -ne 11 ]]; then
    printf '[FAIL] %s: second run displayed %s agent replacement prompts, expected 11\n' "$name" "$agent_replacement_prompt_count"
    return 1
  fi

  if [[ ! -f "$marker_file" ]] || [[ "$(cat "$marker_file")" != "$stale_rule" ]]; then
    printf '[FAIL] %s: fake rm did not record exactly the stale-rule path\n' "$name"
    return 1
  fi
  if [[ ! -f "$stale_rule" ]]; then
    printf '[FAIL] %s: stale rule was removed despite the failed rm\n' "$name"
    return 1
  fi
  if ! cmp -s "$expected_stale_rule" "$stale_rule"; then
    printf '[FAIL] %s: stale rule bytes changed despite the failed rm\n' "$name"
    return 1
  fi
  if ! cmp -s "$expected_manifest" "$manifest_file"; then
    printf '[FAIL] %s: manifest changed after stale-rule removal failed\n' "$name"
    return 1
  fi

  if ! cmp -s "$invocation_dir/agents/LICENSE" "$home_directory/.claude/agents.LICENSE"; then
    printf '[FAIL] %s: reinstalled notice differs from its invocation source\n' "$name"
    return 1
  fi
  agent_count=0
  for source_agent in "$invocation_dir"/agents/claude/*.md; do
    destination_agent="$home_directory/.claude/agents/${source_agent##*/}"
    if [[ ! -f "$destination_agent" ]] || ! cmp -s "$source_agent" "$destination_agent"; then
      printf '[FAIL] %s: reinstalled agent is missing or differs from its source: %s\n' "$name" "${destination_agent##*/}"
      return 1
    fi
    agent_count=$((agent_count + 1))
  done
  if [[ "$agent_count" -ne 11 ]]; then
    printf '[FAIL] %s: consented reinstall verified %s agent definitions, expected 11 agent definitions\n' "$name" "$agent_count"
    return 1
  fi

  changed_path_report="$(sed -n '/Changed paths:/,$p' "$second_session_log")"
  if [[ -z "$changed_path_report" ]] || ! grep -Fq -- "$home_directory/.claude/agents.LICENSE" <<< "$changed_path_report"; then
    printf '[FAIL] %s: changed-path report omitted destination: %s\n' "$name" "$home_directory/.claude/agents.LICENSE"
    return 1
  fi
  for source_agent in "$invocation_dir"/agents/claude/*.md; do
    destination_agent="$home_directory/.claude/agents/${source_agent##*/}"
    if ! grep -Fq -- "$destination_agent" <<< "$changed_path_report"; then
      printf '[FAIL] %s: changed-path report omitted destination: %s\n' "$name" "$destination_agent"
      return 1
    fi
  done

  return 0
}

test_claude_installer_fails_closed_for_a_block_scalar_agent_identity() {
  local name="claude_installer_fails_closed_for_a_block_scalar_agent_identity"
  local candidate_agent
  local expected_agent
  local canonical_agent
  local licence_file

  create_claude_fixture
  candidate_agent="$home_directory/.claude/agents/team-reviewer.md"
  expected_agent="$fixture_root/expected-team-reviewer.md"
  canonical_agent="$home_directory/.claude/agents/architect-reviewer.md"
  licence_file="$home_directory/.claude/agents.LICENSE"
  mkdir -p "$(dirname "$candidate_agent")"
  cat > "$candidate_agent" <<'EOF'
---
name: >-
  architect-reviewer
---
EOF
  cp "$candidate_agent" "$expected_agent"
  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  export HOME XDG_CONFIG_HOME
  printf '\n\n\n \n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Eq '^CLAUDE_INSTALLER_EXIT=[1-9][0-9]*$'; then
    printf '[FAIL] %s: installer did not exit with a positive status\n' "$name"
    return 1
  fi

  if ! grep -Fq "cannot inspect agent identity in '$candidate_agent'; its name field is unreadable or malformed." "$session_log"; then
    printf '[FAIL] %s: malformed identity diagnostic did not identify the exact candidate path\n' "$name"
    return 1
  fi

  if ! cmp -s "$expected_agent" "$candidate_agent"; then
    printf '[FAIL] %s: candidate bytes changed after identity inspection failed\n' "$name"
    return 1
  fi

  if [[ -e "$canonical_agent" || -L "$canonical_agent" ]]; then
    printf '[FAIL] %s: canonical agent was written despite the malformed identity\n' "$name"
    return 1
  fi
  if [[ -e "$licence_file" || -L "$licence_file" ]]; then
    printf '[FAIL] %s: bundle licence was written despite the malformed identity\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_fails_closed_for_an_anchored_agent_identity_value() {
  local name="claude_installer_fails_closed_for_an_anchored_agent_identity_value"
  local candidate_agent
  local expected_agent
  local canonical_agent
  local licence_file

  create_claude_fixture
  candidate_agent="$home_directory/.claude/agents/team-reviewer.md"
  expected_agent="$fixture_root/expected-team-reviewer.md"
  canonical_agent="$home_directory/.claude/agents/architect-reviewer.md"
  licence_file="$home_directory/.claude/agents.LICENSE"
  mkdir -p "$(dirname "$candidate_agent")"
  cat > "$candidate_agent" <<'EOF'
---
name: &reviewer architect-reviewer
---
EOF
  cp "$candidate_agent" "$expected_agent"
  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  export HOME XDG_CONFIG_HOME
  printf '\n\n\n \n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Eq '^CLAUDE_INSTALLER_EXIT=[1-9][0-9]*$'; then
    printf '[FAIL] %s: installer did not exit with a positive status\n' "$name"
    return 1
  fi

  if ! grep -Fq "cannot inspect agent identity in '$candidate_agent'; its name field is unreadable or malformed." "$session_log"; then
    printf '[FAIL] %s: malformed identity diagnostic did not identify the exact candidate path\n' "$name"
    return 1
  fi

  if ! cmp -s "$expected_agent" "$candidate_agent"; then
    printf '[FAIL] %s: candidate bytes changed after identity inspection failed\n' "$name"
    return 1
  fi

  if [[ -e "$canonical_agent" || -L "$canonical_agent" ]]; then
    printf '[FAIL] %s: canonical agent was written despite the malformed identity\n' "$name"
    return 1
  fi
  if [[ -e "$licence_file" || -L "$licence_file" ]]; then
    printf '[FAIL] %s: bundle licence was written despite the malformed identity\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_fails_closed_for_a_flow_mapping_agent_identity() {
  local name="claude_installer_fails_closed_for_a_flow_mapping_agent_identity"
  local candidate_agent
  local expected_agent
  local canonical_agent
  local licence_file

  create_claude_fixture
  candidate_agent="$home_directory/.claude/agents/team-reviewer.md"
  expected_agent="$fixture_root/expected-team-reviewer.md"
  canonical_agent="$home_directory/.claude/agents/architect-reviewer.md"
  licence_file="$home_directory/.claude/agents.LICENSE"
  mkdir -p "$(dirname "$candidate_agent")"
  cat > "$candidate_agent" <<'EOF'
---
{ name: architect-reviewer }
---
EOF
  cp "$candidate_agent" "$expected_agent"
  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  export HOME XDG_CONFIG_HOME
  printf '\n\n\n \n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Eq '^CLAUDE_INSTALLER_EXIT=[1-9][0-9]*$'; then
    printf '[FAIL] %s: installer did not exit with a positive status\n' "$name"
    return 1
  fi

  if ! grep -Fq "cannot inspect agent identity in '$candidate_agent'; its name field is unreadable or malformed." "$session_log"; then
    printf '[FAIL] %s: malformed identity diagnostic did not identify the exact candidate path\n' "$name"
    return 1
  fi

  if ! cmp -s "$expected_agent" "$candidate_agent"; then
    printf '[FAIL] %s: candidate bytes changed after identity inspection failed\n' "$name"
    return 1
  fi

  if [[ -e "$canonical_agent" || -L "$canonical_agent" ]]; then
    printf '[FAIL] %s: canonical agent was written despite the malformed identity\n' "$name"
    return 1
  fi
  if [[ -e "$licence_file" || -L "$licence_file" ]]; then
    printf '[FAIL] %s: bundle licence was written despite the malformed identity\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_fails_closed_for_a_quoted_agent_identity_key() {
  local name="claude_installer_fails_closed_for_a_quoted_agent_identity_key"
  local candidate_agent
  local expected_agent
  local canonical_agent
  local licence_file

  create_claude_fixture
  candidate_agent="$home_directory/.claude/agents/team-reviewer.md"
  expected_agent="$fixture_root/expected-team-reviewer.md"
  canonical_agent="$home_directory/.claude/agents/architect-reviewer.md"
  licence_file="$home_directory/.claude/agents.LICENSE"
  mkdir -p "$(dirname "$candidate_agent")"
  cat > "$candidate_agent" <<'EOF'
---
"name": architect-reviewer
---
EOF
  cp "$candidate_agent" "$expected_agent"
  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  export HOME XDG_CONFIG_HOME
  printf '\n\n\n \n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Eq '^CLAUDE_INSTALLER_EXIT=[1-9][0-9]*$'; then
    printf '[FAIL] %s: installer did not exit with a positive status\n' "$name"
    return 1
  fi

  if ! grep -Fq "cannot inspect agent identity in '$candidate_agent'; its name field is unreadable or malformed." "$session_log"; then
    printf '[FAIL] %s: malformed identity diagnostic did not identify the exact candidate path\n' "$name"
    return 1
  fi

  if ! cmp -s "$expected_agent" "$candidate_agent"; then
    printf '[FAIL] %s: candidate bytes changed after identity inspection failed\n' "$name"
    return 1
  fi

  if [[ -e "$canonical_agent" || -L "$canonical_agent" ]]; then
    printf '[FAIL] %s: canonical agent was written despite the malformed identity\n' "$name"
    return 1
  fi
  if [[ -e "$licence_file" || -L "$licence_file" ]]; then
    printf '[FAIL] %s: bundle licence was written despite the malformed identity\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_fails_closed_for_a_symlinked_agent_root() {
  local name="claude_installer_fails_closed_for_a_symlinked_agent_root"
  local agents_directory
  local external_agents_directory
  local competing_agent
  local expected_agent
  local canonical_agent
  local licence_file

  create_claude_fixture
  agents_directory="$home_directory/.claude/agents"
  external_agents_directory="$fixture_root/external-agents"
  competing_agent="$external_agents_directory/team.md"
  expected_agent="$fixture_root/expected-team.md"
  canonical_agent="$agents_directory/architect-reviewer.md"
  licence_file="$home_directory/.claude/agents.LICENSE"
  mkdir -p "$external_agents_directory" "$(dirname "$agents_directory")"
  cat > "$competing_agent" <<'EOF'
---
name: architect-reviewer
description: Fixture-local reviewer under a symlinked root
---

Preserve these reviewer bytes.
EOF
  cp "$competing_agent" "$expected_agent"
  ln -s "$external_agents_directory" "$agents_directory"
  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  export HOME XDG_CONFIG_HOME
  printf '\n\n\n \n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Eq '^CLAUDE_INSTALLER_EXIT=[1-9][0-9]*$'; then
    printf '[FAIL] %s: installer did not exit with a positive status\n' "$name"
    return 1
  fi
  if ! grep -Fq "cannot inspect agent scan root '$agents_directory'" "$session_log"; then
    printf '[FAIL] %s: fail-closed diagnostic did not name the exact symlinked scan root\n' "$name"
    return 1
  fi
  if ! cmp -s "$expected_agent" "$competing_agent"; then
    printf '[FAIL] %s: competitor bytes changed under the symlinked scan root\n' "$name"
    return 1
  fi
  if [[ -e "$licence_file" || -L "$licence_file" || -e "$canonical_agent" || -L "$canonical_agent" ]]; then
    printf '[FAIL] %s: bundle files were written through the symlinked scan root\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_fails_closed_for_a_symlinked_markdown_candidate() {
  local name="claude_installer_fails_closed_for_a_symlinked_markdown_candidate"
  local agents_directory
  local candidate_agent
  local external_agent
  local expected_agent
  local canonical_agent
  local licence_file

  create_claude_fixture
  agents_directory="$home_directory/.claude/agents"
  candidate_agent="$agents_directory/team-reviewer.md"
  external_agent="$fixture_root/external-team-reviewer.md"
  expected_agent="$fixture_root/expected-team-reviewer.md"
  canonical_agent="$agents_directory/architect-reviewer.md"
  licence_file="$home_directory/.claude/agents.LICENSE"
  mkdir -p "$agents_directory"
  cat > "$external_agent" <<'EOF'
---
name: architect-reviewer
description: Fixture-local reviewer behind a symlinked candidate
---

Preserve these reviewer bytes.
EOF
  cp "$external_agent" "$expected_agent"
  ln -s "$external_agent" "$candidate_agent"
  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  export HOME XDG_CONFIG_HOME
  printf '\n\n\n \n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Eq '^CLAUDE_INSTALLER_EXIT=[1-9][0-9]*$'; then
    printf '[FAIL] %s: installer did not exit with a positive status\n' "$name"
    return 1
  fi
  if ! grep -Fq "$candidate_agent" "$session_log"; then
    printf '[FAIL] %s: symlink diagnostic did not name the exact candidate path\n' "$name"
    return 1
  fi
  if [[ ! -L "$candidate_agent" || "$(readlink "$candidate_agent")" != "$external_agent" ]]; then
    printf '[FAIL] %s: candidate symlink was changed\n' "$name"
    return 1
  fi
  if ! cmp -s "$expected_agent" "$external_agent"; then
    printf '[FAIL] %s: candidate referent bytes changed\n' "$name"
    return 1
  fi
  if [[ -e "$licence_file" || -L "$licence_file" || -e "$canonical_agent" || -L "$canonical_agent" ]]; then
    printf '[FAIL] %s: bundle files were written despite the symlinked candidate\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_fails_closed_for_a_symlinked_nested_agent_directory() {
  local name="claude_installer_fails_closed_for_a_symlinked_nested_agent_directory"
  local agents_directory
  local nested_directory
  local external_directory
  local competing_agent
  local expected_agent
  local canonical_agent
  local licence_file

  create_claude_fixture
  agents_directory="$home_directory/.claude/agents"
  nested_directory="$agents_directory/review"
  external_directory="$fixture_root/external-review"
  competing_agent="$external_directory/team.md"
  expected_agent="$fixture_root/expected-team.md"
  canonical_agent="$agents_directory/architect-reviewer.md"
  licence_file="$home_directory/.claude/agents.LICENSE"
  mkdir -p "$agents_directory" "$external_directory"
  cat > "$competing_agent" <<'EOF'
---
name: architect-reviewer
description: Fixture-local reviewer under a nested symlink
---

Preserve these reviewer bytes.
EOF
  cp "$competing_agent" "$expected_agent"
  ln -s "$external_directory" "$nested_directory"
  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  export HOME XDG_CONFIG_HOME
  printf '\n\n\n \n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Eq '^CLAUDE_INSTALLER_EXIT=[1-9][0-9]*$'; then
    printf '[FAIL] %s: installer did not exit with a positive status\n' "$name"
    return 1
  fi
  if ! grep -Fq "$nested_directory" "$session_log"; then
    printf '[FAIL] %s: symlink diagnostic did not name the exact nested directory path\n' "$name"
    return 1
  fi
  if [[ ! -L "$nested_directory" || "$(readlink "$nested_directory")" != "$external_directory" ]]; then
    printf '[FAIL] %s: nested directory symlink was changed\n' "$name"
    return 1
  fi
  if ! cmp -s "$expected_agent" "$competing_agent"; then
    printf '[FAIL] %s: nested candidate bytes changed\n' "$name"
    return 1
  fi
  if [[ -e "$licence_file" || -L "$licence_file" || -e "$canonical_agent" || -L "$canonical_agent" ]]; then
    printf '[FAIL] %s: bundle files were written despite the nested symlink\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_ignores_a_non_markdown_agent_symlink() {
  local name="claude_installer_ignores_a_non_markdown_agent_symlink"
  local agents_directory
  local referent_file
  local expected_referent
  local non_markdown_symlink
  local canonical_agent
  local source_agent
  local notice_file

  create_claude_fixture
  agents_directory="$home_directory/.claude/agents"
  referent_file="$fixture_root/notes.txt"
  expected_referent="$fixture_root/expected-notes.txt"
  non_markdown_symlink="$agents_directory/notes.txt"
  canonical_agent="$agents_directory/architect-reviewer.md"
  source_agent="$invocation_dir/agents/claude/architect-reviewer.md"
  notice_file="$home_directory/.claude/agents.LICENSE"
  mkdir -p "$agents_directory"
  printf 'Plain-text notes with no agent identity.\n' > "$referent_file"
  cp "$referent_file" "$expected_referent"
  ln -s "$referent_file" "$non_markdown_symlink"
  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  export HOME XDG_CONFIG_HOME
  printf '\n\n\n \n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Fqx 'CLAUDE_INSTALLER_EXIT=0'; then
    printf '[FAIL] %s: installer did not exit with status 0\n' "$name"
    return 1
  fi

  if [[ ! -L "$non_markdown_symlink" || "$(readlink "$non_markdown_symlink")" != "$referent_file" ]]; then
    printf '[FAIL] %s: non-Markdown agent symlink no longer points to its fixture-local referent\n' "$name"
    return 1
  fi
  if ! cmp -s "$expected_referent" "$referent_file"; then
    printf '[FAIL] %s: non-Markdown symlink referent bytes changed\n' "$name"
    return 1
  fi
  if [[ ! -f "$canonical_agent" ]] || ! cmp -s "$source_agent" "$canonical_agent"; then
    printf '[FAIL] %s: canonical bundled architect-reviewer.md is missing or differs from its source\n' "$name"
    return 1
  fi
  if [[ ! -f "$notice_file" ]] || ! cmp -s "$invocation_dir/agents/LICENSE" "$notice_file"; then
    printf '[FAIL] %s: sibling agents.LICENSE is missing or differs from its source\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_fails_closed_for_an_indented_quoted_agent_identity_key() {
  local name="claude_installer_fails_closed_for_an_indented_quoted_agent_identity_key"
  local candidate_agent
  local expected_agent
  local canonical_agent
  local licence_file

  create_claude_fixture
  candidate_agent="$home_directory/.claude/agents/team-reviewer.md"
  expected_agent="$fixture_root/expected-team-reviewer.md"
  canonical_agent="$home_directory/.claude/agents/architect-reviewer.md"
  licence_file="$home_directory/.claude/agents.LICENSE"
  mkdir -p "$(dirname "$candidate_agent")"
  cat > "$candidate_agent" <<'EOF'
---
  "name": architect-reviewer
---
EOF
  cp "$candidate_agent" "$expected_agent"
  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  export HOME XDG_CONFIG_HOME
  printf '\n\n\n \n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Eq '^CLAUDE_INSTALLER_EXIT=[1-9][0-9]*$'; then
    printf '[FAIL] %s: installer did not exit with a positive status\n' "$name"
    return 1
  fi
  if ! grep -Fq "cannot inspect agent identity in '$candidate_agent'; its name field is unreadable or malformed." "$session_log"; then
    printf '[FAIL] %s: malformed identity diagnostic did not name the exact candidate path\n' "$name"
    return 1
  fi
  if ! cmp -s "$expected_agent" "$candidate_agent"; then
    printf '[FAIL] %s: candidate bytes changed after identity inspection failed\n' "$name"
    return 1
  fi
  if [[ -e "$canonical_agent" || -L "$canonical_agent" || -e "$licence_file" || -L "$licence_file" ]]; then
    printf '[FAIL] %s: bundle files were written despite the malformed identity\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_fails_closed_for_an_indented_block_scalar_agent_identity() {
  local name="claude_installer_fails_closed_for_an_indented_block_scalar_agent_identity"
  local candidate_agent
  local expected_agent
  local canonical_agent
  local licence_file

  create_claude_fixture
  candidate_agent="$home_directory/.claude/agents/team-reviewer.md"
  expected_agent="$fixture_root/expected-team-reviewer.md"
  canonical_agent="$home_directory/.claude/agents/architect-reviewer.md"
  licence_file="$home_directory/.claude/agents.LICENSE"
  mkdir -p "$(dirname "$candidate_agent")"
  cat > "$candidate_agent" <<'EOF'
---
  name: >-
    architect-reviewer
---
EOF
  cp "$candidate_agent" "$expected_agent"
  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  export HOME XDG_CONFIG_HOME
  printf '\n\n\n \n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Eq '^CLAUDE_INSTALLER_EXIT=[1-9][0-9]*$'; then
    printf '[FAIL] %s: installer did not exit with a positive status\n' "$name"
    return 1
  fi
  if ! grep -Fq "cannot inspect agent identity in '$candidate_agent'; its name field is unreadable or malformed." "$session_log"; then
    printf '[FAIL] %s: malformed identity diagnostic did not name the exact candidate path\n' "$name"
    return 1
  fi
  if ! cmp -s "$expected_agent" "$candidate_agent"; then
    printf '[FAIL] %s: candidate bytes changed after identity inspection failed\n' "$name"
    return 1
  fi
  if [[ -e "$canonical_agent" || -L "$canonical_agent" || -e "$licence_file" || -L "$licence_file" ]]; then
    printf '[FAIL] %s: bundle files were written despite the malformed identity\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_fails_closed_for_a_double_quoted_escaped_agent_identity_value() {
  local name="claude_installer_fails_closed_for_a_double_quoted_escaped_agent_identity_value"
  local candidate_agent
  local expected_agent
  local canonical_agent
  local licence_file

  create_claude_fixture
  candidate_agent="$home_directory/.claude/agents/team-reviewer.md"
  expected_agent="$fixture_root/expected-team-reviewer.md"
  canonical_agent="$home_directory/.claude/agents/architect-reviewer.md"
  licence_file="$home_directory/.claude/agents.LICENSE"
  mkdir -p "$(dirname "$candidate_agent")"
  cat > "$candidate_agent" <<'EOF'
---
name: "architect\u002dreviewer"
---
EOF
  cp "$candidate_agent" "$expected_agent"
  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  export HOME XDG_CONFIG_HOME
  printf '\n\n\n \n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Eq '^CLAUDE_INSTALLER_EXIT=[1-9][0-9]*$'; then
    printf '[FAIL] %s: installer did not exit with a positive status\n' "$name"
    return 1
  fi
  if ! grep -Fq "cannot inspect agent identity in '$candidate_agent'; its name field is unreadable or malformed." "$session_log"; then
    printf '[FAIL] %s: malformed identity diagnostic did not name the exact candidate path\n' "$name"
    return 1
  fi
  if ! cmp -s "$expected_agent" "$candidate_agent"; then
    printf '[FAIL] %s: candidate bytes changed after identity inspection failed\n' "$name"
    return 1
  fi
  if [[ -e "$canonical_agent" || -L "$canonical_agent" ]]; then
    printf '[FAIL] %s: canonical agent was written despite the malformed identity\n' "$name"
    return 1
  fi
  if [[ -e "$licence_file" || -L "$licence_file" ]]; then
    printf '[FAIL] %s: bundle licence was written despite the malformed identity\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_fails_closed_for_an_escaped_quoted_agent_identity_key() {
  local name="claude_installer_fails_closed_for_an_escaped_quoted_agent_identity_key"
  local candidate_agent
  local expected_agent
  local canonical_agent
  local licence_file

  create_claude_fixture
  candidate_agent="$home_directory/.claude/agents/team-reviewer.md"
  expected_agent="$fixture_root/expected-team-reviewer.md"
  canonical_agent="$home_directory/.claude/agents/architect-reviewer.md"
  licence_file="$home_directory/.claude/agents.LICENSE"
  mkdir -p "$(dirname "$candidate_agent")"
  cat > "$candidate_agent" <<'EOF'
---
"na\u006de": architect-reviewer
---
EOF
  cp "$candidate_agent" "$expected_agent"
  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  export HOME XDG_CONFIG_HOME
  printf '\n\n\n \n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Eq '^CLAUDE_INSTALLER_EXIT=[1-9][0-9]*$'; then
    printf '[FAIL] %s: installer did not exit with a positive status\n' "$name"
    return 1
  fi
  if ! grep -Fq "cannot inspect agent identity in '$candidate_agent'; its name field is unreadable or malformed." "$session_log"; then
    printf '[FAIL] %s: malformed identity diagnostic did not name the exact candidate path\n' "$name"
    return 1
  fi
  if ! cmp -s "$expected_agent" "$candidate_agent"; then
    printf '[FAIL] %s: candidate bytes changed after identity inspection failed\n' "$name"
    return 1
  fi
  if [[ -e "$canonical_agent" || -L "$canonical_agent" ]]; then
    printf '[FAIL] %s: canonical agent was written despite the malformed identity\n' "$name"
    return 1
  fi
  if [[ -e "$licence_file" || -L "$licence_file" ]]; then
    printf '[FAIL] %s: bundle licence was written despite the malformed identity\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_fails_closed_for_an_explicit_agent_identity_key() {
  local name="claude_installer_fails_closed_for_an_explicit_agent_identity_key"
  local candidate_agent
  local expected_agent
  local canonical_agent
  local licence_file

  create_claude_fixture
  candidate_agent="$home_directory/.claude/agents/team-reviewer.md"
  expected_agent="$fixture_root/expected-team-reviewer.md"
  canonical_agent="$home_directory/.claude/agents/architect-reviewer.md"
  licence_file="$home_directory/.claude/agents.LICENSE"
  mkdir -p "$(dirname "$candidate_agent")"
  cat > "$candidate_agent" <<'EOF'
---
? name
: architect-reviewer
---
EOF
  cp "$candidate_agent" "$expected_agent"
  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  export HOME XDG_CONFIG_HOME
  printf '\n\n\n \n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Eq '^CLAUDE_INSTALLER_EXIT=[1-9][0-9]*$'; then
    printf '[FAIL] %s: installer did not exit with a positive status\n' "$name"
    return 1
  fi
  if ! grep -Fq "cannot inspect agent identity in '$candidate_agent'; its name field is unreadable or malformed." "$session_log"; then
    printf '[FAIL] %s: malformed identity diagnostic did not name the exact candidate path\n' "$name"
    return 1
  fi
  if ! cmp -s "$expected_agent" "$candidate_agent"; then
    printf '[FAIL] %s: candidate bytes changed after identity inspection failed\n' "$name"
    return 1
  fi
  if [[ -e "$canonical_agent" || -L "$canonical_agent" ]]; then
    printf '[FAIL] %s: canonical agent was written despite the malformed identity\n' "$name"
    return 1
  fi
  if [[ -e "$licence_file" || -L "$licence_file" ]]; then
    printf '[FAIL] %s: bundle licence was written despite the malformed identity\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_fails_closed_for_an_indented_agent_identity_after_document_end_marker() {
  local name="claude_installer_fails_closed_for_an_indented_agent_identity_after_document_end_marker"
  local candidate_agent
  local expected_agent
  local canonical_agent
  local licence_file

  create_claude_fixture
  candidate_agent="$home_directory/.claude/agents/team-reviewer.md"
  expected_agent="$fixture_root/expected-team-reviewer.md"
  canonical_agent="$home_directory/.claude/agents/architect-reviewer.md"
  licence_file="$home_directory/.claude/agents.LICENSE"
  mkdir -p "$(dirname "$candidate_agent")"
  cat > "$candidate_agent" <<'EOF'
---
  name: architect-reviewer
...
---
EOF
  cp "$candidate_agent" "$expected_agent"
  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  export HOME XDG_CONFIG_HOME
  printf '\n\n\n \n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Eq '^CLAUDE_INSTALLER_EXIT=[1-9][0-9]*$'; then
    printf '[FAIL] %s: installer did not exit with a positive status\n' "$name"
    return 1
  fi
  if ! grep -Fq "cannot inspect agent identity in '$candidate_agent'; its name field is unreadable or malformed." "$session_log"; then
    printf '[FAIL] %s: malformed identity diagnostic did not name the exact candidate path\n' "$name"
    return 1
  fi
  if ! cmp -s "$expected_agent" "$candidate_agent"; then
    printf '[FAIL] %s: candidate bytes changed after identity inspection failed\n' "$name"
    return 1
  fi
  if [[ -e "$canonical_agent" || -L "$canonical_agent" ]]; then
    printf '[FAIL] %s: canonical agent was written despite the malformed identity\n' "$name"
    return 1
  fi
  if [[ -e "$licence_file" || -L "$licence_file" ]]; then
    printf '[FAIL] %s: bundle licence was written despite the malformed identity\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_fails_closed_when_project_agent_root_has_an_inaccessible_ancestor() {
  local name="claude_installer_fails_closed_when_project_agent_root_has_an_inaccessible_ancestor"
  local project_claude_directory
  local project_agents_directory
  local candidate_agent
  local expected_agent
  local canonical_agent
  local licence_file
  local original_mode
  local restored_mode

  create_claude_fixture
  project_claude_directory="$fixture_root/project/.claude"
  project_agents_directory="$project_claude_directory/agents"
  candidate_agent="$project_agents_directory/team-reviewer.md"
  expected_agent="$fixture_root/expected-team-reviewer.md"
  canonical_agent="$home_directory/.claude/agents/architect-reviewer.md"
  licence_file="$home_directory/.claude/agents.LICENSE"
  mkdir -p "$project_agents_directory"
  cat > "$candidate_agent" <<'EOF'
---
name: architect-reviewer
---

Preserve this project-authored team reviewer.
EOF
  cp "$candidate_agent" "$expected_agent"
  original_mode="$(stat -f '%Lp' "$project_claude_directory")"
  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  export HOME XDG_CONFIG_HOME
  /bin/chmod 000 "$project_claude_directory"
  printf '\n\n\n \n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null
  /bin/chmod "$original_mode" "$project_claude_directory"

  restored_mode="$(stat -f '%Lp' "$project_claude_directory")"
  if [[ "$restored_mode" != "$original_mode" ]]; then
    printf '[FAIL] %s: project .claude directory mode was not restored\n' "$name"
    return 1
  fi
  if ! sed 's/\r$//' "$session_log" | grep -Fqx 'CLAUDE_INSTALLER_EXIT=1'; then
    printf '[FAIL] %s: installer did not exit with status 1\n' "$name"
    return 1
  fi
  if ! grep -Fq "cannot inspect agent scan root '$project_agents_directory'; ensure it is a readable and searchable directory." "$session_log"; then
    printf '[FAIL] %s: scan-root diagnostic did not name the inaccessible project agent root\n' "$name"
    return 1
  fi
  if ! cmp -s "$expected_agent" "$candidate_agent"; then
    printf '[FAIL] %s: project candidate bytes changed after scan-root inspection failed\n' "$name"
    return 1
  fi
  if [[ -e "$canonical_agent" || -L "$canonical_agent" ]]; then
    printf '[FAIL] %s: canonical user agent was written despite the inaccessible project agent root\n' "$name"
    return 1
  fi
  if [[ -e "$licence_file" || -L "$licence_file" ]]; then
    printf '[FAIL] %s: user bundle licence was written despite the inaccessible project agent root\n' "$name"
    return 1
  fi

  return 0
}

test_agent_bundle_notice_rejects_a_mismatched_notice_at_eof_without_changing_it() {
  local existing_notice expected_notice
  local manifest_entries=('rules/retained.md')
  local changed_paths=()

  create_claude_fixture
  existing_notice="$home_directory/.claude/agents.LICENSE"
  expected_notice="$fixture_root/expected-agents.LICENSE"
  mkdir -p "$(dirname "$existing_notice")"
  printf 'User-authored notice to preserve at EOF.\n' > "$existing_notice"
  cp "$existing_notice" "$expected_notice"
  source "$repository_root/_install-common.sh"

  if install_agent_bundle_notice "$repository_root/agents/LICENSE" "$existing_notice" agents.LICENSE manifest_entries changed_paths < /dev/null > "$fixture_root/helper-output" 2>&1; then
    printf '[FAIL] notice replacement at EOF succeeded for a mismatched notice\n'
    return 1
  fi
  if ! cmp -s "$expected_notice" "$existing_notice"; then
    printf '[FAIL] notice replacement at EOF changed the mismatched notice\n'
    return 1
  fi
}

test_agent_bundle_notice_preserves_an_identical_notice_at_eof_without_claiming_it() {
  local existing_notice
  local manifest_entries=('rules/retained.md')
  local changed_paths=()

  create_claude_fixture
  existing_notice="$home_directory/.claude/agents.LICENSE"
  mkdir -p "$(dirname "$existing_notice")"
  cp "$repository_root/agents/LICENSE" "$existing_notice"
  source "$repository_root/_install-common.sh"

  if ! install_agent_bundle_notice "$repository_root/agents/LICENSE" "$existing_notice" agents.LICENSE manifest_entries changed_paths < /dev/null > "$fixture_root/helper-output" 2>&1; then
    printf '[FAIL] notice replacement at EOF failed for an identical notice\n'
    return 1
  fi
  if ! cmp -s "$repository_root/agents/LICENSE" "$existing_notice"; then
    printf '[FAIL] notice replacement at EOF changed the identical notice\n'
    return 1
  fi
  if [[ "${#manifest_entries[@]}" -ne 1 || "${manifest_entries[0]}" != 'rules/retained.md' ]]; then
    printf '[FAIL] notice replacement at EOF changed the manifest entries\n'
    return 1
  fi
}

test_agent_bundle_files_preserves_an_unmanaged_agent_at_eof_without_claiming_it() {
  local output_directory existing_agent expected_agent
  local agent_files=('architect-reviewer.md')
  local manifest_entries=('rules/retained.md')
  local changed_paths=()

  create_claude_fixture
  output_directory="$home_directory/.claude/agents"
  existing_agent="$output_directory/architect-reviewer.md"
  expected_agent="$fixture_root/expected-architect-reviewer.md"
  mkdir -p "$output_directory"
  printf 'User-authored agent to preserve at EOF.\n' > "$existing_agent"
  cp "$existing_agent" "$expected_agent"
  source "$repository_root/_install-common.sh"

  if ! install_agent_bundle_files "$invocation_dir/agents/claude" "$output_directory" agents manifest_entries agent_files changed_paths < /dev/null > "$fixture_root/helper-output" 2>&1; then
    printf '[FAIL] agent replacement at EOF returned a failure\n'
    return 1
  fi
  if ! cmp -s "$expected_agent" "$existing_agent"; then
    printf '[FAIL] agent replacement at EOF changed the existing agent\n'
    return 1
  fi
  if [[ "${#manifest_entries[@]}" -ne 1 || "${manifest_entries[0]}" != 'rules/retained.md' ]]; then
    printf '[FAIL] agent replacement at EOF changed the manifest entries\n'
    return 1
  fi
}

test_agent_bundle_helper_prompts_before_refusing_a_dangling_canonical_agent_symlink() {
  local name="agent_bundle_helper_prompts_before_refusing_a_dangling_canonical_agent_symlink"
  local source_directory
  local output_directory
  local canonical_agent
  local dangling_referent
  local response_file
  local helper_output
  local helper_status
  local agent_files
  local manifest_entries
  local changed_paths

  create_claude_fixture
  source_directory="$fixture_root/source-agents"
  output_directory="$home_directory/.claude/agents"
  canonical_agent="$output_directory/architect-reviewer.md"
  dangling_referent="$fixture_root/dangling-agent-referent"
  response_file="$fixture_root/helper-response"
  helper_output="$fixture_root/helper-output"
  mkdir -p "$source_directory" "$(dirname "$canonical_agent")"
  cp "$repository_root/agents/claude/architect-reviewer.md" "$source_directory/architect-reviewer.md"
  ln -s "$dangling_referent" "$canonical_agent"
  printf 'n\n' > "$response_file"
  source "$repository_root/_install-common.sh"
  agent_files=(architect-reviewer.md)
  manifest_entries=()
  changed_paths=()
  if install_agent_bundle_files "$source_directory" "$output_directory" agents manifest_entries agent_files changed_paths < "$response_file" > "$helper_output" 2>&1; then
    helper_status=0
  else
    helper_status=$?
  fi

  if [[ "$helper_status" -ne 0 ]]; then
    printf '[FAIL] %s: refusing replacement returned status %s instead of 0\n' "$name" "$helper_status"
    return 1
  fi
  if ! grep -Fq 'Replace existing agent' "$helper_output" || ! grep -Fq 'architect-reviewer.md' "$helper_output" || ! grep -Fq '[y/n]' "$helper_output"; then
    printf '[FAIL] %s: helper did not prompt for [y/n] consent to replace the canonical agent\n' "$name"
    return 1
  fi
  if [[ ! -L "$canonical_agent" || "$(readlink "$canonical_agent")" != "$dangling_referent" ]]; then
    printf '[FAIL] %s: refusal did not preserve the dangling canonical symlink\n' "$name"
    return 1
  fi
  if [[ -e "$dangling_referent" || "${#manifest_entries[@]}" -ne 0 || "${#changed_paths[@]}" -ne 0 ]]; then
    printf '[FAIL] %s: refusal wrote the referent or recorded bundle changes\n' "$name"
    return 1
  fi

  return 0
}

test_agent_bundle_helper_replaces_a_dangling_canonical_agent_symlink_after_consent() {
  local name="agent_bundle_helper_replaces_a_dangling_canonical_agent_symlink_after_consent"
  local source_directory
  local output_directory
  local canonical_agent
  local dangling_referent
  local response_file
  local helper_output
  local helper_status
  local agent_files
  local manifest_entries
  local changed_paths

  create_claude_fixture
  source_directory="$fixture_root/source-agents"
  output_directory="$home_directory/.claude/agents"
  canonical_agent="$output_directory/architect-reviewer.md"
  dangling_referent="$fixture_root/dangling-agent-referent"
  response_file="$fixture_root/helper-response"
  helper_output="$fixture_root/helper-output"
  mkdir -p "$source_directory" "$(dirname "$canonical_agent")"
  cp "$repository_root/agents/claude/architect-reviewer.md" "$source_directory/architect-reviewer.md"
  ln -s "$dangling_referent" "$canonical_agent"
  printf 'y\n' > "$response_file"
  source "$repository_root/_install-common.sh"
  agent_files=(architect-reviewer.md)
  manifest_entries=()
  changed_paths=()
  if install_agent_bundle_files "$source_directory" "$output_directory" agents manifest_entries agent_files changed_paths < "$response_file" > "$helper_output" 2>&1; then
    helper_status=0
  else
    helper_status=$?
  fi

  if [[ "$helper_status" -ne 0 ]]; then
    printf '[FAIL] %s: consented replacement returned status %s instead of 0\n' "$name" "$helper_status"
    return 1
  fi
  if ! grep -Fq 'Replace existing agent' "$helper_output" || ! grep -Fq 'architect-reviewer.md' "$helper_output" || ! grep -Fq '[y/n]' "$helper_output"; then
    printf '[FAIL] %s: helper did not prompt for [y/n] consent to replace the canonical agent\n' "$name"
    return 1
  fi
  if [[ -L "$canonical_agent" || ! -f "$canonical_agent" ]]; then
    printf '[FAIL] %s: consent did not replace the symlink with a regular file\n' "$name"
    return 1
  fi
  if ! cmp -s "$source_directory/architect-reviewer.md" "$canonical_agent"; then
    printf '[FAIL] %s: consented canonical file differs from the bundled source\n' "$name"
    return 1
  fi
  if [[ -e "$dangling_referent" ]]; then
    printf '[FAIL] %s: consent wrote through the symlink to its referent\n' "$name"
    return 1
  fi
  if [[ "${#manifest_entries[@]}" -ne 1 || "${manifest_entries[0]}" != 'agents/architect-reviewer.md' || "${#changed_paths[@]}" -ne 1 || "${changed_paths[0]}" != "$canonical_agent" ]]; then
    printf '[FAIL] %s: consented replacement did not record the canonical manifest and changed paths\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_blocks_a_conflict_with_whitespace_before_name_separator() {
  local name="claude_installer_blocks_a_conflict_with_whitespace_before_name_separator"
  local candidate_agent
  local expected_agent
  local canonical_agent
  local licence_file

  create_claude_fixture
  candidate_agent="$home_directory/.claude/agents/team-reviewer.md"
  expected_agent="$fixture_root/expected-team-reviewer.md"
  canonical_agent="$home_directory/.claude/agents/architect-reviewer.md"
  licence_file="$home_directory/.claude/agents.LICENSE"
  mkdir -p "$(dirname "$candidate_agent")"
  cat > "$candidate_agent" <<'EOF'
---
name : architect-reviewer
---
EOF
  cp "$candidate_agent" "$expected_agent"
  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  export HOME XDG_CONFIG_HOME
  printf '\n\n\n \n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Eq '^CLAUDE_INSTALLER_EXIT=[1-9][0-9]*$'; then
    printf '[FAIL] %s: installer did not exit with a positive status\n' "$name"
    return 1
  fi
  if ! grep -Fq "competing agent definition at $candidate_agent claims bundled identity architect-reviewer" "$session_log"; then
    printf '[FAIL] %s: conflict diagnostic did not identify the exact candidate path and identity\n' "$name"
    return 1
  fi
  if ! cmp -s "$expected_agent" "$candidate_agent"; then
    printf '[FAIL] %s: candidate bytes changed after the identity conflict\n' "$name"
    return 1
  fi
  if [[ -e "$canonical_agent" || -L "$canonical_agent" ]]; then
    printf '[FAIL] %s: canonical agent was written despite the identity conflict\n' "$name"
    return 1
  fi
  if [[ -e "$licence_file" || -L "$licence_file" ]]; then
    printf '[FAIL] %s: bundle licence was written despite the identity conflict\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_fails_closed_for_a_tagged_agent_identity_value() {
  local name="claude_installer_fails_closed_for_a_tagged_agent_identity_value"
  local candidate_agent
  local expected_agent
  local canonical_agent
  local licence_file

  create_claude_fixture
  candidate_agent="$home_directory/.claude/agents/team-reviewer.md"
  expected_agent="$fixture_root/expected-team-reviewer.md"
  canonical_agent="$home_directory/.claude/agents/architect-reviewer.md"
  licence_file="$home_directory/.claude/agents.LICENSE"
  mkdir -p "$(dirname "$candidate_agent")"
  cat > "$candidate_agent" <<'EOF'
---
name: !!str architect-reviewer
---
EOF
  cp "$candidate_agent" "$expected_agent"
  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  export HOME XDG_CONFIG_HOME
  printf '\n\n\n \n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Eq '^CLAUDE_INSTALLER_EXIT=[1-9][0-9]*$'; then
    printf '[FAIL] %s: installer did not exit with a positive status\n' "$name"
    return 1
  fi
  if ! grep -Fq "cannot inspect agent identity in '$candidate_agent'; its name field is unreadable or malformed." "$session_log"; then
    printf '[FAIL] %s: malformed identity diagnostic did not name the exact candidate path\n' "$name"
    return 1
  fi
  if ! cmp -s "$expected_agent" "$candidate_agent"; then
    printf '[FAIL] %s: candidate bytes changed after identity inspection failed\n' "$name"
    return 1
  fi
  if [[ -e "$canonical_agent" || -L "$canonical_agent" ]]; then
    printf '[FAIL] %s: canonical agent was written despite the malformed identity\n' "$name"
    return 1
  fi
  if [[ -e "$licence_file" || -L "$licence_file" ]]; then
    printf '[FAIL] %s: bundle licence was written despite the malformed identity\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_fails_closed_for_an_anchored_root_flow_mapping_agent_identity() {
  local name="claude_installer_fails_closed_for_an_anchored_root_flow_mapping_agent_identity"
  local candidate_agent
  local expected_agent
  local canonical_agent
  local licence_file

  create_claude_fixture
  candidate_agent="$home_directory/.claude/agents/team-reviewer.md"
  expected_agent="$fixture_root/expected-team-reviewer.md"
  canonical_agent="$home_directory/.claude/agents/architect-reviewer.md"
  licence_file="$home_directory/.claude/agents.LICENSE"
  mkdir -p "$(dirname "$candidate_agent")"
  cat > "$candidate_agent" <<'EOF'
---
&reviewer { name: architect-reviewer }
---
EOF
  cp "$candidate_agent" "$expected_agent"
  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  export HOME XDG_CONFIG_HOME
  printf '\n\n\n \n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Eq '^CLAUDE_INSTALLER_EXIT=[1-9][0-9]*$'; then
    printf '[FAIL] %s: installer did not exit with a positive status\n' "$name"
    return 1
  fi
  if ! grep -Fq "cannot inspect agent identity in '$candidate_agent'; its name field is unreadable or malformed." "$session_log"; then
    printf '[FAIL] %s: malformed identity diagnostic did not name the exact candidate path\n' "$name"
    return 1
  fi
  if ! cmp -s "$expected_agent" "$candidate_agent"; then
    printf '[FAIL] %s: candidate bytes changed after identity inspection failed\n' "$name"
    return 1
  fi
  if [[ -e "$canonical_agent" || -L "$canonical_agent" ]]; then
    printf '[FAIL] %s: canonical agent was written despite the malformed identity\n' "$name"
    return 1
  fi
  if [[ -e "$licence_file" || -L "$licence_file" ]]; then
    printf '[FAIL] %s: bundle licence was written despite the malformed identity\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_fails_closed_for_a_tagged_root_flow_mapping_agent_identity() {
  local name="claude_installer_fails_closed_for_a_tagged_root_flow_mapping_agent_identity"
  local candidate_agent
  local expected_agent
  local canonical_agent
  local licence_file

  create_claude_fixture
  candidate_agent="$home_directory/.claude/agents/team-reviewer.md"
  expected_agent="$fixture_root/expected-team-reviewer.md"
  canonical_agent="$home_directory/.claude/agents/architect-reviewer.md"
  licence_file="$home_directory/.claude/agents.LICENSE"
  mkdir -p "$(dirname "$candidate_agent")"
  cat > "$candidate_agent" <<'EOF'
---
!!map { name: architect-reviewer }
---
EOF
  cp "$candidate_agent" "$expected_agent"
  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  export HOME XDG_CONFIG_HOME
  printf '\n\n\n \n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Eq '^CLAUDE_INSTALLER_EXIT=[1-9][0-9]*$'; then
    printf '[FAIL] %s: installer did not exit with a positive status\n' "$name"
    return 1
  fi
  if ! grep -Fq "cannot inspect agent identity in '$candidate_agent'; its name field is unreadable or malformed." "$session_log"; then
    printf '[FAIL] %s: malformed identity diagnostic did not name the exact candidate path\n' "$name"
    return 1
  fi
  if ! cmp -s "$expected_agent" "$candidate_agent"; then
    printf '[FAIL] %s: candidate bytes changed after identity inspection failed\n' "$name"
    return 1
  fi
  if [[ -e "$canonical_agent" || -L "$canonical_agent" ]]; then
    printf '[FAIL] %s: canonical agent was written despite the malformed identity\n' "$name"
    return 1
  fi
  if [[ -e "$licence_file" || -L "$licence_file" ]]; then
    printf '[FAIL] %s: bundle licence was written despite the malformed identity\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_fails_closed_for_a_plain_yaml_merge_key_agent_identity() {
  local name="claude_installer_fails_closed_for_a_plain_yaml_merge_key_agent_identity"
  local candidate_agent
  local expected_agent
  local canonical_agent
  local licence_file

  create_claude_fixture
  candidate_agent="$home_directory/.claude/agents/team-reviewer.md"
  expected_agent="$fixture_root/expected-team-reviewer.md"
  canonical_agent="$home_directory/.claude/agents/architect-reviewer.md"
  licence_file="$home_directory/.claude/agents.LICENSE"
  mkdir -p "$(dirname "$candidate_agent")"
  cat > "$candidate_agent" <<'EOF'
---
defaults: &defaults
  name: architect-reviewer
<< : *defaults
---
EOF
  cp "$candidate_agent" "$expected_agent"
  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  export HOME XDG_CONFIG_HOME
  printf '\n\n\n \n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Eq '^CLAUDE_INSTALLER_EXIT=[1-9][0-9]*$'; then
    printf '[FAIL] %s: installer did not exit with a positive status\n' "$name"
    return 1
  fi
  if ! grep -Fq "cannot inspect agent identity in '$candidate_agent'; its name field is unreadable or malformed." "$session_log"; then
    printf '[FAIL] %s: malformed identity diagnostic did not name the exact candidate path\n' "$name"
    return 1
  fi
  if ! cmp -s "$expected_agent" "$candidate_agent"; then
    printf '[FAIL] %s: candidate bytes changed after identity inspection failed\n' "$name"
    return 1
  fi
  if [[ -e "$canonical_agent" || -L "$canonical_agent" ]]; then
    printf '[FAIL] %s: canonical agent was written despite the malformed identity\n' "$name"
    return 1
  fi
  if [[ -e "$licence_file" || -L "$licence_file" ]]; then
    printf '[FAIL] %s: bundle licence was written despite the malformed identity\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_fails_closed_for_a_double_quoted_yaml_merge_key_agent_identity() {
  local name="claude_installer_fails_closed_for_a_double_quoted_yaml_merge_key_agent_identity"
  local candidate_agent
  local expected_agent
  local canonical_agent
  local licence_file

  create_claude_fixture
  candidate_agent="$home_directory/.claude/agents/team-reviewer.md"
  expected_agent="$fixture_root/expected-team-reviewer.md"
  canonical_agent="$home_directory/.claude/agents/architect-reviewer.md"
  licence_file="$home_directory/.claude/agents.LICENSE"
  mkdir -p "$(dirname "$candidate_agent")"
  cat > "$candidate_agent" <<'EOF'
---
defaults: &defaults
  name: architect-reviewer
"<<" : *defaults
---
EOF
  cp "$candidate_agent" "$expected_agent"
  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  export HOME XDG_CONFIG_HOME
  printf '\n\n\n \n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Eq '^CLAUDE_INSTALLER_EXIT=[1-9][0-9]*$'; then
    printf '[FAIL] %s: installer did not exit with a positive status\n' "$name"
    return 1
  fi
  if ! grep -Fq "cannot inspect agent identity in '$candidate_agent'; its name field is unreadable or malformed." "$session_log"; then
    printf '[FAIL] %s: malformed identity diagnostic did not name the exact candidate path\n' "$name"
    return 1
  fi
  if ! cmp -s "$expected_agent" "$candidate_agent"; then
    printf '[FAIL] %s: candidate bytes changed after identity inspection failed\n' "$name"
    return 1
  fi
  if [[ -e "$canonical_agent" || -L "$canonical_agent" ]]; then
    printf '[FAIL] %s: canonical agent was written despite the malformed identity\n' "$name"
    return 1
  fi
  if [[ -e "$licence_file" || -L "$licence_file" ]]; then
    printf '[FAIL] %s: bundle licence was written despite the malformed identity\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_fails_closed_for_a_single_quoted_yaml_merge_key_agent_identity() {
  local name="claude_installer_fails_closed_for_a_single_quoted_yaml_merge_key_agent_identity"
  local candidate_agent
  local expected_agent
  local canonical_agent
  local licence_file

  create_claude_fixture
  candidate_agent="$home_directory/.claude/agents/team-reviewer.md"
  expected_agent="$fixture_root/expected-team-reviewer.md"
  canonical_agent="$home_directory/.claude/agents/architect-reviewer.md"
  licence_file="$home_directory/.claude/agents.LICENSE"
  mkdir -p "$(dirname "$candidate_agent")"
  cat > "$candidate_agent" <<'EOF'
---
defaults: &defaults
  name: architect-reviewer
'<<' : *defaults
---
EOF
  cp "$candidate_agent" "$expected_agent"
  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  export HOME XDG_CONFIG_HOME
  printf '\n\n\n \n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Eq '^CLAUDE_INSTALLER_EXIT=[1-9][0-9]*$'; then
    printf '[FAIL] %s: installer did not exit with a positive status\n' "$name"
    return 1
  fi
  if ! grep -Fq "cannot inspect agent identity in '$candidate_agent'; its name field is unreadable or malformed." "$session_log"; then
    printf '[FAIL] %s: malformed identity diagnostic did not name the exact candidate path\n' "$name"
    return 1
  fi
  if ! cmp -s "$expected_agent" "$candidate_agent"; then
    printf '[FAIL] %s: candidate bytes changed after identity inspection failed\n' "$name"
    return 1
  fi
  if [[ -e "$canonical_agent" || -L "$canonical_agent" ]]; then
    printf '[FAIL] %s: canonical agent was written despite the malformed identity\n' "$name"
    return 1
  fi
  if [[ -e "$licence_file" || -L "$licence_file" ]]; then
    printf '[FAIL] %s: bundle licence was written despite the malformed identity\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_blocks_a_conflict_with_crlf_agent_frontmatter() {
  local name="claude_installer_blocks_a_conflict_with_crlf_agent_frontmatter"
  local candidate_agent
  local expected_agent
  local canonical_agent
  local licence_file

  create_claude_fixture
  candidate_agent="$home_directory/.claude/agents/team-reviewer.md"
  expected_agent="$fixture_root/expected-team-reviewer.md"
  canonical_agent="$home_directory/.claude/agents/architect-reviewer.md"
  licence_file="$home_directory/.claude/agents.LICENSE"
  mkdir -p "$(dirname "$candidate_agent")"
  /usr/bin/printf '%s\r\n' '---' 'name: architect-reviewer' '---' > "$candidate_agent"
  cp "$candidate_agent" "$expected_agent"
  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  export HOME XDG_CONFIG_HOME
  printf '\n\n\n \n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Eq '^CLAUDE_INSTALLER_EXIT=[1-9][0-9]*$'; then
    printf '[FAIL] %s: installer did not exit with a positive status\n' "$name"
    return 1
  fi
  if ! grep -Fq "competing agent definition at $candidate_agent claims bundled identity architect-reviewer" "$session_log"; then
    printf '[FAIL] %s: conflict diagnostic did not identify the exact candidate path and identity\n' "$name"
    return 1
  fi
  if ! cmp -s "$expected_agent" "$candidate_agent"; then
    printf '[FAIL] %s: candidate bytes changed after the identity conflict\n' "$name"
    return 1
  fi
  if [[ -e "$canonical_agent" || -L "$canonical_agent" ]]; then
    printf '[FAIL] %s: canonical agent was written despite the identity conflict\n' "$name"
    return 1
  fi
  if [[ -e "$licence_file" || -L "$licence_file" ]]; then
    printf '[FAIL] %s: bundle licence was written despite the identity conflict\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_fails_closed_for_an_unterminated_quoted_agent_identity_key() {
  local name="claude_installer_fails_closed_for_an_unterminated_quoted_agent_identity_key"
  local candidate_agent
  local expected_agent
  local canonical_agent
  local licence_file

  create_claude_fixture
  candidate_agent="$fixture_root/project/.claude/agents/team-reviewer.md"
  expected_agent="$fixture_root/expected-team-reviewer.md"
  canonical_agent="$home_directory/.claude/agents/architect-reviewer.md"
  licence_file="$home_directory/.claude/agents.LICENSE"
  mkdir -p "$(dirname "$candidate_agent")"
  cat > "$candidate_agent" <<'EOF'
---
"na\
me": architect-reviewer
description: Project-authored reviewer with an unterminated quoted identity key
---
EOF
  cp "$candidate_agent" "$expected_agent"
  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  export HOME XDG_CONFIG_HOME
  printf '\n\n\n \n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Eq '^CLAUDE_INSTALLER_EXIT=[1-9][0-9]*$'; then
    printf '[FAIL] %s: installer did not exit with a positive status\n' "$name"
    return 1
  fi
  if ! grep -Fq "cannot inspect agent identity in '$candidate_agent'; its name field is unreadable or malformed." "$session_log"; then
    printf '[FAIL] %s: malformed identity diagnostic did not name the exact candidate path\n' "$name"
    return 1
  fi
  if ! cmp -s "$expected_agent" "$candidate_agent"; then
    printf '[FAIL] %s: candidate bytes changed after identity inspection failed\n' "$name"
    return 1
  fi
  if [[ -e "$canonical_agent" || -L "$canonical_agent" ]]; then
    printf '[FAIL] %s: canonical agent was written despite the malformed identity\n' "$name"
    return 1
  fi
  if [[ -e "$licence_file" || -L "$licence_file" ]]; then
    printf '[FAIL] %s: bundle licence was written despite the malformed identity\n' "$name"
    return 1
  fi

  return 0
}

test_claude_installer_fails_closed_for_an_unterminated_single_quoted_agent_identity_key() {
  local name="claude_installer_fails_closed_for_an_unterminated_single_quoted_agent_identity_key"
  local candidate_agent
  local expected_agent
  local canonical_agent
  local licence_file

  create_claude_fixture
  candidate_agent="$fixture_root/project/.claude/agents/team-reviewer.md"
  expected_agent="$fixture_root/expected-team-reviewer.md"
  canonical_agent="$home_directory/.claude/agents/architect-reviewer.md"
  licence_file="$home_directory/.claude/agents.LICENSE"
  mkdir -p "$(dirname "$candidate_agent")"
  cat > "$candidate_agent" <<'EOF'
---
'name: architect-reviewer
description: Project-authored reviewer with an unterminated single-quoted identity key
---

Preserve this project-authored file-backed team reviewer.
EOF
  cp "$candidate_agent" "$expected_agent"
  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  export HOME XDG_CONFIG_HOME
  printf '\n\n\n \n' | /usr/bin/script -q "$session_log" "$fixture_root/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Eq '^CLAUDE_INSTALLER_EXIT=[1-9][0-9]*$'; then
    printf '[FAIL] %s: installer did not exit with a positive status\n' "$name"
    return 1
  fi
  if ! grep -Fq "cannot inspect agent identity in '$candidate_agent'; its name field is unreadable or malformed." "$session_log"; then
    printf '[FAIL] %s: malformed identity diagnostic did not name the exact candidate path\n' "$name"
    return 1
  fi
  if ! cmp -s "$expected_agent" "$candidate_agent"; then
    printf '[FAIL] %s: candidate bytes changed after identity inspection failed\n' "$name"
    return 1
  fi
  if [[ -e "$canonical_agent" || -L "$canonical_agent" ]]; then
    printf '[FAIL] %s: canonical agent was written despite the malformed identity\n' "$name"
    return 1
  fi
  if [[ -e "$licence_file" || -L "$licence_file" ]]; then
    printf '[FAIL] %s: bundle licence was written despite the malformed identity\n' "$name"
    return 1
  fi

  return 0
}

run_case 'Claude installer offers the default-off agent bundle choice' test_claude_installer_offers_the_default_off_agent_bundle_choice
run_case 'Claude installer installs all agents when selected in project scope' test_claude_installer_installs_all_agents_when_selected_in_project_scope
run_case 'Claude installer preserves installed agents when reinstalling with bundle deselected' test_claude_installer_reinstalling_with_bundle_deselected_preserves_installed_agents
run_case 'Claude installer preserves an edited notice when bundle is deselected' test_claude_installer_preserves_an_edited_notice_when_bundle_is_deselected
run_case 'Claude installer rejects a manifest base change before writes' test_claude_installer_rejects_a_manifest_base_change_before_writes
run_case 'Claude installer refuses an unrecognised agent replacement response' test_claude_installer_refuses_an_unrecognised_agent_replacement_response
run_case 'Claude installer refuses an unrecognised notice replacement response' test_claude_installer_refuses_an_unrecognised_notice_replacement_response
run_case 'Claude installer refuses to replace a managed canonical agent' test_claude_installer_refuses_to_replace_a_managed_canonical_agent
run_case 'Claude installer refuses to replace a managed notice' test_claude_installer_refuses_to_replace_a_managed_notice
run_case 'Claude installer allows refusing an exact existing notice without claiming it' test_claude_installer_allows_refusing_an_exact_existing_notice_without_claiming_it
run_case 'Claude installer replaces a mismatched notice when user confirms' test_claude_installer_replaces_a_mismatched_notice_when_user_confirms
run_case 'Claude installer replaces a mismatched notice when user confirms with uppercase Y' test_claude_installer_replaces_a_mismatched_notice_when_user_confirms_with_uppercase_y
run_case 'Claude installer cleans a failed notice stage copy' test_claude_installer_cleans_a_failed_notice_stage_copy
run_case 'Claude installer cleans a failed notice stage comparison' test_claude_installer_cleans_a_failed_notice_stage_comparison
run_case 'Claude installer cleans a failed notice stage rename' test_claude_installer_cleans_a_failed_notice_stage_rename
run_case 'Claude installer blocks a project agent conflict before user bundle writes' test_claude_installer_blocks_a_project_agent_conflict_before_user_bundle_writes
run_case 'Claude installer blocks a conflict with a double-quoted agent identity value' test_claude_installer_blocks_a_conflict_with_a_double_quoted_agent_identity_value
run_case 'Claude installer blocks a conflict with a single-quoted agent identity value' test_claude_installer_blocks_a_conflict_with_a_single_quoted_agent_identity_value
run_case 'Claude installer fails closed for a single-quoted agent identity key' test_claude_installer_fails_closed_for_a_single_quoted_agent_identity_key
run_case 'Claude installer blocks a user agent conflict before project bundle writes' test_claude_installer_blocks_a_user_agent_conflict_before_project_bundle_writes
run_case 'Claude installer blocks a conflict in an explicit project path' test_claude_installer_blocks_a_conflict_in_an_explicit_project_path
run_case 'Claude installer blocks a nested agent identity conflict before bundle writes' test_claude_installer_blocks_a_nested_agent_identity_conflict_before_bundle_writes
run_case 'Claude installer fails closed when a target agent cannot be inspected' test_claude_installer_fails_closed_when_a_target_agent_cannot_be_inspected
run_case 'Claude installer fails closed when agent tree traversal errors' test_claude_installer_fails_closed_when_agent_tree_traversal_errors
run_case 'Claude installer fails closed when an agent root cannot be enumerated' test_claude_installer_fails_closed_when_an_agent_root_cannot_be_enumerated
run_case 'Claude installer fails closed when agent identity inspection errors' test_claude_installer_fails_closed_when_agent_identity_inspection_errors
run_case 'Claude installer rejects a directory at a canonical agent path' test_claude_installer_rejects_a_directory_at_a_canonical_agent_path
run_case 'Claude installer rejects a directory at the notice path' test_claude_installer_rejects_a_directory_at_the_notice_path
run_case 'Claude installer reports prior changes when agent directory creation fails' test_claude_installer_reports_prior_changes_when_agent_directory_creation_fails
run_case 'Claude installer replaces a canonical agent when user confirms' test_claude_installer_replaces_a_canonical_agent_when_user_confirms
run_case 'Claude installer replaces a canonical agent when user confirms with uppercase Y' test_claude_installer_replaces_a_canonical_agent_when_user_confirms_with_uppercase_y
run_case 'Claude installer reports partial agent copy failure with prior changes' test_claude_installer_reports_partial_agent_copy_failure_with_prior_changes
run_case 'Claude installer reports manifest write failure with all bundle changes' test_claude_installer_reports_manifest_write_failure_with_all_bundle_changes
run_case 'Claude installer reports stale prune failure with all bundle changes' test_claude_installer_reports_stale_prune_failure_with_all_bundle_changes
run_case 'Claude installer fails closed for a block scalar agent identity' test_claude_installer_fails_closed_for_a_block_scalar_agent_identity
run_case 'Claude installer fails closed for a quoted agent identity key' test_claude_installer_fails_closed_for_a_quoted_agent_identity_key
run_case 'Claude installer fails closed for a symlinked agent root' test_claude_installer_fails_closed_for_a_symlinked_agent_root
run_case 'Claude installer fails closed for a symlinked markdown candidate' test_claude_installer_fails_closed_for_a_symlinked_markdown_candidate
run_case 'Claude installer fails closed for a symlinked nested agent directory' test_claude_installer_fails_closed_for_a_symlinked_nested_agent_directory
run_case 'Claude installer ignores a non-Markdown agent symlink' test_claude_installer_ignores_a_non_markdown_agent_symlink
run_case 'Claude installer fails closed for an indented quoted agent identity key' test_claude_installer_fails_closed_for_an_indented_quoted_agent_identity_key
run_case 'Claude installer fails closed for an indented block scalar agent identity' test_claude_installer_fails_closed_for_an_indented_block_scalar_agent_identity
run_case 'Agent bundle notice rejects a mismatched notice at EOF without changing it' test_agent_bundle_notice_rejects_a_mismatched_notice_at_eof_without_changing_it
run_case 'Agent bundle notice preserves an identical notice at EOF without claiming it' test_agent_bundle_notice_preserves_an_identical_notice_at_eof_without_claiming_it
run_case 'Agent bundle files preserves an unmanaged agent at EOF without claiming it' test_agent_bundle_files_preserves_an_unmanaged_agent_at_eof_without_claiming_it
run_case 'Agent bundle helper prompts before refusing a dangling canonical agent symlink' test_agent_bundle_helper_prompts_before_refusing_a_dangling_canonical_agent_symlink
run_case 'Agent bundle helper replaces a dangling canonical agent symlink after consent' test_agent_bundle_helper_replaces_a_dangling_canonical_agent_symlink_after_consent
run_case 'Claude installer fails closed for a double-quoted escaped agent identity value' test_claude_installer_fails_closed_for_a_double_quoted_escaped_agent_identity_value
run_case 'Claude installer blocks a conflict with whitespace before name separator' test_claude_installer_blocks_a_conflict_with_whitespace_before_name_separator
run_case 'Claude installer fails closed for a tagged agent identity value' test_claude_installer_fails_closed_for_a_tagged_agent_identity_value
run_case 'Claude installer fails closed for an anchored agent identity value' test_claude_installer_fails_closed_for_an_anchored_agent_identity_value
run_case 'Claude installer fails closed for a flow mapping agent identity' test_claude_installer_fails_closed_for_a_flow_mapping_agent_identity
run_case 'Claude installer fails closed for an anchored root flow mapping agent identity' test_claude_installer_fails_closed_for_an_anchored_root_flow_mapping_agent_identity
run_case 'Claude installer fails closed for a tagged root flow mapping agent identity' test_claude_installer_fails_closed_for_a_tagged_root_flow_mapping_agent_identity
run_case 'Claude installer fails closed for an escaped quoted agent identity key' test_claude_installer_fails_closed_for_an_escaped_quoted_agent_identity_key
run_case 'Claude installer fails closed for an explicit agent identity key' test_claude_installer_fails_closed_for_an_explicit_agent_identity_key
run_case 'Claude installer fails closed for a plain YAML merge key agent identity' test_claude_installer_fails_closed_for_a_plain_yaml_merge_key_agent_identity
run_case 'Claude installer fails closed for a double-quoted YAML merge key agent identity' test_claude_installer_fails_closed_for_a_double_quoted_yaml_merge_key_agent_identity
run_case 'Claude installer fails closed for a single-quoted YAML merge key agent identity' test_claude_installer_fails_closed_for_a_single_quoted_yaml_merge_key_agent_identity
run_case 'Claude installer blocks a conflict with CRLF agent frontmatter' test_claude_installer_blocks_a_conflict_with_crlf_agent_frontmatter
run_case 'Claude installer fails closed for an indented agent identity after the document end marker' test_claude_installer_fails_closed_for_an_indented_agent_identity_after_document_end_marker
run_case 'Claude installer fails closed when a project agent root has an inaccessible ancestor' test_claude_installer_fails_closed_when_project_agent_root_has_an_inaccessible_ancestor
run_case 'Claude installer fails closed for an unterminated quoted agent identity key' test_claude_installer_fails_closed_for_an_unterminated_quoted_agent_identity_key
run_case 'Claude installer fails closed for an unterminated single-quoted agent identity key' test_claude_installer_fails_closed_for_an_unterminated_single_quoted_agent_identity_key

printf 'Tests: %d passed, %d failed\n' "$passed" "$failed"
[[ "$failed" -eq 0 ]]
