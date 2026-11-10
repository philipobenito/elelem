#!/usr/bin/env bash
set -uo pipefail

if [[ -z "${ELELEM_TEST_ROOT:-}" || ! -d "$ELELEM_TEST_ROOT" ]]; then
  printf 'ELELEM_TEST_ROOT must name an existing fixture directory\n' >&2
  exit 2
fi

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

test_opencode_installer_offers_the_default_off_agent_bundle_choice() {
  local name="opencode_installer_offers_the_default_off_agent_bundle_choice"
  local fixture_root
  local invocation_directory
  local project_directory
  local home_directory
  local xdg_directory
  local temporary_directory
  local session_log

  fixture_root="$(mktemp -d "$ELELEM_TEST_ROOT/opencode-agent-bundle.XXXXXX")"
  invocation_directory="$fixture_root/invocation"
  project_directory="$fixture_root/project"
  home_directory="$fixture_root/home"
  xdg_directory="$fixture_root/xdg"
  temporary_directory="$fixture_root/tmp"
  session_log="$fixture_root/session.log"

  mkdir -p "$invocation_directory" "$project_directory" "$home_directory" "$xdg_directory" "$temporary_directory"
  ln -s "$repository_root/install-opencode.sh" "$invocation_directory/install-opencode.sh"
  ln -s "$repository_root/_install-common.sh" "$invocation_directory/_install-common.sh"
  cp -R "$repository_root/rules" "$invocation_directory/rules"
  cp -R "$repository_root/skills" "$invocation_directory/skills"
  cp -R "$repository_root/agents" "$invocation_directory/agents"

  cat > "$temporary_directory/run-installer.sh" <<'EOF'
#!/usr/bin/env bash
fixture_directory="$(cd "$(dirname "$0")/.." && pwd)"
cd "$fixture_directory/project" || exit 1
"$fixture_directory/invocation/install-opencode.sh"
installer_status=$?
printf '\nOPENCODE_INSTALLER_EXIT=%s\n' "$installer_status"
exit "$installer_status"
EOF
  chmod +x "$temporary_directory/run-installer.sh"

  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  TMPDIR="$temporary_directory"
  export HOME XDG_CONFIG_HOME TMPDIR
  printf '\033[B\n\n\n\n\n' | /usr/bin/script -q "$session_log" "$temporary_directory/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Fqx 'OPENCODE_INSTALLER_EXIT=0'; then
    printf '[FAIL] %s: installer did not exit with status 0\n' "$name"
    return 1
  fi

  if ! grep -Fq 'Elelem agent bundle (11 agents)' "$session_log"; then
    printf '[FAIL] %s: optional agent bundle menu choice was not displayed\n' "$name"
    return 1
  fi

  if [[ -e "$home_directory/.config/opencode/agents" || -L "$home_directory/.config/opencode/agents" || -e "$home_directory/.config/opencode/agents.LICENSE" || -L "$home_directory/.config/opencode/agents.LICENSE" ]]; then
    printf '[FAIL] %s: accepting the default-off choice installed bundle files\n' "$name"
    return 1
  fi

  return 0
}

test_opencode_installer_installs_the_complete_agent_bundle_at_the_selected_scope() {
  local name="opencode_installer_installs_the_complete_agent_bundle_at_the_selected_scope"
  local fixture_parent="$ELELEM_TEST_ROOT"
  local scope
  local fixture_root
  local invocation_directory
  local project_directory
  local home_directory
  local xdg_directory
  local temporary_directory
  local session_log
  local base_directory
  local agents_directory
  local manifest_file
  local markdown_count
  local source_file
  local filename
  local manifest_base
  local test_status=0

  mkdir -p "$fixture_parent"

  for scope in user project; do
    fixture_root="$(mktemp -d "$fixture_parent/$scope.XXXXXX")"
    invocation_directory="$fixture_root/invocation"
    project_directory="$fixture_root/project"
    home_directory="$fixture_root/home"
    xdg_directory="$fixture_root/xdg"
    temporary_directory="$fixture_root/tmp"
    session_log="$fixture_root/session.log"

    mkdir -p "$invocation_directory" "$project_directory" "$home_directory" "$xdg_directory" "$temporary_directory"
    ln -s "$repository_root/install-opencode.sh" "$invocation_directory/install-opencode.sh"
    ln -s "$repository_root/_install-common.sh" "$invocation_directory/_install-common.sh"
    cp -R "$repository_root/rules" "$invocation_directory/rules"
    cp -R "$repository_root/skills" "$invocation_directory/skills"
    cp -R "$repository_root/agents" "$invocation_directory/agents"

    cat > "$temporary_directory/run-installer.sh" <<'EOF'
#!/usr/bin/env bash
fixture_directory="$(cd "$(dirname "$0")/.." && pwd)"
cd "$fixture_directory/project" || exit 1
"$fixture_directory/invocation/install-opencode.sh"
installer_status=$?
printf '\nOPENCODE_INSTALLER_EXIT=%s\n' "$installer_status"
exit "$installer_status"
EOF
    chmod +x "$temporary_directory/run-installer.sh"

    HOME="$home_directory"
    XDG_CONFIG_HOME="$xdg_directory"
    TMPDIR="$temporary_directory"
    export HOME XDG_CONFIG_HOME TMPDIR

    if [[ "$scope" == user ]]; then
      printf '\033[B\n\n\n\n \n' | /usr/bin/script -q "$session_log" "$temporary_directory/run-installer.sh" >/dev/null
      base_directory="$home_directory/.config/opencode"
    else
      printf '\033[A\n%s\n\n\n\n \n' "$project_directory" | /usr/bin/script -q "$session_log" "$temporary_directory/run-installer.sh" >/dev/null
      base_directory="$project_directory/.opencode"
    fi

    agents_directory="$base_directory/agents"
    manifest_file="$invocation_directory/.elelem-manifest-opencode"

    if ! sed 's/\r$//' "$session_log" | grep -Fqx 'OPENCODE_INSTALLER_EXIT=0'; then
      printf '[FAIL] %s: %s-scope installer did not exit with status 0\n' "$name" "$scope"
      test_status=1
    fi

    if [[ ! -d "$agents_directory" ]]; then
      printf '[FAIL] %s: %s-scope agent directory was not installed\n' "$name" "$scope"
      test_status=1
    else
      markdown_count="$(find "$agents_directory" -type f -name '*.md' | wc -l | tr -d '[:space:]')"
      if [[ "$markdown_count" != 11 ]]; then
        printf '[FAIL] %s: %s-scope agent directory contains %s Markdown files, expected 11\n' "$name" "$scope" "$markdown_count"
        test_status=1
      fi

      for source_file in "$invocation_directory/agents/opencode/"*.md; do
        filename="$(basename "$source_file")"
        if ! cmp -s "$source_file" "$agents_directory/$filename"; then
          printf '[FAIL] %s: %s-scope agent %s is missing or differs from its source\n' "$name" "$scope" "$filename"
          test_status=1
        fi
      done
    fi

    if ! cmp -s "$invocation_directory/agents/LICENSE" "$base_directory/agents.LICENSE"; then
      printf '[FAIL] %s: %s-scope agent notice is missing or differs from its source\n' "$name" "$scope"
      test_status=1
    fi

    if [[ ! -f "$manifest_file" ]]; then
      printf '[FAIL] %s: %s-scope manifest was not written\n' "$name" "$scope"
      test_status=1
    else
      manifest_base=""
      IFS= read -r manifest_base < "$manifest_file" || true
      if [[ "$manifest_base" != "$base_directory" ]]; then
        printf '[FAIL] %s: %s-scope manifest records base %s, expected %s\n' "$name" "$scope" "$manifest_base" "$base_directory"
        test_status=1
      fi

      for source_file in "$invocation_directory/agents/opencode/"*.md; do
        filename="$(basename "$source_file")"
        if ! grep -Fqx "agents/$filename" "$manifest_file"; then
          printf '[FAIL] %s: %s-scope manifest omits agents/%s\n' "$name" "$scope" "$filename"
          test_status=1
        fi
      done
      if ! grep -Fqx 'agents.LICENSE' "$manifest_file"; then
        printf '[FAIL] %s: %s-scope manifest omits agents.LICENSE\n' "$name" "$scope"
        test_status=1
      fi
    fi

    if [[ "$scope" == user && ( -e "$xdg_directory/opencode/agents" || -L "$xdg_directory/opencode/agents" || -e "$xdg_directory/opencode/agents.LICENSE" || -L "$xdg_directory/opencode/agents.LICENSE" ) ]]; then
      printf '[FAIL] %s: user-scope agent files were installed under XDG_CONFIG_HOME\n' "$name"
      test_status=1
    fi
  done

  return "$test_status"
}

test_opencode_installer_preserves_tracked_agents_when_bundle_is_deselected() {
  local name="opencode_installer_preserves_tracked_agents_when_bundle_is_deselected"
  local fixture_root
  local invocation_directory
  local project_directory
  local home_directory
  local xdg_directory
  local temporary_directory
  local selected_session_log
  local deselected_session_log
  local agents_directory
  local manifest_file
  local expected_agent
  local expected_notice
  local markdown_count
  local source_file
  local filename
  local test_status=0

  fixture_root="$(mktemp -d "$ELELEM_TEST_ROOT/opencode-agent-bundle-reinstall.XXXXXX")"
  invocation_directory="$fixture_root/invocation"
  project_directory="$fixture_root/project"
  home_directory="$fixture_root/home"
  xdg_directory="$fixture_root/xdg"
  temporary_directory="$fixture_root/tmp"
  selected_session_log="$fixture_root/selected-session.log"
  deselected_session_log="$fixture_root/deselected-session.log"
  agents_directory="$home_directory/.config/opencode/agents"
  manifest_file="$invocation_directory/.elelem-manifest-opencode"
  expected_agent="$temporary_directory/expected-architect-reviewer.md"
  expected_notice="$temporary_directory/expected-agents.LICENSE"

  mkdir -p "$invocation_directory" "$project_directory" "$home_directory" "$xdg_directory" "$temporary_directory"
  ln -s "$repository_root/install-opencode.sh" "$invocation_directory/install-opencode.sh"
  ln -s "$repository_root/_install-common.sh" "$invocation_directory/_install-common.sh"
  cp -R "$repository_root/rules" "$invocation_directory/rules"
  cp -R "$repository_root/skills" "$invocation_directory/skills"
  cp -R "$repository_root/agents" "$invocation_directory/agents"

  cat > "$temporary_directory/run-installer.sh" <<'EOF'
#!/usr/bin/env bash
fixture_directory="$(cd "$(dirname "$0")/.." && pwd)"
cd "$fixture_directory/project" || exit 1
"$fixture_directory/invocation/install-opencode.sh"
installer_status=$?
printf '\nOPENCODE_INSTALLER_EXIT=%s\n' "$installer_status"
exit "$installer_status"
EOF
  chmod +x "$temporary_directory/run-installer.sh"

  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  TMPDIR="$temporary_directory"
  export HOME XDG_CONFIG_HOME TMPDIR

  printf '\033[B\n\n\n\n \n' | /usr/bin/script -q "$selected_session_log" "$temporary_directory/run-installer.sh" >/dev/null
  if ! sed 's/\r$//' "$selected_session_log" | grep -Fqx 'OPENCODE_INSTALLER_EXIT=0'; then
    printf '[FAIL] %s: bundle-selected installer did not exit with status 0\n' "$name"
    test_status=1
  else
    printf 'User-edited canonical agent bytes.\n' > "$agents_directory/architect-reviewer.md"
    printf 'User-edited bundle notice bytes.\n' > "$home_directory/.config/opencode/agents.LICENSE"
    cp "$agents_directory/architect-reviewer.md" "$expected_agent"
    cp "$home_directory/.config/opencode/agents.LICENSE" "$expected_notice"
  fi

  printf '\033[B\n\n\n\n\n' | /usr/bin/script -q "$deselected_session_log" "$temporary_directory/run-installer.sh" >/dev/null
  if ! sed 's/\r$//' "$deselected_session_log" | grep -Fqx 'OPENCODE_INSTALLER_EXIT=0'; then
    printf '[FAIL] %s: bundle-deselected installer did not exit with status 0\n' "$name"
    test_status=1
  fi

  if [[ ! -d "$agents_directory" ]]; then
    printf '[FAIL] %s: tracked agent directory was removed after bundle deselection\n' "$name"
    test_status=1
  else
    markdown_count="$(find "$agents_directory" -type f -name '*.md' | wc -l | tr -d '[:space:]')"
    if [[ "$markdown_count" != 11 ]]; then
      printf '[FAIL] %s: tracked agent directory contains %s Markdown files after bundle deselection, expected 11\n' "$name" "$markdown_count"
      test_status=1
    fi

    for source_file in "$invocation_directory/agents/opencode/"*.md; do
      filename="$(basename "$source_file")"
      if [[ "$filename" == architect-reviewer.md ]]; then
        continue
      fi
      if ! cmp -s "$source_file" "$agents_directory/$filename"; then
        printf '[FAIL] %s: tracked agent %s is missing or differs from its source after bundle deselection\n' "$name" "$filename"
        test_status=1
      fi
    done
  fi

  if ! cmp -s "$expected_agent" "$agents_directory/architect-reviewer.md"; then
    printf '[FAIL] %s: tracked canonical agent user edits were not preserved after bundle deselection\n' "$name"
    test_status=1
  fi

  if ! cmp -s "$expected_notice" "$home_directory/.config/opencode/agents.LICENSE"; then
    printf '[FAIL] %s: tracked notice user edits were not preserved after bundle deselection\n' "$name"
    test_status=1
  fi

  for source_file in "$invocation_directory/agents/opencode/"*.md; do
    filename="$(basename "$source_file")"
    if ! grep -Fqx "agents/$filename" "$manifest_file"; then
      printf '[FAIL] %s: manifest omits tracked agents/%s after bundle deselection\n' "$name" "$filename"
      test_status=1
    fi
  done
  if ! grep -Fqx 'agents.LICENSE' "$manifest_file"; then
    printf '[FAIL] %s: manifest omits tracked agents.LICENSE after bundle deselection\n' "$name"
    test_status=1
  fi

  return "$test_status"
}

test_opencode_installer_rejects_a_manifest_base_change_before_writes() {
  local name="opencode_installer_rejects_a_manifest_base_change_before_writes"
  local fixture_root
  local invocation_directory
  local project_directory
  local home_directory
  local xdg_directory
  local temporary_directory
  local session_log
  local manifest_file
  local expected_manifest
  local test_status=0

  fixture_root="$(mktemp -d "$ELELEM_TEST_ROOT/manifest-base-change.XXXXXX")"
  invocation_directory="$fixture_root/invocation"
  project_directory="$fixture_root/project"
  home_directory="$fixture_root/home"
  xdg_directory="$fixture_root/xdg"
  temporary_directory="$fixture_root/tmp"
  session_log="$fixture_root/session.log"
  manifest_file="$invocation_directory/.elelem-manifest-opencode"
  expected_manifest="$temporary_directory/expected-manifest"

  mkdir -p "$invocation_directory" "$project_directory" "$home_directory" "$xdg_directory" "$temporary_directory"
  ln -s "$repository_root/install-opencode.sh" "$invocation_directory/install-opencode.sh"
  ln -s "$repository_root/_install-common.sh" "$invocation_directory/_install-common.sh"
  cp -R "$repository_root/rules" "$invocation_directory/rules"
  cp -R "$repository_root/skills" "$invocation_directory/skills"
  cp -R "$repository_root/agents" "$invocation_directory/agents"

  cat > "$temporary_directory/run-installer.sh" <<'EOF'
#!/usr/bin/env bash
fixture_directory="$(cd "$(dirname "$0")/.." && pwd)"
cd "$fixture_directory/project" || exit 1
"$fixture_directory/invocation/install-opencode.sh"
installer_status=$?
printf '\nOPENCODE_INSTALLER_EXIT=%s\n' "$installer_status"
exit "$installer_status"
EOF
  chmod +x "$temporary_directory/run-installer.sh"

  printf '%s\npreserved-sentinel\n' "$home_directory/.config/opencode" > "$manifest_file"
  cp "$manifest_file" "$expected_manifest"

  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  TMPDIR="$temporary_directory"
  export HOME XDG_CONFIG_HOME TMPDIR
  printf '\033[A\n%s\n\n\n\n \n' "$project_directory" | /usr/bin/script -q "$session_log" "$temporary_directory/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Eq '^OPENCODE_INSTALLER_EXIT=[1-9][0-9]*$'; then
    printf '[FAIL] %s: installer did not exit with a non-zero status\n' "$name"
    test_status=1
  fi

  if ! grep -Fq 'refusing to change install scope' "$session_log"; then
    printf '[FAIL] %s: install-scope refusal diagnostic was not displayed\n' "$name"
    test_status=1
  fi

  if ! cmp -s "$expected_manifest" "$manifest_file"; then
    printf '[FAIL] %s: manifest changed after rejecting the selected scope\n' "$name"
    test_status=1
  fi

  if [[ -e "$project_directory/.opencode" || -L "$project_directory/.opencode" ]]; then
    printf '[FAIL] %s: project-scope target was created before rejecting the selected scope\n' "$name"
    test_status=1
  fi

  return "$test_status"
}

test_opencode_installer_blocks_a_current_project_markdown_agent_conflict_before_bundle_writes() {
  local name="opencode_installer_blocks_a_current_project_markdown_agent_conflict_before_bundle_writes"
  local fixture_root
  local invocation_directory
  local project_directory
  local home_directory
  local xdg_directory
  local temporary_directory
  local session_log
  local project_agent
  local expected_project_agent
  local user_agent
  local user_agent_notice
  local test_status=0

  fixture_root="$(mktemp -d "$ELELEM_TEST_ROOT/current-project-agent-conflict.XXXXXX")"
  invocation_directory="$fixture_root/invocation"
  project_directory="$fixture_root/project"
  home_directory="$fixture_root/home"
  xdg_directory="$fixture_root/xdg"
  temporary_directory="$fixture_root/tmp"
  session_log="$fixture_root/session.log"
  project_agent="$project_directory/.opencode/agents/architect-reviewer.md"
  expected_project_agent="$temporary_directory/expected-project-agent.md"
  user_agent="$home_directory/.config/opencode/agents/architect-reviewer.md"
  user_agent_notice="$home_directory/.config/opencode/agents.LICENSE"

  mkdir -p "$invocation_directory" "$project_directory/.opencode/agents" "$home_directory" "$xdg_directory" "$temporary_directory"
  ln -s "$repository_root/install-opencode.sh" "$invocation_directory/install-opencode.sh"
  ln -s "$repository_root/_install-common.sh" "$invocation_directory/_install-common.sh"
  cp -R "$repository_root/rules" "$invocation_directory/rules"
  cp -R "$repository_root/skills" "$invocation_directory/skills"
  cp -R "$repository_root/agents" "$invocation_directory/agents"

  cat > "$project_agent" <<'EOF'
---
description: Reviews project architecture
mode: subagent
---

Review the project architecture and report concrete findings.
EOF
  cp "$project_agent" "$expected_project_agent"

  cat > "$temporary_directory/run-installer.sh" <<'EOF'
#!/usr/bin/env bash
fixture_directory="$(cd "$(dirname "$0")/.." && pwd)"
cd "$fixture_directory/project" || exit 1
"$fixture_directory/invocation/install-opencode.sh"
installer_status=$?
printf '\nOPENCODE_INSTALLER_EXIT=%s\n' "$installer_status"
exit "$installer_status"
EOF
  chmod +x "$temporary_directory/run-installer.sh"

  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  TMPDIR="$temporary_directory"
  export HOME XDG_CONFIG_HOME TMPDIR
  printf '\033[B\n\n\n\n \n' | /usr/bin/script -q "$session_log" "$temporary_directory/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Eq '^OPENCODE_INSTALLER_EXIT=[1-9][0-9]*$'; then
    printf '[FAIL] %s: installer did not exit with a non-zero status\n' "$name"
    test_status=1
  fi

  if ! grep -Fq 'architect-reviewer' "$session_log"; then
    printf '[FAIL] %s: conflict diagnostic did not identify architect-reviewer\n' "$name"
    test_status=1
  fi

  if ! cmp -s "$expected_project_agent" "$project_agent"; then
    printf '[FAIL] %s: project agent changed after conflict preflight\n' "$name"
    test_status=1
  fi

  if [[ -e "$user_agent" || -L "$user_agent" || -e "$user_agent_notice" || -L "$user_agent_notice" ]]; then
    printf '[FAIL] %s: user-scope bundle files were written despite the project conflict\n' "$name"
    test_status=1
  fi

  return "$test_status"
}

test_opencode_installer_blocks_a_user_markdown_agent_conflict_before_project_bundle_writes() {
  local name="opencode_installer_blocks_a_user_markdown_agent_conflict_before_project_bundle_writes"
  local fixture_root
  local invocation_directory
  local project_directory
  local home_directory
  local xdg_directory
  local temporary_directory
  local session_log
  local user_agent
  local expected_user_agent
  local project_agent
  local project_notice
  local test_status=0

  fixture_root="$(mktemp -d "$ELELEM_TEST_ROOT/user-agent-conflict-project-scope.XXXXXX")"
  invocation_directory="$fixture_root/invocation"
  project_directory="$fixture_root/project"
  home_directory="$fixture_root/home"
  xdg_directory="$fixture_root/xdg"
  temporary_directory="$fixture_root/tmp"
  session_log="$fixture_root/session.log"
  user_agent="$home_directory/.config/opencode/agents/architect-reviewer.md"
  expected_user_agent="$temporary_directory/expected-architect-reviewer.md"
  project_agent="$project_directory/.opencode/agents/architect-reviewer.md"
  project_notice="$project_directory/.opencode/agents.LICENSE"

  mkdir -p "$invocation_directory" "$project_directory" "$(dirname "$user_agent")" "$xdg_directory" "$temporary_directory"
  ln -s "$repository_root/install-opencode.sh" "$invocation_directory/install-opencode.sh"
  ln -s "$repository_root/_install-common.sh" "$invocation_directory/_install-common.sh"
  cp -R "$repository_root/rules" "$invocation_directory/rules"
  cp -R "$repository_root/skills" "$invocation_directory/skills"
  cp -R "$repository_root/agents" "$invocation_directory/agents"

  cat > "$user_agent" <<'EOF'
---
description: User-scoped architecture reviewer
mode: subagent
---

Preserve this user-scoped agent when project installation conflicts.
EOF
  cp "$user_agent" "$expected_user_agent"

  cat > "$temporary_directory/run-installer.sh" <<'EOF'
#!/usr/bin/env bash
fixture_directory="$(cd "$(dirname "$0")/.." && pwd)"
cd "$fixture_directory/project" || exit 1
"$fixture_directory/invocation/install-opencode.sh"
installer_status=$?
printf '\nOPENCODE_INSTALLER_EXIT=%s\n' "$installer_status"
exit "$installer_status"
EOF
  chmod +x "$temporary_directory/run-installer.sh"

  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  TMPDIR="$temporary_directory"
  export HOME XDG_CONFIG_HOME TMPDIR
  printf '\033[A\n%s\n\n\n\n \n' "$project_directory" | /usr/bin/script -q "$session_log" "$temporary_directory/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Eq '^OPENCODE_INSTALLER_EXIT=[1-9][0-9]*$'; then
    printf '[FAIL] %s: installer did not exit with a positive status\n' "$name"
    test_status=1
  fi
  if ! grep -Fq 'agent ID' "$session_log" || ! grep -Fq 'architect-reviewer' "$session_log" || ! grep -Fq "$user_agent" "$session_log"; then
    printf '[FAIL] %s: user agent conflict diagnostic did not identify architect-reviewer and its path\n' "$name"
    test_status=1
  fi
  if ! cmp -s "$expected_user_agent" "$user_agent"; then
    printf '[FAIL] %s: user-scoped conflicting agent changed before project bundle installation\n' "$name"
    test_status=1
  fi
  if [[ -e "$project_agent" || -L "$project_agent" || -e "$project_notice" || -L "$project_notice" ]]; then
    printf '[FAIL] %s: project-scope bundle files were written despite the user conflict\n' "$name"
    test_status=1
  fi

  return "$test_status"
}

test_opencode_installer_blocks_json_agent_declarations_before_bundle_writes() {
  local name="opencode_installer_blocks_json_agent_declarations_before_bundle_writes"
  local fixture_root
  local scope
  local invocation_directory
  local project_directory
  local home_directory
  local xdg_directory
  local temporary_directory
  local session_log
  local config_file
  local expected_config
  local selected_base
  local test_status=0

  for scope in user project; do
    fixture_root="$(mktemp -d "$ELELEM_TEST_ROOT/json-agent-conflict-$scope.XXXXXX")"
    invocation_directory="$fixture_root/invocation"
    project_directory="$fixture_root/project"
    home_directory="$fixture_root/home"
    xdg_directory="$fixture_root/xdg"
    temporary_directory="$fixture_root/tmp"
    session_log="$fixture_root/session.log"

    mkdir -p "$invocation_directory" "$project_directory" "$home_directory" "$xdg_directory" "$temporary_directory"
    ln -s "$repository_root/install-opencode.sh" "$invocation_directory/install-opencode.sh"
    ln -s "$repository_root/_install-common.sh" "$invocation_directory/_install-common.sh"
    cp -R "$repository_root/rules" "$invocation_directory/rules"
    cp -R "$repository_root/skills" "$invocation_directory/skills"
    cp -R "$repository_root/agents" "$invocation_directory/agents"

    if [[ "$scope" == user ]]; then
      config_file="$project_directory/.opencode/opencode.json"
      selected_base="$home_directory/.config/opencode"
    else
      config_file="$home_directory/.config/opencode/opencode.json"
      selected_base="$project_directory/.opencode"
    fi
    expected_config="$temporary_directory/expected-opencode.json"
    mkdir -p "$(dirname "$config_file")"
    cat > "$config_file" <<'EOF'
{
  "agent": {
    "architect-reviewer": {
      "description": "Reviews project architecture",
      "mode": "subagent",
      "prompt": "Review the project architecture and report concrete findings."
    },
    "documentation-helper": {
      "description": "Updates project documentation",
      "mode": "subagent",
      "prompt": "Update documentation for the requested change."
    }
  }
}
EOF
    cp "$config_file" "$expected_config"

    cat > "$temporary_directory/run-installer.sh" <<'EOF'
#!/usr/bin/env bash
fixture_directory="$(cd "$(dirname "$0")/.." && pwd)"
cd "$fixture_directory/project" || exit 1
"$fixture_directory/invocation/install-opencode.sh"
installer_status=$?
printf '\nOPENCODE_INSTALLER_EXIT=%s\n' "$installer_status"
exit "$installer_status"
EOF
    chmod +x "$temporary_directory/run-installer.sh"

    HOME="$home_directory"
    XDG_CONFIG_HOME="$xdg_directory"
    TMPDIR="$temporary_directory"
    export HOME XDG_CONFIG_HOME TMPDIR
    if [[ "$scope" == user ]]; then
      printf '\033[B\n\n\n\n \n' | /usr/bin/script -q "$session_log" "$temporary_directory/run-installer.sh" >/dev/null
    else
      printf '\033[A\n%s\n\n\n\n \n' "$project_directory" | /usr/bin/script -q "$session_log" "$temporary_directory/run-installer.sh" >/dev/null
    fi

    if ! sed 's/\r$//' "$session_log" | grep -Eq '^OPENCODE_INSTALLER_EXIT=[1-9][0-9]*$'; then
      printf '[FAIL] %s: %s-scope installer did not exit with a non-zero status\n' "$name" "$scope"
      test_status=1
    fi

    if ! grep -Fq 'architect-reviewer' "$session_log"; then
      printf '[FAIL] %s: %s-scope conflict diagnostic did not identify architect-reviewer\n' "$name" "$scope"
      test_status=1
    fi

    if ! cmp -s "$expected_config" "$config_file"; then
      printf '[FAIL] %s: %s-scope JSON config changed after conflict preflight\n' "$name" "$scope"
      test_status=1
    fi

    if [[ -e "$selected_base/agents/architect-reviewer.md" || -L "$selected_base/agents/architect-reviewer.md" || -e "$selected_base/agents.LICENSE" || -L "$selected_base/agents.LICENSE" ]]; then
      printf '[FAIL] %s: %s-scope bundle files were written despite the JSON conflict\n' "$name" "$scope"
      test_status=1
    fi
  done

  return "$test_status"
}

test_opencode_installer_fails_closed_when_a_json_identity_query_cannot_be_completed() {
  local name="opencode_installer_fails_closed_when_a_json_identity_query_cannot_be_completed"
  local fixture_root invocation_directory project_directory home_directory xdg_directory temporary_directory bin_directory
  local config_file session_log test_status=0

  fixture_root="$(mktemp -d "$ELELEM_TEST_ROOT/json-identity-query-failure.XXXXXX")"
  invocation_directory="$fixture_root/invocation"
  project_directory="$fixture_root/project"
  home_directory="$fixture_root/home"
  xdg_directory="$fixture_root/xdg"
  temporary_directory="$fixture_root/tmp"
  bin_directory="$fixture_root/bin"
  config_file="$project_directory/.opencode/opencode.json"
  session_log="$fixture_root/session.log"
  mkdir -p "$invocation_directory" "$project_directory/.opencode" "$home_directory" "$xdg_directory" "$temporary_directory" "$bin_directory"
  ln -s "$repository_root/install-opencode.sh" "$invocation_directory/install-opencode.sh"
  ln -s "$repository_root/_install-common.sh" "$invocation_directory/_install-common.sh"
  cp -R "$repository_root/rules" "$invocation_directory/rules"
  cp -R "$repository_root/skills" "$invocation_directory/skills"
  cp -R "$repository_root/agents" "$invocation_directory/agents"
  printf '{ "agent": { "architect-reviewer": { "description": "Existing agent" } } }\n' > "$config_file"
  cp "$config_file" "$temporary_directory/expected-opencode.json"

  cat > "$bin_directory/jq" <<'EOF'
#!/usr/bin/env bash
fixture_directory="$(cd "$(dirname "$0")/.." && pwd)"
printf 'call %s\n' "$*" >> "$fixture_directory/jq.log"
if [[ "$1" == -se ]]; then
  /usr/bin/jq "$@"
  status=$?
  printf 'validation status=%s\n' "$status" >> "$fixture_directory/jq.log"
  if [[ "$status" == 0 ]]; then
    touch "$fixture_directory/validation-succeeded"
  fi
  exit "$status"
fi
if [[ "$1" == -e && -f "$fixture_directory/validation-succeeded" && ! -e "$fixture_directory/identity-query-failed" ]]; then
  touch "$fixture_directory/identity-query-failed"
  printf 'identity status=2\n' >> "$fixture_directory/jq.log"
  exit 2
fi
exec /usr/bin/jq "$@"
EOF
  cat > "$temporary_directory/run-installer.sh" <<'EOF'
#!/usr/bin/env bash
fixture_directory="$(cd "$(dirname "$0")/.." && pwd)"
if [[ "$HOME" != "$fixture_directory/home" || "$XDG_CONFIG_HOME" != "$fixture_directory/xdg" || "$TMPDIR" != "$fixture_directory/tmp" ]]; then
  printf 'Fixture environment is not isolated\n'
  exit 2
fi
cd "$fixture_directory/project" || exit 1
"$fixture_directory/invocation/install-opencode.sh"
installer_status=$?
printf '\nOPENCODE_INSTALLER_EXIT=%s\n' "$installer_status"
exit "$installer_status"
EOF
  chmod +x "$bin_directory/jq" "$temporary_directory/run-installer.sh"
  printf '\033[B\n\n\n\n \n' | HOME="$home_directory" XDG_CONFIG_HOME="$xdg_directory" TMPDIR="$temporary_directory" PATH="$bin_directory:$PATH" /usr/bin/script -q "$session_log" "$temporary_directory/run-installer.sh" >/dev/null

  if [[ ! -f "$fixture_root/identity-query-failed" ]] || ! awk '/^validation status=0$/ { validated=1 } /^identity status=2$/ { if (validated) failed++; else exit 1 } END { exit failed == 1 ? 0 : 1 }' "$fixture_root/jq.log"; then
    printf '[FAIL] %s: validation success did not precede exactly one injected identity query error\n' "$name"
    test_status=1
  fi
  if ! sed 's/\r$//' "$session_log" | grep -Eq '^OPENCODE_INSTALLER_EXIT=[1-9][0-9]*$'; then
    printf '[FAIL] %s: installer treated the identity query error as absence instead of exiting non-zero\n' "$name"
    test_status=1
  fi
  if ! grep -Fq "cannot inspect JSON agent declarations in '$config_file'" "$session_log"; then
    printf '[FAIL] %s: JSON inspection diagnostic did not identify the config path\n' "$name"
    test_status=1
  fi
  if ! cmp -s "$temporary_directory/expected-opencode.json" "$config_file"; then
    printf '[FAIL] %s: JSON config changed during preflight\n' "$name"
    test_status=1
  fi
  if [[ -e "$home_directory/.config/opencode/agents" || -L "$home_directory/.config/opencode/agents" || -e "$home_directory/.config/opencode/agents.LICENSE" || -L "$home_directory/.config/opencode/agents.LICENSE" ]]; then
    printf '[FAIL] %s: user-scope bundle files were written after the identity query error\n' "$name"
    test_status=1
  fi
  return "$test_status"
}

test_opencode_installer_fails_closed_when_relevant_json_cannot_be_inspected() {
  local name="opencode_installer_fails_closed_when_relevant_json_cannot_be_inspected"
  local scope
  local fixture_root
  local invocation_directory
  local project_directory
  local home_directory
  local xdg_directory
  local temporary_directory
  local session_log
  local config_file
  local expected_config
  local selected_base
  local test_status=0

  for scope in user project; do
    fixture_root="$(mktemp -d "$ELELEM_TEST_ROOT/malformed-json-agent-$scope.XXXXXX")"
    invocation_directory="$fixture_root/invocation"
    project_directory="$fixture_root/project"
    home_directory="$fixture_root/home"
    xdg_directory="$fixture_root/xdg"
    temporary_directory="$fixture_root/tmp"
    session_log="$fixture_root/session.log"

    mkdir -p "$invocation_directory" "$project_directory" "$home_directory" "$xdg_directory" "$temporary_directory"
    ln -s "$repository_root/install-opencode.sh" "$invocation_directory/install-opencode.sh"
    ln -s "$repository_root/_install-common.sh" "$invocation_directory/_install-common.sh"
    cp -R "$repository_root/rules" "$invocation_directory/rules"
    cp -R "$repository_root/skills" "$invocation_directory/skills"
    cp -R "$repository_root/agents" "$invocation_directory/agents"

    if [[ "$scope" == user ]]; then
      config_file="$project_directory/.opencode/opencode.json"
      selected_base="$home_directory/.config/opencode"
    elif [[ "$scope" == project ]]; then
      config_file="$home_directory/.config/opencode/opencode.json"
      selected_base="$project_directory/.opencode"
    fi
    expected_config="$temporary_directory/expected-opencode.json"
    mkdir -p "$(dirname "$config_file")"
    printf '{ "agent": {' > "$config_file"
    cp "$config_file" "$expected_config"

    cat > "$temporary_directory/run-installer.sh" <<'EOF'
#!/usr/bin/env bash
fixture_directory="$(cd "$(dirname "$0")/.." && pwd)"
cd "$fixture_directory/project" || exit 1
"$fixture_directory/invocation/install-opencode.sh"
installer_status=$?
printf '\nOPENCODE_INSTALLER_EXIT=%s\n' "$installer_status"
exit "$installer_status"
EOF
    chmod +x "$temporary_directory/run-installer.sh"

    HOME="$home_directory"
    XDG_CONFIG_HOME="$xdg_directory"
    TMPDIR="$temporary_directory"
    export HOME XDG_CONFIG_HOME TMPDIR
    if [[ "$scope" == user ]]; then
      printf '\033[B\n\n\n\n \n' | /usr/bin/script -q "$session_log" "$temporary_directory/run-installer.sh" >/dev/null
    else
      printf '\033[A\n%s\n\n\n\n \n' "$project_directory" | /usr/bin/script -q "$session_log" "$temporary_directory/run-installer.sh" >/dev/null
    fi

    if ! sed 's/\r$//' "$session_log" | grep -Eq '^OPENCODE_INSTALLER_EXIT=[1-9][0-9]*$'; then
      printf '[FAIL] %s: %s-scope installer did not exit with a non-zero status\n' "$name" "$scope"
      test_status=1
    fi

    if ! grep -Fq 'cannot inspect JSON agent declarations' "$session_log" || ! grep -Fq "$config_file" "$session_log"; then
      printf '[FAIL] %s: %s-scope malformed JSON diagnostic did not identify %s\n' "$name" "$scope" "$config_file"
      test_status=1
    fi

    if ! cmp -s "$expected_config" "$config_file"; then
      printf '[FAIL] %s: %s-scope malformed JSON config changed during preflight\n' "$name" "$scope"
      test_status=1
    fi

    if [[ -e "$selected_base/agents/architect-reviewer.md" || -L "$selected_base/agents/architect-reviewer.md" || -e "$selected_base/agents.LICENSE" || -L "$selected_base/agents.LICENSE" ]]; then
      printf '[FAIL] %s: %s-scope bundle files were written despite malformed JSON\n' "$name" "$scope"
      test_status=1
    fi
  done

  fixture_root="$(mktemp -d "$ELELEM_TEST_ROOT/uninspectable-json-agent-project-config.XXXXXX")"
  invocation_directory="$fixture_root/invocation"
  project_directory="$fixture_root/project"
  home_directory="$fixture_root/home"
  xdg_directory="$fixture_root/xdg"
  temporary_directory="$fixture_root/tmp"
  session_log="$fixture_root/session.log"
  config_file="$project_directory/.opencode/opencode.json"
  selected_base="$home_directory/.config/opencode"

  mkdir -p "$invocation_directory" "$project_directory" "$home_directory" "$xdg_directory" "$temporary_directory" "$config_file"
  ln -s "$repository_root/install-opencode.sh" "$invocation_directory/install-opencode.sh"
  ln -s "$repository_root/_install-common.sh" "$invocation_directory/_install-common.sh"
  cp -R "$repository_root/rules" "$invocation_directory/rules"
  cp -R "$repository_root/skills" "$invocation_directory/skills"
  cp -R "$repository_root/agents" "$invocation_directory/agents"

  cat > "$temporary_directory/run-installer.sh" <<'EOF'
#!/usr/bin/env bash
fixture_directory="$(cd "$(dirname "$0")/.." && pwd)"
cd "$fixture_directory/project" || exit 1
"$fixture_directory/invocation/install-opencode.sh"
installer_status=$?
printf '\nOPENCODE_INSTALLER_EXIT=%s\n' "$installer_status"
exit "$installer_status"
EOF
  chmod +x "$temporary_directory/run-installer.sh"

  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  TMPDIR="$temporary_directory"
  export HOME XDG_CONFIG_HOME TMPDIR
  printf '\033[B\n\n\n\n \n' | /usr/bin/script -q "$session_log" "$temporary_directory/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Eq '^OPENCODE_INSTALLER_EXIT=[1-9][0-9]*$'; then
    printf '[FAIL] %s: user-scope installer did not exit with a non-zero status for an uninspectable config path\n' "$name"
    test_status=1
  fi

  if ! grep -Fq 'cannot inspect JSON agent declarations' "$session_log" || ! grep -Fq "$config_file" "$session_log"; then
    printf '[FAIL] %s: user-scope uninspectable JSON diagnostic did not identify %s\n' "$name" "$config_file"
    test_status=1
  fi

  if [[ ! -d "$config_file" ]]; then
    printf '[FAIL] %s: current-project JSON config path did not remain a directory\n' "$name"
    test_status=1
  fi

  if [[ -e "$selected_base/agents/architect-reviewer.md" || -L "$selected_base/agents/architect-reviewer.md" || -e "$selected_base/agents.LICENSE" || -L "$selected_base/agents.LICENSE" ]]; then
    printf '[FAIL] %s: user-scope bundle files were written despite the uninspectable JSON path\n' "$name"
    test_status=1
  fi

  fixture_root="$(mktemp -d "$ELELEM_TEST_ROOT/unreadable-json-agent-project-config.XXXXXX")"
  invocation_directory="$fixture_root/invocation"
  project_directory="$fixture_root/project"
  home_directory="$fixture_root/home"
  xdg_directory="$fixture_root/xdg"
  temporary_directory="$fixture_root/tmp"
  session_log="$fixture_root/session.log"
  config_file="$project_directory/.opencode/opencode.json"
  expected_config="$temporary_directory/expected-opencode.json"
  selected_base="$home_directory/.config/opencode"

  mkdir -p "$invocation_directory" "$project_directory" "$home_directory" "$xdg_directory" "$temporary_directory" "$(dirname "$config_file")"
  ln -s "$repository_root/install-opencode.sh" "$invocation_directory/install-opencode.sh"
  ln -s "$repository_root/_install-common.sh" "$invocation_directory/_install-common.sh"
  cp -R "$repository_root/rules" "$invocation_directory/rules"
  cp -R "$repository_root/skills" "$invocation_directory/skills"
  cp -R "$repository_root/agents" "$invocation_directory/agents"
  printf '{ "agent": {} }\n' > "$config_file"
  cp "$config_file" "$expected_config"

  cat > "$temporary_directory/run-installer.sh" <<'EOF'
#!/usr/bin/env bash
fixture_directory="$(cd "$(dirname "$0")/.." && pwd)"
cd "$fixture_directory/project" || exit 1
"$fixture_directory/invocation/install-opencode.sh"
installer_status=$?
printf '\nOPENCODE_INSTALLER_EXIT=%s\n' "$installer_status"
exit "$installer_status"
EOF
  chmod +x "$temporary_directory/run-installer.sh"

  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  TMPDIR="$temporary_directory"
  export HOME XDG_CONFIG_HOME TMPDIR
  chmod 000 "$config_file"
  if [[ -r "$config_file" ]]; then
    printf '[FAIL] %s: current-project JSON config remained readable after permissions were removed\n' "$name"
    test_status=1
  fi
  printf '\033[B\n\n\n\n \n' | /usr/bin/script -q "$session_log" "$temporary_directory/run-installer.sh" >/dev/null
  chmod 600 "$config_file"

  if ! sed 's/\r$//' "$session_log" | grep -Eq '^OPENCODE_INSTALLER_EXIT=[1-9][0-9]*$'; then
    printf '[FAIL] %s: user-scope installer did not exit with a positive status for unreadable JSON\n' "$name"
    test_status=1
  fi

  if ! grep -Fq 'cannot inspect JSON agent declarations' "$session_log" || ! grep -Fq "$config_file" "$session_log"; then
    printf '[FAIL] %s: user-scope unreadable JSON diagnostic did not identify %s\n' "$name" "$config_file"
    test_status=1
  fi

  if ! cmp -s "$expected_config" "$config_file"; then
    printf '[FAIL] %s: current-project JSON config changed after unreadable JSON preflight\n' "$name"
    test_status=1
  fi

  if [[ -e "$selected_base/agents/architect-reviewer.md" || -L "$selected_base/agents/architect-reviewer.md" || -e "$selected_base/agents.LICENSE" || -L "$selected_base/agents.LICENSE" ]]; then
    printf '[FAIL] %s: user-scope bundle files were written despite unreadable JSON\n' "$name"
    test_status=1
  fi

  return "$test_status"
}

test_opencode_installer_reports_bundle_changes_when_manifest_write_fails() {
  local name="opencode_installer_reports_bundle_changes_when_manifest_write_fails"
  local fixture_root
  local invocation_directory
  local project_directory
  local home_directory
  local xdg_directory
  local temporary_directory
  local bin_directory
  local session_log
  local manifest_file
  local expected_manifest
  local user_agent
  local user_agent_notice
  local changed_paths_file
  local source_file
  local filename
  local changed_path_count
  local original_path="$PATH"
  local test_status=0

  fixture_root="$(mktemp -d "$ELELEM_TEST_ROOT/manifest-write-failure.XXXXXX")"
  invocation_directory="$fixture_root/invocation"
  project_directory="$fixture_root/project"
  home_directory="$fixture_root/home"
  xdg_directory="$fixture_root/xdg"
  temporary_directory="$fixture_root/tmp"
  bin_directory="$fixture_root/bin"
  session_log="$fixture_root/session.log"
  manifest_file="$invocation_directory/.elelem-manifest-opencode"
  expected_manifest="$temporary_directory/expected-manifest"
  user_agent="$home_directory/.config/opencode/agents/architect-reviewer.md"
  user_agent_notice="$home_directory/.config/opencode/agents.LICENSE"
  changed_paths_file="$temporary_directory/changed-paths"

  mkdir -p "$invocation_directory" "$project_directory" "$home_directory" "$xdg_directory" "$temporary_directory" "$bin_directory"
  ln -s "$repository_root/install-opencode.sh" "$invocation_directory/install-opencode.sh"
  ln -s "$repository_root/_install-common.sh" "$invocation_directory/_install-common.sh"
  cp -R "$repository_root/rules" "$invocation_directory/rules"
  cp -R "$repository_root/skills" "$invocation_directory/skills"
  cp -R "$repository_root/agents" "$invocation_directory/agents"

  cat > "$temporary_directory/run-installer.sh" <<'EOF'
#!/usr/bin/env bash
fixture_directory="$(cd "$(dirname "$0")/.." && pwd)"
cd "$fixture_directory/project" || exit 1
"$fixture_directory/invocation/install-opencode.sh"
installer_status=$?
printf '\nOPENCODE_INSTALLER_EXIT=%s\n' "$installer_status"
exit "$installer_status"
EOF
  chmod +x "$temporary_directory/run-installer.sh"

  cat > "$bin_directory/sort" <<'EOF'
#!/usr/bin/env bash
for argument in "$@"; do
  if [[ "$argument" == *.elelem-manifest-opencode.entries.* ]]; then
    exit 1
  fi
done
exec /usr/bin/sort "$@"
EOF
  chmod +x "$bin_directory/sort"

  printf '%s\npreserved-sentinel\n' "$home_directory/.config/opencode" > "$manifest_file"
  cp "$manifest_file" "$expected_manifest"

  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  TMPDIR="$temporary_directory"
  PATH="$bin_directory:$PATH"
  export HOME XDG_CONFIG_HOME TMPDIR PATH
  printf '\033[B\n\n\n\n \n' | /usr/bin/script -q "$session_log" "$temporary_directory/run-installer.sh" >/dev/null
  PATH="$original_path"
  export PATH

  if ! sed 's/\r$//' "$session_log" | grep -Eq '^OPENCODE_INSTALLER_EXIT=[1-9][0-9]*$'; then
    printf '[FAIL] %s: installer did not exit with a non-zero status\n' "$name"
    test_status=1
  fi

  if ! cmp -s "$expected_manifest" "$manifest_file"; then
    printf '[FAIL] %s: manifest changed after the staged manifest write failed\n' "$name"
    test_status=1
  fi

  if [[ ! -f "$user_agent" ]] || ! cmp -s "$invocation_directory/agents/opencode/architect-reviewer.md" "$user_agent"; then
    printf '[FAIL] %s: user-scope architect-reviewer agent is missing or differs from its source\n' "$name"
    test_status=1
  fi

  if [[ ! -f "$user_agent_notice" ]] || ! cmp -s "$invocation_directory/agents/LICENSE" "$user_agent_notice"; then
    printf '[FAIL] %s: user-scope agent notice is missing or differs from its source\n' "$name"
    test_status=1
  fi

  awk '{ gsub(/\033\[[0-9;?]*[[:alpha:]]/, ""); sub(/\r$/, "") } $0 == "Changed paths:" { in_changed_paths = 1; next } in_changed_paths && /^  / { print; next } in_changed_paths { exit }' "$session_log" > "$changed_paths_file"
  changed_path_count="$(wc -l < "$changed_paths_file" | tr -d '[:space:]')"
  if [[ "$changed_path_count" != 12 ]]; then
    printf '[FAIL] %s: Changed paths list contains %s destinations, expected 12\n' "$name" "$changed_path_count"
    test_status=1
  fi
  if ! grep -Fqx "  $user_agent_notice" "$changed_paths_file"; then
    printf '[FAIL] %s: Changed paths list omits %s\n' "$name" "$user_agent_notice"
    test_status=1
  fi
  for source_file in "$invocation_directory/agents/opencode/"*.md; do
    filename="$(basename "$source_file")"
    if ! grep -Fqx "  $home_directory/.config/opencode/agents/$filename" "$changed_paths_file"; then
      printf '[FAIL] %s: Changed paths list omits %s\n' "$name" "$home_directory/.config/opencode/agents/$filename"
      test_status=1
    fi
  done

  return "$test_status"
}

test_opencode_installer_reports_bundle_changes_when_manifest_pruning_fails() {
  local name="opencode_installer_reports_bundle_changes_when_manifest_pruning_fails"
  local fixture_root
  local invocation_directory
  local project_directory
  local home_directory
  local xdg_directory
  local temporary_directory
  local bin_directory
  local session_log
  local manifest_file
  local expected_manifest
  local stale_file
  local expected_stale_file
  local changed_paths_file
  local source_file
  local filename
  local changed_path_count
  local original_path="$PATH"
  local test_status=0

  fixture_root="$(mktemp -d "$ELELEM_TEST_ROOT/manifest-prune-failure.XXXXXX")"
  invocation_directory="$fixture_root/invocation"
  project_directory="$fixture_root/project"
  home_directory="$fixture_root/home"
  xdg_directory="$fixture_root/xdg"
  temporary_directory="$fixture_root/tmp"
  bin_directory="$fixture_root/bin"
  session_log="$fixture_root/session.log"
  manifest_file="$invocation_directory/.elelem-manifest-opencode"
  expected_manifest="$temporary_directory/expected-manifest"
  stale_file="$home_directory/.config/opencode/stale-opencode-file.md"
  expected_stale_file="$temporary_directory/expected-stale-opencode-file.md"
  changed_paths_file="$temporary_directory/changed-paths"

  mkdir -p "$invocation_directory" "$project_directory" "$home_directory/.config/opencode" "$xdg_directory" "$temporary_directory" "$bin_directory"
  ln -s "$repository_root/install-opencode.sh" "$invocation_directory/install-opencode.sh"
  ln -s "$repository_root/_install-common.sh" "$invocation_directory/_install-common.sh"
  cp -R "$repository_root/rules" "$invocation_directory/rules"
  cp -R "$repository_root/skills" "$invocation_directory/skills"
  cp -R "$repository_root/agents" "$invocation_directory/agents"

  cat > "$temporary_directory/run-installer.sh" <<'EOF'
#!/usr/bin/env bash
fixture_directory="$(cd "$(dirname "$0")/.." && pwd)"
cd "$fixture_directory/project" || exit 1
"$fixture_directory/invocation/install-opencode.sh"
installer_status=$?
printf '\nOPENCODE_INSTALLER_EXIT=%s\n' "$installer_status"
exit "$installer_status"
EOF
  chmod +x "$temporary_directory/run-installer.sh"

  cat > "$bin_directory/rm" <<EOF
#!/usr/bin/env bash
for argument in "\$@"; do
  if [[ "\$argument" == "$stale_file" ]]; then
    exit 1
  fi
done
exec /bin/rm "\$@"
EOF
  chmod +x "$bin_directory/rm"

  printf '%s\nstale-opencode-file.md\n' "$home_directory/.config/opencode" > "$manifest_file"
  cp "$manifest_file" "$expected_manifest"
  printf 'Stale tracked file bytes to preserve.\n' > "$stale_file"
  cp "$stale_file" "$expected_stale_file"

  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  TMPDIR="$temporary_directory"
  PATH="$bin_directory:$PATH"
  export HOME XDG_CONFIG_HOME TMPDIR PATH
  printf '\033[B\n\n\n\n \n' | /usr/bin/script -q "$session_log" "$temporary_directory/run-installer.sh" >/dev/null
  PATH="$original_path"
  export PATH

  if ! sed 's/\r$//' "$session_log" | grep -Eq '^OPENCODE_INSTALLER_EXIT=[1-9][0-9]*$'; then
    printf '[FAIL] %s: installer did not exit with a positive status\n' "$name"
    test_status=1
  fi

  if ! cmp -s "$expected_manifest" "$manifest_file"; then
    printf '[FAIL] %s: manifest changed after stale-entry pruning failed\n' "$name"
    test_status=1
  fi

  if ! cmp -s "$expected_stale_file" "$stale_file"; then
    printf '[FAIL] %s: stale file changed after stale-entry pruning failed\n' "$name"
    test_status=1
  fi

  awk '{ gsub(/\033\[[0-9;?]*[[:alpha:]]/, ""); sub(/\r$/, "") } $0 == "Changed paths:" { in_changed_paths = 1; next } in_changed_paths && /^  / { print; next } in_changed_paths { exit }' "$session_log" > "$changed_paths_file"
  changed_path_count="$(wc -l < "$changed_paths_file" | tr -d '[:space:]')"
  if [[ "$changed_path_count" != 12 ]]; then
    printf '[FAIL] %s: Changed paths list contains %s destinations, expected 12\n' "$name" "$changed_path_count"
    test_status=1
  fi
  if ! grep -Fqx "  $home_directory/.config/opencode/agents.LICENSE" "$changed_paths_file"; then
    printf '[FAIL] %s: Changed paths list omits %s\n' "$name" "$home_directory/.config/opencode/agents.LICENSE"
    test_status=1
  fi
  for source_file in "$invocation_directory/agents/opencode/"*.md; do
    filename="$(basename "$source_file")"
    if ! grep -Fqx "  $home_directory/.config/opencode/agents/$filename" "$changed_paths_file"; then
      printf '[FAIL] %s: Changed paths list omits %s\n' "$name" "$home_directory/.config/opencode/agents/$filename"
      test_status=1
    fi
  done

  return "$test_status"
}

test_opencode_installer_replaces_a_canonical_agent_after_confirmation() {
  local name="opencode_installer_replaces_a_canonical_agent_after_confirmation"
  local fixture_root
  local invocation_directory
  local project_directory
  local home_directory
  local xdg_directory
  local temporary_directory
  local session_log
  local user_agent
  local manifest_file

  fixture_root="$(mktemp -d "$ELELEM_TEST_ROOT/replace-agent-confirmed.XXXXXX")"
  invocation_directory="$fixture_root/invocation"
  project_directory="$fixture_root/project"
  home_directory="$fixture_root/home"
  xdg_directory="$fixture_root/xdg"
  temporary_directory="$fixture_root/tmp"
  session_log="$fixture_root/session.log"
  user_agent="$home_directory/.config/opencode/agents/architect-reviewer.md"
  manifest_file="$invocation_directory/.elelem-manifest-opencode"

  mkdir -p "$invocation_directory" "$project_directory" "$(dirname "$user_agent")" "$xdg_directory" "$temporary_directory"
  ln -s "$repository_root/install-opencode.sh" "$invocation_directory/install-opencode.sh"
  ln -s "$repository_root/_install-common.sh" "$invocation_directory/_install-common.sh"
  cp -R "$repository_root/rules" "$invocation_directory/rules"
  cp -R "$repository_root/skills" "$invocation_directory/skills"
  cp -R "$repository_root/agents" "$invocation_directory/agents"
  printf 'Existing user-authored agent bytes to replace.\n' > "$user_agent"

  cat > "$temporary_directory/run-installer.sh" <<'EOF'
#!/usr/bin/env bash
fixture_directory="$(cd "$(dirname "$0")/.." && pwd)"
cd "$fixture_directory/project" || exit 1
"$fixture_directory/invocation/install-opencode.sh"
installer_status=$?
printf '\nOPENCODE_INSTALLER_EXIT=%s\n' "$installer_status"
exit "$installer_status"
EOF
  chmod +x "$temporary_directory/run-installer.sh"

  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  TMPDIR="$temporary_directory"
  export HOME XDG_CONFIG_HOME TMPDIR
  printf '\033[B\n\n\n\n \ny\n' | /usr/bin/script -q "$session_log" "$temporary_directory/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Fqx 'OPENCODE_INSTALLER_EXIT=0'; then
    printf '[FAIL] %s: installer did not exit with status 0\n' "$name"
    return 1
  fi
  if ! grep -Fq "Replace existing agent 'architect-reviewer.md'? [y/n]" "$session_log"; then
    printf '[FAIL] %s: canonical agent replacement prompt was not displayed\n' "$name"
    return 1
  fi
  if ! cmp -s "$invocation_directory/agents/opencode/architect-reviewer.md" "$user_agent"; then
    printf '[FAIL] %s: confirmed canonical agent replacement did not install the bundled definition\n' "$name"
    return 1
  fi
  if [[ ! -f "$manifest_file" ]] || ! grep -Fqx 'agents/architect-reviewer.md' "$manifest_file"; then
    printf '[FAIL] %s: replaced canonical agent was not recorded in the manifest\n' "$name"
    return 1
  fi

  return 0
}

test_opencode_installer_preserves_a_managed_agent_when_replacement_is_refused() {
  local name="opencode_installer_preserves_a_managed_agent_when_replacement_is_refused"
  local fixture_root
  local invocation_directory
  local project_directory
  local home_directory
  local xdg_directory
  local temporary_directory
  local session_log
  local user_agent
  local expected_agent
  local manifest_file

  fixture_root="$(mktemp -d "$ELELEM_TEST_ROOT/refuse-managed-agent.XXXXXX")"
  invocation_directory="$fixture_root/invocation"
  project_directory="$fixture_root/project"
  home_directory="$fixture_root/home"
  xdg_directory="$fixture_root/xdg"
  temporary_directory="$fixture_root/tmp"
  session_log="$fixture_root/session.log"
  user_agent="$home_directory/.config/opencode/agents/architect-reviewer.md"
  expected_agent="$temporary_directory/expected-architect-reviewer.md"
  manifest_file="$invocation_directory/.elelem-manifest-opencode"

  mkdir -p "$invocation_directory" "$project_directory" "$(dirname "$user_agent")" "$xdg_directory" "$temporary_directory"
  ln -s "$repository_root/install-opencode.sh" "$invocation_directory/install-opencode.sh"
  ln -s "$repository_root/_install-common.sh" "$invocation_directory/_install-common.sh"
  cp -R "$repository_root/rules" "$invocation_directory/rules"
  cp -R "$repository_root/skills" "$invocation_directory/skills"
  cp -R "$repository_root/agents" "$invocation_directory/agents"
  printf 'Existing managed canonical agent bytes to preserve.\n' > "$user_agent"
  cp "$user_agent" "$expected_agent"
  printf '%s\nagents/architect-reviewer.md\n' "$home_directory/.config/opencode" > "$manifest_file"

  cat > "$temporary_directory/run-installer.sh" <<'EOF'
#!/usr/bin/env bash
fixture_directory="$(cd "$(dirname "$0")/.." && pwd)"
cd "$fixture_directory/project" || exit 1
"$fixture_directory/invocation/install-opencode.sh"
installer_status=$?
printf '\nOPENCODE_INSTALLER_EXIT=%s\n' "$installer_status"
exit "$installer_status"
EOF
  chmod +x "$temporary_directory/run-installer.sh"

  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  TMPDIR="$temporary_directory"
  export HOME XDG_CONFIG_HOME TMPDIR
  printf '\033[B\n\n\n\n \nn\n' | /usr/bin/script -q "$session_log" "$temporary_directory/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Fqx 'OPENCODE_INSTALLER_EXIT=0'; then
    printf '[FAIL] %s: installer did not exit with status 0\n' "$name"
    return 1
  fi
  if ! grep -Fq "Replace existing agent 'architect-reviewer.md'? [y/n]" "$session_log"; then
    printf '[FAIL] %s: canonical agent replacement prompt was not displayed\n' "$name"
    return 1
  fi
  if ! cmp -s "$expected_agent" "$user_agent"; then
    printf '[FAIL] %s: refused managed canonical agent was not preserved byte-for-byte\n' "$name"
    return 1
  fi
  if [[ ! -f "$manifest_file" ]] || ! grep -Fqx 'agents/architect-reviewer.md' "$manifest_file"; then
    printf '[FAIL] %s: refused managed canonical agent was removed from the manifest\n' "$name"
    return 1
  fi

  return 0
}

test_opencode_installer_preserves_an_unmanaged_agent_when_replacement_is_refused() {
  local name="opencode_installer_preserves_an_unmanaged_agent_when_replacement_is_refused"
  local fixture_root
  local invocation_directory
  local project_directory
  local home_directory
  local xdg_directory
  local temporary_directory
  local session_log
  local user_agent
  local expected_agent
  local manifest_file

  fixture_root="$(mktemp -d "$ELELEM_TEST_ROOT/refuse-unmanaged-agent.XXXXXX")"
  invocation_directory="$fixture_root/invocation"
  project_directory="$fixture_root/project"
  home_directory="$fixture_root/home"
  xdg_directory="$fixture_root/xdg"
  temporary_directory="$fixture_root/tmp"
  session_log="$fixture_root/session.log"
  user_agent="$home_directory/.config/opencode/agents/architect-reviewer.md"
  expected_agent="$temporary_directory/expected-architect-reviewer.md"
  manifest_file="$invocation_directory/.elelem-manifest-opencode"

  mkdir -p "$invocation_directory" "$project_directory" "$(dirname "$user_agent")" "$xdg_directory" "$temporary_directory"
  ln -s "$repository_root/install-opencode.sh" "$invocation_directory/install-opencode.sh"
  ln -s "$repository_root/_install-common.sh" "$invocation_directory/_install-common.sh"
  cp -R "$repository_root/rules" "$invocation_directory/rules"
  cp -R "$repository_root/skills" "$invocation_directory/skills"
  cp -R "$repository_root/agents" "$invocation_directory/agents"
  printf 'Existing unmanaged canonical agent bytes to preserve.\n' > "$user_agent"
  cp "$user_agent" "$expected_agent"

  cat > "$temporary_directory/run-installer.sh" <<'EOF'
#!/usr/bin/env bash
fixture_directory="$(cd "$(dirname "$0")/.." && pwd)"
cd "$fixture_directory/project" || exit 1
"$fixture_directory/invocation/install-opencode.sh"
installer_status=$?
printf '\nOPENCODE_INSTALLER_EXIT=%s\n' "$installer_status"
exit "$installer_status"
EOF
  chmod +x "$temporary_directory/run-installer.sh"

  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  TMPDIR="$temporary_directory"
  export HOME XDG_CONFIG_HOME TMPDIR
  printf '\033[B\n\n\n\n \nn\n' | /usr/bin/script -q "$session_log" "$temporary_directory/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Fqx 'OPENCODE_INSTALLER_EXIT=0'; then
    printf '[FAIL] %s: installer did not exit with status 0\n' "$name"
    return 1
  fi
  if ! grep -Fq "Replace existing agent 'architect-reviewer.md'? [y/n]" "$session_log"; then
    printf '[FAIL] %s: canonical agent replacement prompt was not displayed\n' "$name"
    return 1
  fi
  if ! cmp -s "$expected_agent" "$user_agent"; then
    printf '[FAIL] %s: refused unmanaged canonical agent was not preserved byte-for-byte\n' "$name"
    return 1
  fi
  if [[ -f "$manifest_file" ]] && grep -Fqx 'agents/architect-reviewer.md' "$manifest_file"; then
    printf '[FAIL] %s: refused unmanaged canonical agent was added to the manifest\n' "$name"
    return 1
  fi

  return 0
}

test_opencode_installer_refuses_a_mismatched_notice_when_replacement_is_declined() {
  local name="opencode_installer_refuses_a_mismatched_notice_when_replacement_is_declined"
  local fixture_root
  local invocation_directory
  local project_directory
  local home_directory
  local xdg_directory
  local temporary_directory
  local session_log
  local existing_notice
  local expected_notice
  local manifest_file
  local user_agent

  fixture_root="$(mktemp -d "$ELELEM_TEST_ROOT/refuse-mismatched-notice.XXXXXX")"
  invocation_directory="$fixture_root/invocation"
  project_directory="$fixture_root/project"
  home_directory="$fixture_root/home"
  xdg_directory="$fixture_root/xdg"
  temporary_directory="$fixture_root/tmp"
  session_log="$fixture_root/session.log"
  existing_notice="$home_directory/.config/opencode/agents.LICENSE"
  expected_notice="$temporary_directory/expected-agents.LICENSE"
  manifest_file="$invocation_directory/.elelem-manifest-opencode"
  user_agent="$home_directory/.config/opencode/agents/architect-reviewer.md"

  mkdir -p "$invocation_directory" "$project_directory" "$(dirname "$existing_notice")" "$xdg_directory" "$temporary_directory"
  ln -s "$repository_root/install-opencode.sh" "$invocation_directory/install-opencode.sh"
  ln -s "$repository_root/_install-common.sh" "$invocation_directory/_install-common.sh"
  cp -R "$repository_root/rules" "$invocation_directory/rules"
  cp -R "$repository_root/skills" "$invocation_directory/skills"
  cp -R "$repository_root/agents" "$invocation_directory/agents"
  printf 'Existing mismatched notice bytes to preserve.\n' > "$existing_notice"
  cp "$existing_notice" "$expected_notice"

  cat > "$temporary_directory/run-installer.sh" <<'EOF'
#!/usr/bin/env bash
fixture_directory="$(cd "$(dirname "$0")/.." && pwd)"
cd "$fixture_directory/project" || exit 1
"$fixture_directory/invocation/install-opencode.sh"
installer_status=$?
printf '\nOPENCODE_INSTALLER_EXIT=%s\n' "$installer_status"
exit "$installer_status"
EOF
  chmod +x "$temporary_directory/run-installer.sh"

  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  TMPDIR="$temporary_directory"
  export HOME XDG_CONFIG_HOME TMPDIR
  printf '\033[B\n\n\n\n \nn\n' | /usr/bin/script -q "$session_log" "$temporary_directory/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Eq '^OPENCODE_INSTALLER_EXIT=[1-9][0-9]*$'; then
    printf '[FAIL] %s: installer did not exit with a positive status\n' "$name"
    return 1
  fi
  if ! grep -Fq "Replace existing notice 'agents.LICENSE'? [y/n]" "$session_log"; then
    printf '[FAIL] %s: notice replacement prompt was not displayed\n' "$name"
    return 1
  fi
  if ! cmp -s "$expected_notice" "$existing_notice"; then
    printf '[FAIL] %s: refused mismatched notice was not preserved byte-for-byte\n' "$name"
    return 1
  fi
  if [[ -e "$user_agent" || -L "$user_agent" ]]; then
    printf '[FAIL] %s: agent bundle was installed despite notice replacement refusal\n' "$name"
    return 1
  fi
  if [[ -f "$manifest_file" ]] && grep -Fqx 'agents.LICENSE' "$manifest_file"; then
    printf '[FAIL] %s: refused unmanaged notice was added to the manifest\n' "$name"
    return 1
  fi

  return 0
}

test_opencode_installer_installs_agents_after_refusing_an_exact_notice_without_claiming_it() {
  local name="opencode_installer_installs_agents_after_refusing_an_exact_notice_without_claiming_it"
  local fixture_root
  local invocation_directory
  local project_directory
  local home_directory
  local xdg_directory
  local temporary_directory
  local session_log
  local existing_notice
  local agents_directory
  local manifest_file
  local source_file
  local filename
  local agent_count

  fixture_root="$(mktemp -d "$ELELEM_TEST_ROOT/refuse-exact-notice.XXXXXX")"
  invocation_directory="$fixture_root/invocation"
  project_directory="$fixture_root/project"
  home_directory="$fixture_root/home"
  xdg_directory="$fixture_root/xdg"
  temporary_directory="$fixture_root/tmp"
  session_log="$fixture_root/session.log"
  existing_notice="$home_directory/.config/opencode/agents.LICENSE"
  agents_directory="$home_directory/.config/opencode/agents"
  manifest_file="$invocation_directory/.elelem-manifest-opencode"

  mkdir -p "$invocation_directory" "$project_directory" "$(dirname "$existing_notice")" "$xdg_directory" "$temporary_directory"
  ln -s "$repository_root/install-opencode.sh" "$invocation_directory/install-opencode.sh"
  ln -s "$repository_root/_install-common.sh" "$invocation_directory/_install-common.sh"
  cp -R "$repository_root/rules" "$invocation_directory/rules"
  cp -R "$repository_root/skills" "$invocation_directory/skills"
  cp -R "$repository_root/agents" "$invocation_directory/agents"
  cp "$invocation_directory/agents/LICENSE" "$existing_notice"

  cat > "$temporary_directory/run-installer.sh" <<'EOF'
#!/usr/bin/env bash
fixture_directory="$(cd "$(dirname "$0")/.." && pwd)"
cd "$fixture_directory/project" || exit 1
"$fixture_directory/invocation/install-opencode.sh"
installer_status=$?
printf '\nOPENCODE_INSTALLER_EXIT=%s\n' "$installer_status"
exit "$installer_status"
EOF
  chmod +x "$temporary_directory/run-installer.sh"

  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  TMPDIR="$temporary_directory"
  export HOME XDG_CONFIG_HOME TMPDIR
  printf '\033[B\n\n\n\n \nn\n' | /usr/bin/script -q "$session_log" "$temporary_directory/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Fqx 'OPENCODE_INSTALLER_EXIT=0'; then
    printf '[FAIL] %s: installer did not exit with status 0\n' "$name"
    return 1
  fi
  if ! grep -Fq "Replace existing notice 'agents.LICENSE'? [y/n]" "$session_log"; then
    printf '[FAIL] %s: notice replacement prompt was not displayed\n' "$name"
    return 1
  fi
  if ! cmp -s "$invocation_directory/agents/LICENSE" "$existing_notice"; then
    printf '[FAIL] %s: exact existing notice changed after replacement refusal\n' "$name"
    return 1
  fi

  agent_count="$(find "$agents_directory" -maxdepth 1 -type f -name '*.md' | wc -l | tr -d '[:space:]')"
  if [[ "$agent_count" != 11 ]]; then
    printf '[FAIL] %s: user agent bundle contains %s files, expected 11\n' "$name" "$agent_count"
    return 1
  fi
  for source_file in "$invocation_directory/agents/opencode/"*.md; do
    filename="$(basename "$source_file")"
    if ! cmp -s "$source_file" "$agents_directory/$filename"; then
      printf '[FAIL] %s: user agent %s is missing or differs from its source\n' "$name" "$filename"
      return 1
    fi
    if ! grep -Fqx "agents/$filename" "$manifest_file"; then
      printf '[FAIL] %s: manifest omits agents/%s\n' "$name" "$filename"
      return 1
    fi
  done
  if grep -Fqx 'agents.LICENSE' "$manifest_file"; then
    printf '[FAIL] %s: refused existing notice was added to the manifest\n' "$name"
    return 1
  fi

  return 0
}

test_opencode_installer_replaces_a_mismatched_notice_after_confirmation() {
  local name="opencode_installer_replaces_a_mismatched_notice_after_confirmation"
  local fixture_root
  local invocation_directory
  local project_directory
  local home_directory
  local xdg_directory
  local temporary_directory
  local session_log
  local existing_notice
  local user_agent
  local manifest_file

  fixture_root="$(mktemp -d "$ELELEM_TEST_ROOT/replace-notice-confirmed.XXXXXX")"
  invocation_directory="$fixture_root/invocation"
  project_directory="$fixture_root/project"
  home_directory="$fixture_root/home"
  xdg_directory="$fixture_root/xdg"
  temporary_directory="$fixture_root/tmp"
  session_log="$fixture_root/session.log"
  existing_notice="$home_directory/.config/opencode/agents.LICENSE"
  user_agent="$home_directory/.config/opencode/agents/architect-reviewer.md"
  manifest_file="$invocation_directory/.elelem-manifest-opencode"

  mkdir -p "$invocation_directory" "$project_directory" "$(dirname "$existing_notice")" "$xdg_directory" "$temporary_directory"
  ln -s "$repository_root/install-opencode.sh" "$invocation_directory/install-opencode.sh"
  ln -s "$repository_root/_install-common.sh" "$invocation_directory/_install-common.sh"
  cp -R "$repository_root/rules" "$invocation_directory/rules"
  cp -R "$repository_root/skills" "$invocation_directory/skills"
  cp -R "$repository_root/agents" "$invocation_directory/agents"
  printf 'Existing mismatched notice to replace after consent.\n' > "$existing_notice"

  cat > "$temporary_directory/run-installer.sh" <<'EOF'
#!/usr/bin/env bash
fixture_directory="$(cd "$(dirname "$0")/.." && pwd)"
cd "$fixture_directory/project" || exit 1
"$fixture_directory/invocation/install-opencode.sh"
installer_status=$?
printf '\nOPENCODE_INSTALLER_EXIT=%s\n' "$installer_status"
exit "$installer_status"
EOF
  chmod +x "$temporary_directory/run-installer.sh"

  HOME="$home_directory"
  XDG_CONFIG_HOME="$xdg_directory"
  TMPDIR="$temporary_directory"
  export HOME XDG_CONFIG_HOME TMPDIR
  printf '\033[B\n\n\n\n \ny\n' | /usr/bin/script -q "$session_log" "$temporary_directory/run-installer.sh" >/dev/null

  if ! sed 's/\r$//' "$session_log" | grep -Fqx 'OPENCODE_INSTALLER_EXIT=0'; then
    printf '[FAIL] %s: installer did not exit with status 0\n' "$name"
    return 1
  fi
  if ! grep -Fq "Replace existing notice 'agents.LICENSE'? [y/n]" "$session_log"; then
    printf '[FAIL] %s: notice replacement prompt was not displayed\n' "$name"
    return 1
  fi
  if ! cmp -s "$invocation_directory/agents/LICENSE" "$existing_notice"; then
    printf '[FAIL] %s: confirmed notice replacement did not install the bundled licence\n' "$name"
    return 1
  fi
  if [[ ! -f "$manifest_file" ]] || ! grep -Fqx 'agents.LICENSE' "$manifest_file"; then
    printf '[FAIL] %s: replaced notice was not recorded in the manifest\n' "$name"
    return 1
  fi
  if [[ ! -f "$user_agent" ]]; then
    printf '[FAIL] %s: agent bundle was not installed after confirming notice replacement\n' "$name"
    return 1
  fi

  return 0
}

test_opencode_installer_blocks_direct_project_json_conflicts() {
  local scenario fixture_root invocation_directory project_directory selected_project home_directory xdg_directory temporary_directory config_file selected_base session_log test_status=0

  for scenario in current selected; do
    fixture_root="$(mktemp -d "$ELELEM_TEST_ROOT/direct-project-json-$scenario.XXXXXX")"
    invocation_directory="$fixture_root/invocation"
    project_directory="$fixture_root/project"
    selected_project="$project_directory/selected"
    home_directory="$fixture_root/home"
    xdg_directory="$fixture_root/xdg"
    temporary_directory="$fixture_root/tmp"
    session_log="$fixture_root/session.log"
    mkdir -p "$invocation_directory" "$selected_project" "$home_directory" "$xdg_directory" "$temporary_directory"
    ln -s "$repository_root/install-opencode.sh" "$invocation_directory/install-opencode.sh"
    ln -s "$repository_root/_install-common.sh" "$invocation_directory/_install-common.sh"
    cp -R "$repository_root/rules" "$invocation_directory/rules"
    cp -R "$repository_root/skills" "$invocation_directory/skills"
    cp -R "$repository_root/agents" "$invocation_directory/agents"
    if [[ "$scenario" == current ]]; then
      config_file="$project_directory/opencode.json"
      selected_base="$home_directory/.config/opencode"
    else
      config_file="$selected_project/opencode.json"
      selected_base="$selected_project/.opencode"
    fi
    printf '{"agent":{"architect-reviewer":{}}}\n' > "$config_file"
    cp "$config_file" "$temporary_directory/expected-config"
    cat > "$temporary_directory/run-installer.sh" <<'EOF'
#!/usr/bin/env bash
fixture_directory="$(cd "$(dirname "$0")/.." && pwd)"
cd "$fixture_directory/project" || exit 1
"$fixture_directory/invocation/install-opencode.sh"
installer_status=$?
printf '\nOPENCODE_INSTALLER_EXIT=%s\n' "$installer_status"
exit "$installer_status"
EOF
    chmod +x "$temporary_directory/run-installer.sh"
    if [[ "$scenario" == current ]]; then
      printf '\033[B\n\n\n\n \n' | HOME="$home_directory" XDG_CONFIG_HOME="$xdg_directory" TMPDIR="$temporary_directory" /usr/bin/script -q "$session_log" "$temporary_directory/run-installer.sh" >/dev/null
    else
      printf '\033[A\n%s\n\n\n\n \n' "$selected_project" | HOME="$home_directory" XDG_CONFIG_HOME="$xdg_directory" TMPDIR="$temporary_directory" /usr/bin/script -q "$session_log" "$temporary_directory/run-installer.sh" >/dev/null
    fi
    if ! sed 's/\r$//' "$session_log" | grep -Eq '^OPENCODE_INSTALLER_EXIT=[1-9][0-9]*$'; then
      printf '[FAIL] %s: installer accepted %s direct project JSON\n' "$scenario" "$config_file"
      test_status=1
    fi
    if ! grep -Fq "$config_file" "$session_log" || ! grep -Fq 'architect-reviewer' "$session_log"; then
      printf '[FAIL] %s: diagnostic omitted the config path or identity\n' "$scenario"
      test_status=1
    fi
    if ! cmp -s "$temporary_directory/expected-config" "$config_file"; then
      printf '[FAIL] %s: conflicting JSON changed\n' "$scenario"
      test_status=1
    fi
    if [[ -e "$selected_base/agents" || -L "$selected_base/agents" || -e "$selected_base/agents.LICENSE" || -L "$selected_base/agents.LICENSE" ]]; then
      printf '[FAIL] %s: bundle files were written\n' "$scenario"
      test_status=1
    fi
  done
  return "$test_status"
}

test_opencode_installer_rejects_relevant_jsonc() {
  local scenario fixture_root invocation_directory project_directory selected_project home_directory xdg_directory temporary_directory config_file selected_base session_log test_status=0
  for scenario in user current-direct current-dot selected-direct selected-dot coexist; do
    fixture_root="$(mktemp -d "$ELELEM_TEST_ROOT/jsonc-$scenario.XXXXXX")"
    invocation_directory="$fixture_root/invocation"
    project_directory="$fixture_root/project"
    selected_project="$project_directory/selected"
    home_directory="$fixture_root/home"
    xdg_directory="$fixture_root/xdg"
    temporary_directory="$fixture_root/tmp"
    session_log="$fixture_root/session.log"
    mkdir -p "$invocation_directory" "$selected_project" "$home_directory" "$xdg_directory" "$temporary_directory"
    ln -s "$repository_root/install-opencode.sh" "$invocation_directory/install-opencode.sh"
    ln -s "$repository_root/_install-common.sh" "$invocation_directory/_install-common.sh"
    cp -R "$repository_root/rules" "$invocation_directory/rules"
    cp -R "$repository_root/skills" "$invocation_directory/skills"
    cp -R "$repository_root/agents" "$invocation_directory/agents"
    selected_base="$selected_project/.opencode"
    case "$scenario" in
      user|coexist) config_file="$home_directory/.config/opencode/opencode.jsonc" ;;
      current-direct) config_file="$project_directory/opencode.jsonc" ;;
      current-dot) config_file="$project_directory/.opencode/opencode.jsonc" ;;
      selected-direct) config_file="$selected_project/opencode.jsonc" ;;
      selected-dot) config_file="$selected_project/.opencode/opencode.jsonc" ;;
    esac
    mkdir -p "$(dirname "$config_file")"
    printf '{ // preserved JSONC\n "agents": {}\n}\n' > "$config_file"
    cp "$config_file" "$temporary_directory/expected-config"
    if [[ "$scenario" == coexist ]]; then
      printf '{"agents":{}}\n' > "${config_file%c}"
      cp "${config_file%c}" "$temporary_directory/expected-json"
    fi
    cat > "$temporary_directory/run-installer.sh" <<'EOF'
#!/usr/bin/env bash
fixture_directory="$(cd "$(dirname "$0")/.." && pwd)"
cd "$fixture_directory/project" || exit 1
"$fixture_directory/invocation/install-opencode.sh"
installer_status=$?
printf '\nOPENCODE_INSTALLER_EXIT=%s\n' "$installer_status"
exit "$installer_status"
EOF
    chmod +x "$temporary_directory/run-installer.sh"
    printf '\033[A\n%s\n\n\n\n \n' "$selected_project" | HOME="$home_directory" XDG_CONFIG_HOME="$xdg_directory" TMPDIR="$temporary_directory" /usr/bin/script -q "$session_log" "$temporary_directory/run-installer.sh" >/dev/null
    if ! sed 's/\r$//' "$session_log" | grep -Eq '^OPENCODE_INSTALLER_EXIT=[1-9][0-9]*$'; then
      printf '[FAIL] %s: installer accepted JSONC at %s\n' "$scenario" "$config_file"
      test_status=1
    fi
    if ! grep -Fq "$config_file" "$session_log" || ! grep -Eiq 'convert|remove|deselect' "$session_log"; then
      printf '[FAIL] %s: JSONC diagnostic omitted its path or remediation\n' "$scenario"
      test_status=1
    fi
    if ! cmp -s "$temporary_directory/expected-config" "$config_file" || { [[ "$scenario" == coexist ]] && ! cmp -s "$temporary_directory/expected-json" "${config_file%c}"; }; then
      printf '[FAIL] %s: config bytes changed\n' "$scenario"
      test_status=1
    fi
    if [[ -e "$selected_base/agents" || -L "$selected_base/agents" || -e "$selected_base/agents.LICENSE" || -L "$selected_base/agents.LICENSE" ]]; then
      printf '[FAIL] %s: bundle files were written\n' "$scenario"
      test_status=1
    fi
  done
  return "$test_status"
}

test_opencode_installer_rejects_conflicting_or_invalid_json_declarations() {
  local scenario fixture_root invocation_directory project_directory home_directory xdg_directory temporary_directory config_file selected_base session_log content test_status=0
  for scenario in native-project native-user both-legacy both-native invalid-legacy invalid-native multiple-roots empty-root array-root; do
    fixture_root="$(mktemp -d "$ELELEM_TEST_ROOT/json-declarations-$scenario.XXXXXX")"
    invocation_directory="$fixture_root/invocation"
    project_directory="$fixture_root/project"
    home_directory="$fixture_root/home"
    xdg_directory="$fixture_root/xdg"
    temporary_directory="$fixture_root/tmp"
    session_log="$fixture_root/session.log"
    mkdir -p "$invocation_directory" "$project_directory" "$home_directory" "$xdg_directory" "$temporary_directory"
    ln -s "$repository_root/install-opencode.sh" "$invocation_directory/install-opencode.sh"
    ln -s "$repository_root/_install-common.sh" "$invocation_directory/_install-common.sh"
    cp -R "$repository_root/rules" "$invocation_directory/rules"
    cp -R "$repository_root/skills" "$invocation_directory/skills"
    cp -R "$repository_root/agents" "$invocation_directory/agents"
    if [[ "$scenario" == native-user ]]; then
      config_file="$home_directory/.config/opencode/opencode.json"
      selected_base="$project_directory/.opencode"
    else
      config_file="$project_directory/.opencode/opencode.json"
      selected_base="$home_directory/.config/opencode"
    fi
    case "$scenario" in
      native-project|native-user) content='{"agents":{"architect-reviewer":{}}}' ;;
      both-legacy) content='{"agent":{"architect-reviewer":{}},"agents":{}}' ;;
      both-native) content='{"agent":{},"agents":{"architect-reviewer":{}}}' ;;
      invalid-legacy) content='{"agent":null}' ;;
      invalid-native) content='{"agents":[]}' ;;
      multiple-roots) content='{} {}' ;;
      empty-root) content='' ;;
      array-root) content='[]' ;;
    esac
    mkdir -p "$(dirname "$config_file")"
    printf '%s\n' "$content" > "$config_file"
    cp "$config_file" "$temporary_directory/expected-config"
    cat > "$temporary_directory/run-installer.sh" <<'EOF'
#!/usr/bin/env bash
fixture_directory="$(cd "$(dirname "$0")/.." && pwd)"
cd "$fixture_directory/project" || exit 1
"$fixture_directory/invocation/install-opencode.sh"
installer_status=$?
printf '\nOPENCODE_INSTALLER_EXIT=%s\n' "$installer_status"
exit "$installer_status"
EOF
    chmod +x "$temporary_directory/run-installer.sh"
    if [[ "$scenario" == native-user ]]; then
      printf '\033[A\n%s\n\n\n\n \n' "$project_directory" | HOME="$home_directory" XDG_CONFIG_HOME="$xdg_directory" TMPDIR="$temporary_directory" /usr/bin/script -q "$session_log" "$temporary_directory/run-installer.sh" >/dev/null
    else
      printf '\033[B\n\n\n\n \n' | HOME="$home_directory" XDG_CONFIG_HOME="$xdg_directory" TMPDIR="$temporary_directory" /usr/bin/script -q "$session_log" "$temporary_directory/run-installer.sh" >/dev/null
    fi
    if ! sed 's/\r$//' "$session_log" | grep -Eq '^OPENCODE_INSTALLER_EXIT=[1-9][0-9]*$'; then
      printf '[FAIL] %s: installer accepted invalid or conflicting JSON\n' "$scenario"
      test_status=1
    fi
    if ! grep -Fq "$config_file" "$session_log"; then
      printf '[FAIL] %s: diagnostic omitted config path\n' "$scenario"
      test_status=1
    fi
    case "$scenario" in
      native-project|native-user|both-legacy|both-native)
        if ! grep -Fq 'architect-reviewer' "$session_log"; then
          printf '[FAIL] %s: diagnostic omitted agent identity\n' "$scenario"
          test_status=1
        fi ;;
      *)
        if ! grep -Fq 'cannot inspect JSON agent declarations' "$session_log"; then
          printf '[FAIL] %s: diagnostic omitted invalid JSON reason\n' "$scenario"
          test_status=1
        fi ;;
    esac
    if ! cmp -s "$temporary_directory/expected-config" "$config_file"; then
      printf '[FAIL] %s: config bytes changed\n' "$scenario"
      test_status=1
    fi
    if [[ -e "$selected_base/agents" || -L "$selected_base/agents" || -e "$selected_base/agents.LICENSE" || -L "$selected_base/agents.LICENSE" ]]; then
      printf '[FAIL] %s: bundle files were written\n' "$scenario"
      test_status=1
    fi
  done
  return "$test_status"
}

test_opencode_installer_blocks_conflicts_in_symlinked_agent_roots() {
  local scenario fixture_root invocation_directory project_directory home_directory xdg_directory temporary_directory agent_root real_root agent_file selected_base session_log test_status=0
  for scenario in current-project user; do
    fixture_root="$(mktemp -d "$ELELEM_TEST_ROOT/symlinked-agent-root-$scenario.XXXXXX")"
    invocation_directory="$fixture_root/invocation"
    project_directory="$fixture_root/project"
    home_directory="$fixture_root/home"
    xdg_directory="$fixture_root/xdg"
    temporary_directory="$fixture_root/tmp"
    session_log="$fixture_root/session.log"
    mkdir -p "$invocation_directory" "$project_directory" "$home_directory" "$xdg_directory" "$temporary_directory"
    ln -s "$repository_root/install-opencode.sh" "$invocation_directory/install-opencode.sh"
    ln -s "$repository_root/_install-common.sh" "$invocation_directory/_install-common.sh"
    cp -R "$repository_root/rules" "$invocation_directory/rules"
    cp -R "$repository_root/skills" "$invocation_directory/skills"
    cp -R "$repository_root/agents" "$invocation_directory/agents"
    if [[ "$scenario" == current-project ]]; then
      agent_root="$project_directory/.opencode/agents"
      real_root="$project_directory/other-agents"
      selected_base="$home_directory/.config/opencode"
    else
      agent_root="$home_directory/.config/opencode/agents"
      real_root="$home_directory/other-agents"
      selected_base="$project_directory/.opencode"
    fi
    mkdir -p "$(dirname "$agent_root")" "$real_root"
    ln -s "$real_root" "$agent_root"
    agent_file="$agent_root/architect-reviewer.md"
    printf 'Preserve conflicting agent bytes.\n' > "$agent_file"
    cp "$agent_file" "$temporary_directory/expected-agent"
    cat > "$temporary_directory/run-installer.sh" <<'EOF'
#!/usr/bin/env bash
fixture_directory="$(cd "$(dirname "$0")/.." && pwd)"
cd "$fixture_directory/project" || exit 1
"$fixture_directory/invocation/install-opencode.sh"
installer_status=$?
printf '\nOPENCODE_INSTALLER_EXIT=%s\n' "$installer_status"
exit "$installer_status"
EOF
    chmod +x "$temporary_directory/run-installer.sh"
    if [[ "$scenario" == current-project ]]; then
      printf '\033[B\n\n\n\n \n' | HOME="$home_directory" XDG_CONFIG_HOME="$xdg_directory" TMPDIR="$temporary_directory" /usr/bin/script -q "$session_log" "$temporary_directory/run-installer.sh" >/dev/null
    else
      printf '\033[A\n%s\n\n\n\n \n' "$project_directory" | HOME="$home_directory" XDG_CONFIG_HOME="$xdg_directory" TMPDIR="$temporary_directory" /usr/bin/script -q "$session_log" "$temporary_directory/run-installer.sh" >/dev/null
    fi
    if ! sed 's/\r$//' "$session_log" | grep -Eq '^OPENCODE_INSTALLER_EXIT=[1-9][0-9]*$'; then
      printf '[FAIL] %s: installer accepted a symlinked-root agent conflict\n' "$scenario"
      test_status=1
    fi
    if ! grep -Fq "$agent_file" "$session_log" || ! grep -Fq 'architect-reviewer' "$session_log"; then
      printf '[FAIL] %s: diagnostic omitted agent path or identity\n' "$scenario"
      test_status=1
    fi
    if ! cmp -s "$temporary_directory/expected-agent" "$agent_file"; then
      printf '[FAIL] %s: conflicting agent bytes changed\n' "$scenario"
      test_status=1
    fi
    if [[ -e "$selected_base/agents" || -L "$selected_base/agents" || -e "$selected_base/agents.LICENSE" || -L "$selected_base/agents.LICENSE" ]]; then
      printf '[FAIL] %s: bundle files were written\n' "$scenario"
      test_status=1
    fi
  done
  return "$test_status"
}

test_opencode_installer_inspects_overlapping_config_paths_once() {
  local fixture_root invocation_directory project_directory home_directory xdg_directory temporary_directory bin_directory session_log inspections
  fixture_root="$(mktemp -d "$ELELEM_TEST_ROOT/overlapping-config-paths.XXXXXX")"
  invocation_directory="$fixture_root/invocation"
  project_directory="$fixture_root/project"
  home_directory="$fixture_root/home"
  xdg_directory="$fixture_root/xdg"
  temporary_directory="$fixture_root/tmp"
  bin_directory="$fixture_root/bin"
  session_log="$fixture_root/session.log"
  inspections="$temporary_directory/inspections"
  mkdir -p "$invocation_directory" "$project_directory/.opencode" "$home_directory" "$xdg_directory" "$temporary_directory" "$bin_directory"
  ln -s "$repository_root/install-opencode.sh" "$invocation_directory/install-opencode.sh"
  ln -s "$repository_root/_install-common.sh" "$invocation_directory/_install-common.sh"
  cp -R "$repository_root/rules" "$invocation_directory/rules"
  cp -R "$repository_root/skills" "$invocation_directory/skills"
  cp -R "$repository_root/agents" "$invocation_directory/agents"
  printf '{"agent":{}}\n' > "$project_directory/.opencode/opencode.json"
  cat > "$bin_directory/jq" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == -se ]]; then
  printf '%s\n' "$*" >> "$INSPECTIONS"
fi
exec /usr/bin/jq "$@"
EOF
  chmod +x "$bin_directory/jq"
  cat > "$temporary_directory/run-installer.sh" <<'EOF'
#!/usr/bin/env bash
fixture_directory="$(cd "$(dirname "$0")/.." && pwd)"
cd "$fixture_directory/project" || exit 1
"$fixture_directory/invocation/install-opencode.sh"
installer_status=$?
printf '\nOPENCODE_INSTALLER_EXIT=%s\n' "$installer_status"
exit "$installer_status"
EOF
  chmod +x "$temporary_directory/run-installer.sh"
  printf '\033[A\n%s/.\n\n\n\n \n' "$project_directory" | HOME="$home_directory" XDG_CONFIG_HOME="$xdg_directory" TMPDIR="$temporary_directory" INSPECTIONS="$inspections" PATH="$bin_directory:$PATH" /usr/bin/script -q "$session_log" "$temporary_directory/run-installer.sh" >/dev/null
  if ! sed 's/\r$//' "$session_log" | grep -Fqx 'OPENCODE_INSTALLER_EXIT=0'; then
    printf '[FAIL] overlapping config paths: installer did not exit successfully\n'
    return 1
  fi
  if [[ ! -f "$inspections" ]] || [[ "$(wc -l < "$inspections" | tr -d '[:space:]')" != 1 ]]; then
    printf '[FAIL] overlapping config paths: same config was inspected more than once\n'
    return 1
  fi
  return 0
}

test_opencode_installer_prompts_for_canonical_agent_via_aliased_project_path() {
  local fixture_root invocation_directory project_directory home_directory xdg_directory temporary_directory session_log agent_file
  fixture_root="$(mktemp -d "$ELELEM_TEST_ROOT/aliased-canonical-agent.XXXXXX")"
  invocation_directory="$fixture_root/invocation"
  project_directory="$fixture_root/project"
  home_directory="$fixture_root/home"
  xdg_directory="$fixture_root/xdg"
  temporary_directory="$fixture_root/tmp"
  session_log="$fixture_root/session.log"
  agent_file="$project_directory/.opencode/agents/architect-reviewer.md"
  mkdir -p "$invocation_directory" "$(dirname "$agent_file")" "$home_directory" "$xdg_directory" "$temporary_directory"
  ln -s "$repository_root/install-opencode.sh" "$invocation_directory/install-opencode.sh"
  ln -s "$repository_root/_install-common.sh" "$invocation_directory/_install-common.sh"
  cp -R "$repository_root/rules" "$invocation_directory/rules"
  cp -R "$repository_root/skills" "$invocation_directory/skills"
  cp -R "$repository_root/agents" "$invocation_directory/agents"
  printf 'Preserve canonical agent bytes.\n' > "$agent_file"
  cp "$agent_file" "$temporary_directory/expected-agent"
  cat > "$temporary_directory/run-installer.sh" <<'EOF'
#!/usr/bin/env bash
fixture_directory="$(cd "$(dirname "$0")/.." && pwd)"
cd "$fixture_directory/project" || exit 1
"$fixture_directory/invocation/install-opencode.sh"
installer_status=$?
printf '\nOPENCODE_INSTALLER_EXIT=%s\n' "$installer_status"
exit "$installer_status"
EOF
  chmod +x "$temporary_directory/run-installer.sh"
  printf '\033[A\n%s/.\n\n\n\n \nn\n' "$project_directory" | HOME="$home_directory" XDG_CONFIG_HOME="$xdg_directory" TMPDIR="$temporary_directory" /usr/bin/script -q "$session_log" "$temporary_directory/run-installer.sh" >/dev/null
  if ! sed 's/\r$//' "$session_log" | grep -Fqx 'OPENCODE_INSTALLER_EXIT=0'; then
    printf '[FAIL] aliased canonical agent: installer rejected its selected target\n'
    return 1
  fi
  if ! grep -Fq "Replace existing agent 'architect-reviewer.md'? [y/n]" "$session_log"; then
    printf '[FAIL] aliased canonical agent: replacement prompt was not displayed\n'
    return 1
  fi
  if ! cmp -s "$temporary_directory/expected-agent" "$agent_file"; then
    printf '[FAIL] aliased canonical agent: refused agent bytes changed\n'
    return 1
  fi
  return 0
}

test_opencode_installer_fails_closed_when_a_markdown_agent_root_has_an_inaccessible_ancestor() {
  local fixture_root invocation_directory project_directory home_directory xdg_directory temporary_directory session_log agent_root agent_file original_mode restored_mode script_status test_status=0
  fixture_root="$(mktemp -d "$ELELEM_TEST_ROOT/inaccessible-markdown-ancestor.XXXXXX")"
  invocation_directory="$fixture_root/invocation"
  project_directory="$fixture_root/project"
  home_directory="$fixture_root/home"
  xdg_directory="$fixture_root/xdg"
  temporary_directory="$fixture_root/tmp"
  session_log="$fixture_root/session.log"
  agent_root="$project_directory/.opencode/agents"
  agent_file="$agent_root/architect-reviewer.md"
  mkdir -p "$invocation_directory" "$agent_root" "$home_directory" "$xdg_directory" "$temporary_directory"
  ln -s "$repository_root/install-opencode.sh" "$invocation_directory/install-opencode.sh"
  ln -s "$repository_root/_install-common.sh" "$invocation_directory/_install-common.sh"
  cp -R "$repository_root/rules" "$invocation_directory/rules"
  cp -R "$repository_root/skills" "$invocation_directory/skills"
  cp -R "$repository_root/agents" "$invocation_directory/agents"
  printf 'Preserve inaccessible conflicting agent bytes.\n' > "$agent_file"
  cp "$agent_file" "$temporary_directory/expected-agent"
  cat > "$temporary_directory/run-installer.sh" <<'EOF'
#!/usr/bin/env bash
fixture_directory="$(cd "$(dirname "$0")/.." && pwd)"
cd "$fixture_directory/project" || exit 1
"$fixture_directory/invocation/install-opencode.sh"
installer_status=$?
printf '\nOPENCODE_INSTALLER_EXIT=%s\n' "$installer_status"
exit "$installer_status"
EOF
  chmod +x "$temporary_directory/run-installer.sh"
  original_mode="$(stat -f '%Lp' "$project_directory/.opencode")"
  chmod 000 "$project_directory/.opencode"
  if [[ -r "$project_directory/.opencode" || -x "$project_directory/.opencode" ]]; then
    printf '[FAIL] inaccessible Markdown ancestor: permissions did not prevent access\n'
    test_status=1
  fi
  printf '\033[B\n\n\n\n \n' | HOME="$home_directory" XDG_CONFIG_HOME="$xdg_directory" TMPDIR="$temporary_directory" /usr/bin/script -q "$session_log" "$temporary_directory/run-installer.sh" >/dev/null
  script_status=$?
  chmod "$original_mode" "$project_directory/.opencode"
  restored_mode="$(stat -f '%Lp' "$project_directory/.opencode")"
  printf 'original_mode=%s\nrestored_mode=%s\nscript_status=%s\n' "$original_mode" "$restored_mode" "$script_status" > "$fixture_root/mode-restoration.txt"
  if [[ "$restored_mode" != "$original_mode" ]]; then
    printf '[FAIL] inaccessible Markdown ancestor: original mode was not restored\n'
    test_status=1
  fi
  if ! sed 's/\r$//' "$session_log" | grep -Eq '^OPENCODE_INSTALLER_EXIT=[1-9][0-9]*$'; then
    printf '[FAIL] inaccessible Markdown ancestor: installer did not exit with a positive status\n'
    test_status=1
  fi
  if ! grep -Fq "failed to enumerate Markdown agents in '$agent_root'" "$session_log"; then
    printf '[FAIL] inaccessible Markdown ancestor: enumeration diagnostic omitted the agent root\n'
    test_status=1
  fi
  if ! cmp -s "$temporary_directory/expected-agent" "$agent_file"; then
    printf '[FAIL] inaccessible Markdown ancestor: competing agent bytes changed\n'
    test_status=1
  fi
  if [[ -e "$home_directory/.config/opencode/agents" || -L "$home_directory/.config/opencode/agents" || -e "$home_directory/.config/opencode/agents.LICENSE" || -L "$home_directory/.config/opencode/agents.LICENSE" ]]; then
    printf '[FAIL] inaccessible Markdown ancestor: user bundle files were written\n'
    test_status=1
  fi
  return "$test_status"
}

test_opencode_installer_fails_closed_when_a_markdown_agent_root_cannot_be_enumerated() {
  local fixture_root invocation_directory project_directory home_directory xdg_directory temporary_directory session_log agent_root agent_file original_mode restored_mode find_status script_status test_status=0
  fixture_root="$(mktemp -d "$ELELEM_TEST_ROOT/unreadable-markdown-root.XXXXXX")"
  invocation_directory="$fixture_root/invocation"
  project_directory="$fixture_root/project"
  home_directory="$fixture_root/home"
  xdg_directory="$fixture_root/xdg"
  temporary_directory="$fixture_root/tmp"
  session_log="$fixture_root/session.log"
  agent_root="$project_directory/.opencode/agents"
  agent_file="$agent_root/architect-reviewer.md"
  mkdir -p "$invocation_directory" "$agent_root" "$home_directory" "$xdg_directory" "$temporary_directory"
  ln -s "$repository_root/install-opencode.sh" "$invocation_directory/install-opencode.sh"
  ln -s "$repository_root/_install-common.sh" "$invocation_directory/_install-common.sh"
  cp -R "$repository_root/rules" "$invocation_directory/rules"
  cp -R "$repository_root/skills" "$invocation_directory/skills"
  cp -R "$repository_root/agents" "$invocation_directory/agents"
  printf 'Preserve conflicting agent bytes during enumeration failure.\n' > "$agent_file"
  cp "$agent_file" "$temporary_directory/expected-agent"
  cat > "$temporary_directory/run-installer.sh" <<'EOF'
#!/usr/bin/env bash
fixture_directory="$(cd "$(dirname "$0")/.." && pwd)"
cd "$fixture_directory/project" || exit 1
"$fixture_directory/invocation/install-opencode.sh"
installer_status=$?
printf '\nOPENCODE_INSTALLER_EXIT=%s\n' "$installer_status"
exit "$installer_status"
EOF
  chmod +x "$temporary_directory/run-installer.sh"
  original_mode="$(stat -f '%Lp' "$agent_root")"
  chmod 0300 "$agent_root"
  if [[ -r "$agent_root" || ! -x "$agent_root" || ! -d "$agent_root" ]]; then
    chmod "$original_mode" "$agent_root"
    printf '[FAIL] unreadable Markdown root: invalid permission setup\n'
    return 1
  fi
  if /usr/bin/find "$agent_root" -maxdepth 1 -name architect-reviewer.md -print -quit > "$fixture_root/find-probe.stdout" 2> "$fixture_root/find-probe.stderr"; then
    find_status=0
  else
    find_status=$?
  fi
  printf '%s\n' "$find_status" > "$fixture_root/find-probe.status"
  if [[ "$find_status" -eq 0 ]]; then
    chmod "$original_mode" "$agent_root"
    printf '[FAIL] unreadable Markdown root: real find probe unexpectedly succeeded\n'
    return 1
  fi
  if printf '\033[B\n\n\n\n \n' | HOME="$home_directory" XDG_CONFIG_HOME="$xdg_directory" TMPDIR="$temporary_directory" /usr/bin/script -q "$session_log" "$temporary_directory/run-installer.sh" >/dev/null; then
    script_status=0
  else
    script_status=$?
  fi
  chmod "$original_mode" "$agent_root"
  restored_mode="$(stat -f '%Lp' "$agent_root")"
  printf 'original_mode=%s\nrestored_mode=%s\nfind_status=%s\nscript_status=%s\n' "$original_mode" "$restored_mode" "$find_status" "$script_status" > "$fixture_root/mode-restoration.txt"
  if [[ "$restored_mode" != "$original_mode" ]]; then
    printf '[FAIL] unreadable Markdown root: original mode was not restored\n'
    test_status=1
  fi
  if ! sed 's/\r$//' "$session_log" | grep -Eq '^OPENCODE_INSTALLER_EXIT=[1-9][0-9]*$'; then
    printf '[FAIL] unreadable Markdown root: installer did not exit with a positive status\n'
    test_status=1
  fi
  if ! grep -Fq "failed to enumerate Markdown agents in '$agent_root'" "$session_log"; then
    printf '[FAIL] unreadable Markdown root: enumeration diagnostic omitted the agent root\n'
    test_status=1
  fi
  if ! cmp -s "$temporary_directory/expected-agent" "$agent_file"; then
    printf '[FAIL] unreadable Markdown root: competing agent bytes changed\n'
    test_status=1
  fi
  if [[ -e "$home_directory/.config/opencode/agents" || -L "$home_directory/.config/opencode/agents" || -e "$home_directory/.config/opencode/agents.LICENSE" || -L "$home_directory/.config/opencode/agents.LICENSE" ]]; then
    printf '[FAIL] unreadable Markdown root: user bundle files were written\n'
    test_status=1
  fi
  return "$test_status"
}

test_opencode_installer_ignores_a_conflicting_agent_below_a_descendant_directory_symlink() {
  local fixture_root invocation_directory project_directory home_directory xdg_directory temporary_directory session_log agent_root linked_directory target_directory source_file filename test_status=0
  fixture_root="$(mktemp -d "$ELELEM_TEST_ROOT/descendant-agent-symlink.XXXXXX")"
  invocation_directory="$fixture_root/invocation"
  project_directory="$fixture_root/project"
  home_directory="$fixture_root/home"
  xdg_directory="$fixture_root/xdg"
  temporary_directory="$fixture_root/tmp"
  session_log="$fixture_root/session.log"
  agent_root="$project_directory/.opencode/agents"
  linked_directory="$agent_root/other-agents"
  target_directory="$project_directory/other-agents"
  mkdir -p "$invocation_directory" "$agent_root" "$target_directory" "$home_directory" "$xdg_directory" "$temporary_directory"
  ln -s "$repository_root/install-opencode.sh" "$invocation_directory/install-opencode.sh"
  ln -s "$repository_root/_install-common.sh" "$invocation_directory/_install-common.sh"
  cp -R "$repository_root/rules" "$invocation_directory/rules"
  cp -R "$repository_root/skills" "$invocation_directory/skills"
  cp -R "$repository_root/agents" "$invocation_directory/agents"
  printf 'Preserve nested competing agent bytes.\n' > "$target_directory/architect-reviewer.md"
  cp "$target_directory/architect-reviewer.md" "$temporary_directory/expected-agent"
  ln -s "$target_directory" "$linked_directory"
  cat > "$temporary_directory/run-installer.sh" <<'EOF'
#!/usr/bin/env bash
fixture_directory="$(cd "$(dirname "$0")/.." && pwd)"
cd "$fixture_directory/project" || exit 1
"$fixture_directory/invocation/install-opencode.sh"
installer_status=$?
printf '\nOPENCODE_INSTALLER_EXIT=%s\n' "$installer_status"
exit "$installer_status"
EOF
  chmod +x "$temporary_directory/run-installer.sh"
  printf '\033[B\n\n\n\n \n' | HOME="$home_directory" XDG_CONFIG_HOME="$xdg_directory" TMPDIR="$temporary_directory" /usr/bin/script -q "$session_log" "$temporary_directory/run-installer.sh" >/dev/null
  if ! sed 's/\r$//' "$session_log" | grep -Fqx 'OPENCODE_INSTALLER_EXIT=0'; then
    printf '[FAIL] descendant agent symlink: installer did not exit successfully\n'
    test_status=1
  fi
  for source_file in "$invocation_directory/agents/opencode/"*.md; do
    filename="$(basename "$source_file")"
    if ! cmp -s "$source_file" "$home_directory/.config/opencode/agents/$filename"; then
      printf '[FAIL] descendant agent symlink: bundled agent %s was not installed\n' "$filename"
      test_status=1
    fi
  done
  if ! cmp -s "$invocation_directory/agents/LICENSE" "$home_directory/.config/opencode/agents.LICENSE"; then
    printf '[FAIL] descendant agent symlink: bundle notice was not installed\n'
    test_status=1
  fi
  if [[ ! -L "$linked_directory" || "$(readlink "$linked_directory")" != "$target_directory" ]]; then
    printf '[FAIL] descendant agent symlink: directory symlink changed\n'
    test_status=1
  fi
  if ! cmp -s "$temporary_directory/expected-agent" "$target_directory/architect-reviewer.md"; then
    printf '[FAIL] descendant agent symlink: target agent bytes changed\n'
    test_status=1
  fi
  return "$test_status"
}

passed_cases=0
failed_cases=0

run_case() {
  local case_name="$1"
  shift

  if "$@"; then
    printf '[PASS] %s\n' "$case_name"
    passed_cases=$((passed_cases + 1))
  else
    printf '[FAIL] %s\n' "$case_name"
    failed_cases=$((failed_cases + 1))
  fi
}

run_case test_opencode_installer_offers_the_default_off_agent_bundle_choice test_opencode_installer_offers_the_default_off_agent_bundle_choice
run_case test_opencode_installer_installs_the_complete_agent_bundle_at_the_selected_scope test_opencode_installer_installs_the_complete_agent_bundle_at_the_selected_scope
run_case test_opencode_installer_preserves_tracked_agents_when_bundle_is_deselected test_opencode_installer_preserves_tracked_agents_when_bundle_is_deselected
run_case test_opencode_installer_rejects_a_manifest_base_change_before_writes test_opencode_installer_rejects_a_manifest_base_change_before_writes
run_case test_opencode_installer_blocks_a_current_project_markdown_agent_conflict_before_bundle_writes test_opencode_installer_blocks_a_current_project_markdown_agent_conflict_before_bundle_writes
run_case test_opencode_installer_blocks_a_user_markdown_agent_conflict_before_project_bundle_writes test_opencode_installer_blocks_a_user_markdown_agent_conflict_before_project_bundle_writes
run_case test_opencode_installer_blocks_json_agent_declarations_before_bundle_writes test_opencode_installer_blocks_json_agent_declarations_before_bundle_writes
run_case test_opencode_installer_fails_closed_when_a_json_identity_query_cannot_be_completed test_opencode_installer_fails_closed_when_a_json_identity_query_cannot_be_completed
run_case test_opencode_installer_fails_closed_when_relevant_json_cannot_be_inspected test_opencode_installer_fails_closed_when_relevant_json_cannot_be_inspected
run_case test_opencode_installer_reports_bundle_changes_when_manifest_write_fails test_opencode_installer_reports_bundle_changes_when_manifest_write_fails
run_case test_opencode_installer_reports_bundle_changes_when_manifest_pruning_fails test_opencode_installer_reports_bundle_changes_when_manifest_pruning_fails
run_case test_opencode_installer_replaces_a_canonical_agent_after_confirmation test_opencode_installer_replaces_a_canonical_agent_after_confirmation
run_case test_opencode_installer_preserves_a_managed_agent_when_replacement_is_refused test_opencode_installer_preserves_a_managed_agent_when_replacement_is_refused
run_case test_opencode_installer_preserves_an_unmanaged_agent_when_replacement_is_refused test_opencode_installer_preserves_an_unmanaged_agent_when_replacement_is_refused
run_case test_opencode_installer_refuses_a_mismatched_notice_when_replacement_is_declined test_opencode_installer_refuses_a_mismatched_notice_when_replacement_is_declined
run_case test_opencode_installer_installs_agents_after_refusing_an_exact_notice_without_claiming_it test_opencode_installer_installs_agents_after_refusing_an_exact_notice_without_claiming_it
run_case test_opencode_installer_replaces_a_mismatched_notice_after_confirmation test_opencode_installer_replaces_a_mismatched_notice_after_confirmation
run_case test_opencode_installer_blocks_direct_project_json_conflicts test_opencode_installer_blocks_direct_project_json_conflicts
run_case test_opencode_installer_rejects_relevant_jsonc test_opencode_installer_rejects_relevant_jsonc
run_case test_opencode_installer_rejects_conflicting_or_invalid_json_declarations test_opencode_installer_rejects_conflicting_or_invalid_json_declarations
run_case test_opencode_installer_blocks_conflicts_in_symlinked_agent_roots test_opencode_installer_blocks_conflicts_in_symlinked_agent_roots
run_case test_opencode_installer_inspects_overlapping_config_paths_once test_opencode_installer_inspects_overlapping_config_paths_once
run_case test_opencode_installer_prompts_for_canonical_agent_via_aliased_project_path test_opencode_installer_prompts_for_canonical_agent_via_aliased_project_path
run_case test_opencode_installer_fails_closed_when_a_markdown_agent_root_has_an_inaccessible_ancestor test_opencode_installer_fails_closed_when_a_markdown_agent_root_has_an_inaccessible_ancestor
run_case test_opencode_installer_fails_closed_when_a_markdown_agent_root_cannot_be_enumerated test_opencode_installer_fails_closed_when_a_markdown_agent_root_cannot_be_enumerated
run_case test_opencode_installer_ignores_a_conflicting_agent_below_a_descendant_directory_symlink test_opencode_installer_ignores_a_conflicting_agent_below_a_descendant_directory_symlink

printf 'Summary: %d cases, %d passed, %d failed\n' "$((passed_cases + failed_cases))" "$passed_cases" "$failed_cases"
[[ "$failed_cases" -eq 0 ]]
