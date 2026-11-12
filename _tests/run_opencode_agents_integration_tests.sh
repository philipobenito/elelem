#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
test_root="${TMPDIR:?}/preserve-opencode-agents-integration"
mkdir -p "$test_root"

prepare_installer_fixture() {
  local fixture_root="$1"
  mkdir -p "$fixture_root/invocation" "$fixture_root/project" "$fixture_root/home" "$fixture_root/xdg" "$fixture_root/tmp"
  cp "$repository_root/install-opencode.sh" "$fixture_root/invocation/install-opencode.sh"
  cp "$repository_root/uninstall.sh" "$fixture_root/invocation/uninstall.sh"
  cp "$repository_root/_install-common.sh" "$fixture_root/invocation/_install-common.sh"
  cp -R "$repository_root/rules" "$fixture_root/invocation/rules"
  cp -R "$repository_root/skills" "$fixture_root/invocation/skills"
  cp -R "$repository_root/agents" "$fixture_root/invocation/agents"
  cat > "$fixture_root/tmp/run-installer.sh" <<'RUNNER'
#!/usr/bin/env bash
fixture_root="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$fixture_root/project" || exit 1
"$fixture_root/invocation/install-opencode.sh"
RUNNER
  chmod +x "$fixture_root/tmp/run-installer.sh"
}

run_opencode_install() {
  local fixture_root="$1" session_log="$2" input="${3:-}"
  [[ -n "$input" ]] || input=$'\033[B\n\n\n\n'
  printf '%s' "$input" | HOME="$fixture_root/home" XDG_CONFIG_HOME="$fixture_root/xdg" TMPDIR="$fixture_root/tmp" TERM=dumb NO_COLOR=1 /usr/bin/script -q "$session_log" "$fixture_root/tmp/run-installer.sh" > "$fixture_root/tmp/installer-output.log" 2>&1
}

run_opencode_uninstall() {
  local fixture_root="$1" session_log="$2"
  printf ' \n \n' | HOME="$fixture_root/home" XDG_CONFIG_HOME="$fixture_root/xdg" TMPDIR="$fixture_root/tmp" TERM=dumb NO_COLOR=1 /usr/bin/script -q "$session_log" /bin/bash "$fixture_root/invocation/uninstall.sh" > "$fixture_root/tmp/uninstaller-output.log" 2>&1
}

test_uninstall_preserves_opencode_agents_content() {
  local fixture_root target session_log manifest config ownership
  fixture_root="$(mktemp -d "$test_root/uninstall.XXXXXX")"
  target="$fixture_root/home/.config/opencode/AGENTS.md"
  session_log="$fixture_root/session.log"
  manifest="$fixture_root/invocation/.elelem-manifest-opencode"
  config="$fixture_root/home/.config/opencode/opencode.json"
  ownership="$fixture_root/home/.config/opencode/.elelem-opencode-instructions.json"
  mkdir -p "$fixture_root/invocation" "$fixture_root/project" "$fixture_root/home/.config/opencode" "$fixture_root/xdg" "$fixture_root/tmp"
  cp "$repository_root/uninstall.sh" "$fixture_root/invocation/uninstall.sh"
  cp "$repository_root/_install-common.sh" "$fixture_root/invocation/_install-common.sh"
  printf 'Custom instructions must survive uninstall.\n' > "$target"
  printf '{"instructions":["personal.md","rules/common/*.md"],"model":"custom"}\n' > "$config"
  printf '{"instructions":["rules/common/*.md"]}\n' > "$ownership"
  printf '%s\n.elelem-opencode-instructions.json\n./opencode.json\n./AGENTS.md\n' "$fixture_root/home/.config/opencode" > "$manifest"
  printf ' \n \n' | HOME="$fixture_root/home" XDG_CONFIG_HOME="$fixture_root/xdg" TMPDIR="$fixture_root/tmp" TERM=dumb NO_COLOR=1 /usr/bin/script -q "$session_log" /bin/bash "$fixture_root/invocation/uninstall.sh" > "$fixture_root/tmp/uninstaller-output.log" 2>&1
  if [[ ! -f "$target" ]] || ! grep -Fqx 'Custom instructions must survive uninstall.' "$target"; then
    printf 'Uninstall deleted the OpenCode AGENTS.md file\n' >&2
    return 1
  fi
  jq -e '.instructions == ["personal.md"] and .model == "custom"' "$config" > /dev/null
  [[ ! -e "$ownership" ]]
}

test_install_rejects_an_agents_symlink_before_creating_install_files() {
  local fixture_root target linked_file session_log
  fixture_root="$(mktemp -d "$test_root/symlink-preflight.XXXXXX")"
  target="$fixture_root/home/.config/opencode/AGENTS.md"
  linked_file="$fixture_root/home/custom-instructions.md"
  session_log="$fixture_root/session.log"
  mkdir -p "$fixture_root/home/.config/opencode"
  prepare_installer_fixture "$fixture_root"
  printf 'External instructions.\n' > "$linked_file"
  ln -s "$linked_file" "$target"
  if run_opencode_install "$fixture_root" "$session_log"; then
    printf 'Installer accepted a symlinked OpenCode AGENTS.md\n' >&2
    return 1
  fi
  [[ -L "$target" ]]
  grep -Fq 'must be a regular file' "$session_log"
  [[ ! -e "$fixture_root/home/.config/opencode/rules" ]]
  [[ ! -e "$fixture_root/home/.config/opencode/opencode.json" ]]
  [[ ! -e "$fixture_root/invocation/.elelem-manifest-opencode" ]]
  grep -Fqx 'External instructions.' "$linked_file"
}

test_install_and_uninstall_reject_agents_directories_without_mutation() {
  local operation fixture_root base target config ownership manifest sentinel sentinel_entry log
  for operation in install uninstall; do
    fixture_root="$(mktemp -d "$test_root/nonregular-$operation.XXXXXX")"
    base="$fixture_root/home/.config/opencode"
    target="$base/AGENTS.md"
    config="$base/opencode.json"
    ownership="$base/.elelem-opencode-instructions.json"
    manifest="$fixture_root/invocation/.elelem-manifest-opencode"
    log="$fixture_root/$operation.session.log"
    mkdir -p "$fixture_root/invocation" "$fixture_root/project" "$base" "$fixture_root/home" "$fixture_root/xdg" "$fixture_root/tmp"
    if [[ "$operation" == install ]]; then
      prepare_installer_fixture "$fixture_root"
      sentinel="$base/installed-sentinel.md"
      sentinel_entry=installed-sentinel.md
    else
      cp "$repository_root/uninstall.sh" "$fixture_root/invocation/uninstall.sh"
      cp "$repository_root/_install-common.sh" "$fixture_root/invocation/_install-common.sh"
      mkdir -p "$base/rules/common"
      sentinel="$base/rules/common/testing.md"
      sentinel_entry=rules/common/testing.md
    fi
    mkdir -p "$target"
    printf 'User data inside the AGENTS directory.\n' > "$target/user-sentinel.md"
    printf '{"instructions":["personal.md","rules/common/*.md"],"model":"custom"}\n' > "$config"
    printf '{"instructions":["rules/common/*.md"]}\n' > "$ownership"
    printf 'Installed file sentinel for %s.\n' "$operation" > "$sentinel"
    printf '%s\n.elelem-opencode-instructions.json\nopencode.json\nAGENTS.md\n%s\n' "$base" "$sentinel_entry" > "$manifest"
    cp "$config" "$fixture_root/config.expected"
    cp "$ownership" "$fixture_root/ownership.expected"
    cp "$manifest" "$fixture_root/manifest.expected"
    cp "$target/user-sentinel.md" "$fixture_root/agents-sentinel.expected"
    cp "$sentinel" "$fixture_root/installed-sentinel.expected"
    if [[ "$operation" == install ]]; then
      if run_opencode_install "$fixture_root" "$log" $'\033[B\n'; then
        printf 'Installer accepted AGENTS.md as a directory\n' >&2
        return 1
      fi
      [[ ! -e "$base/rules" && ! -e "$base/skills" ]]
    else
      if run_opencode_uninstall "$fixture_root" "$log"; then
        printf 'Uninstaller accepted AGENTS.md as a directory\n' >&2
        return 1
      fi
    fi
    grep -Fq 'must be a regular file' "$log"
    [[ -d "$target" && -f "$target/user-sentinel.md" ]]
    cmp "$fixture_root/agents-sentinel.expected" "$target/user-sentinel.md"
    cmp "$fixture_root/config.expected" "$config"
    cmp "$fixture_root/ownership.expected" "$ownership"
    cmp "$fixture_root/manifest.expected" "$manifest"
    cmp "$fixture_root/installed-sentinel.expected" "$sentinel"
  done
}

test_user_and_project_scope_lifecycles_preserve_outside_edits_and_config_links() {
  local scope fixture_root base target config_link external_config expected session_log initial_input reinstall_input
  for scope in user project; do
    fixture_root="$(mktemp -d "$test_root/$scope-lifecycle.XXXXXX")"
    prepare_installer_fixture "$fixture_root"
    if [[ "$scope" == user ]]; then
      base="$fixture_root/home/.config/opencode"
      initial_input=$'\033[B\n\n\n\n'
      reinstall_input=$'\033[B\n \n\n\n'
    else
      base="$fixture_root/project/.opencode"
      initial_input=$'\033[A\n\n\n\n\n'
      reinstall_input=$'\033[A\n\n \n\n\n'
    fi
    mkdir -p "$base"
    target="$base/AGENTS.md"
    config_link="$base/opencode.json"
    external_config="$fixture_root/shared-opencode.json"
    expected="$fixture_root/expected.md"
    printf '{"instructions":["personal.md"],"model":"custom","permission":{"edit":"ask"}}\n' > "$external_config"
    ln -s "$external_config" "$config_link"
    printf 'Original project instructions.\n' > "$target"
    session_log="$fixture_root/first-session.log"
    run_opencode_install "$fixture_root" "$session_log" "$initial_input"
    [[ -L "$config_link" ]]
    jq -e '.model == "custom" and .permission.edit == "ask" and (.instructions | index("personal.md") != null)' "$external_config" > /dev/null
    printf 'User prefix edit.\n' | cat - "$target" > "$fixture_root/prefixed.md"
    mv "$fixture_root/prefixed.md" "$target"
    printf 'User suffix edit without newline' >> "$target"
    run_opencode_install "$fixture_root" "$fixture_root/reinstall-session.log" "$reinstall_input"
    grep -Fqx 'User prefix edit.' "$target"
    grep -Fqx 'Original project instructions.' "$target"
    grep -Fq 'User suffix edit without newline' "$target"
    ! sed -n '/<!-- elelem:opencode:start -->/,/<!-- elelem:opencode:end -->/p' "$target" | grep -Fq 'rules/common/ambiguity.md'
    sed -n '/<!-- elelem:opencode:start -->/,/<!-- elelem:opencode:end -->/p' "$target" | grep -Fq 'rules/common/coding-style.md'
    cp "$target" "$expected"
    run_opencode_install "$fixture_root" "$fixture_root/idempotent-session.log" "$reinstall_input"
    cmp "$expected" "$target"
    run_opencode_uninstall "$fixture_root" "$fixture_root/uninstall-session.log"
    printf 'User prefix edit.\nOriginal project instructions.\nUser suffix edit without newline' > "$expected"
    cmp "$expected" "$target"
    [[ -L "$config_link" ]]
    jq -e '.model == "custom" and .permission.edit == "ask" and .instructions == ["personal.md"]' "$external_config" > /dev/null
    [[ ! -e "$fixture_root/invocation/.elelem-manifest-opencode" ]]
    [[ ! -e "$base/.elelem-opencode-instructions.json" ]]
  done
}

test_uninstall_rejects_an_agents_symlink_before_config_cleanup() {
  local fixture_root target external_file config ownership manifest session_log rule_file
  fixture_root="$(mktemp -d "$test_root/uninstall-symlink-preflight.XXXXXX")"
  target="$fixture_root/home/.config/opencode/AGENTS.md"
  external_file="$fixture_root/home/custom-instructions.md"
  config="$fixture_root/home/.config/opencode/opencode.json"
  ownership="$fixture_root/home/.config/opencode/.elelem-opencode-instructions.json"
  manifest="$fixture_root/invocation/.elelem-manifest-opencode"
  session_log="$fixture_root/session.log"
  rule_file="$fixture_root/home/.config/opencode/rules/common/testing.md"
  mkdir -p "$fixture_root/invocation" "$fixture_root/project" "$(dirname "$target")" "$(dirname "$rule_file")" "$fixture_root/xdg" "$fixture_root/tmp"
  cp "$repository_root/uninstall.sh" "$fixture_root/invocation/uninstall.sh"
  cp "$repository_root/_install-common.sh" "$fixture_root/invocation/_install-common.sh"
  printf 'External instructions.\n' > "$external_file"
  cp "$external_file" "$fixture_root/external.expected"
  printf 'Tracked rule bytes.\n' > "$rule_file"
  ln -s "$external_file" "$target"
  printf '{"instructions":["personal.md","rules/common/*.md"],"model":"custom"}\n' > "$config"
  printf '{"instructions":["rules/common/*.md"]}\n' > "$ownership"
  cp "$config" "$fixture_root/config.expected"
  cp "$ownership" "$fixture_root/ownership.expected"
  cp "$rule_file" "$fixture_root/rule.expected"
  printf '%s\n.elelem-opencode-instructions.json\nopencode.json\nAGENTS.md\nrules/common/testing.md\n' "$fixture_root/home/.config/opencode" > "$manifest"
  cp "$manifest" "$fixture_root/manifest.expected"
  if printf ' \n \n' | HOME="$fixture_root/home" XDG_CONFIG_HOME="$fixture_root/xdg" TMPDIR="$fixture_root/tmp" TERM=dumb NO_COLOR=1 /usr/bin/script -q "$session_log" /bin/bash "$fixture_root/invocation/uninstall.sh" > "$fixture_root/tmp/uninstaller-output.log" 2>&1; then
    printf 'Uninstaller accepted a symlinked OpenCode AGENTS.md\n' >&2
    return 1
  fi
  grep -Fq 'must be a regular file' "$session_log"
  cmp "$fixture_root/config.expected" "$config"
  cmp "$fixture_root/ownership.expected" "$ownership"
  cmp "$fixture_root/manifest.expected" "$manifest"
  cmp "$fixture_root/external.expected" "$external_file"
  cmp "$fixture_root/rule.expected" "$rule_file"
}

test_uninstall_retries_after_staged_agents_publication_failure() {
  local fixture_root base target config ownership manifest rule_file bin_directory
  local expected_agents expected_manifest expected_ownership session_log
  fixture_root="$(mktemp -d "$test_root/uninstall-publication-retry.XXXXXX")"
  base="$fixture_root/home/.config/opencode"
  target="$base/AGENTS.md"
  config="$base/opencode.json"
  ownership="$base/.elelem-opencode-instructions.json"
  manifest="$fixture_root/invocation/.elelem-manifest-opencode"
  rule_file="$base/rules/common/testing.md"
  bin_directory="$fixture_root/bin"
  expected_agents="$fixture_root/agents.expected"
  expected_manifest="$fixture_root/manifest.expected"
  expected_ownership="$fixture_root/ownership.expected"
  session_log="$fixture_root/uninstall-failure.session.log"
  mkdir -p "$fixture_root/invocation" "$fixture_root/project" "$base/rules/common" "$fixture_root/xdg" "$fixture_root/tmp" "$bin_directory"
  cp "$repository_root/uninstall.sh" "$fixture_root/invocation/uninstall.sh"
  cp "$repository_root/_install-common.sh" "$fixture_root/invocation/_install-common.sh"
  printf 'Before managed content.\n<!-- elelem:opencode:start -->\nGenerated content.\n<!-- elelem:opencode:end -->\nAfter managed content without newline' > "$target"
  printf '{"instructions":["personal.md","rules/common/*.md"],"model":"custom"}\n' > "$config"
  printf '{"instructions":["rules/common/*.md"]}\n' > "$ownership"
  printf 'Tracked rule bytes.\n' > "$rule_file"
  printf '%s\n.elelem-opencode-instructions.json\nopencode.json\nAGENTS.md\nrules/common/testing.md\n' "$base" > "$manifest"
  cp "$target" "$expected_agents"
  cp "$manifest" "$expected_manifest"
  cp "$ownership" "$expected_ownership"
  cp "$rule_file" "$fixture_root/rule.expected"
  cat > "$bin_directory/mv" <<'MOVE'
#!/usr/bin/env bash
for argument in "$@"; do
  [[ "$argument" != */elelem-opencode-agents.* ]] || exit 1
done
exec /bin/mv "$@"
MOVE
  chmod +x "$bin_directory/mv"
  if printf ' \n \n' | PATH="$bin_directory:$PATH" HOME="$fixture_root/home" XDG_CONFIG_HOME="$fixture_root/xdg" TMPDIR="$fixture_root/tmp" TERM=dumb NO_COLOR=1 /usr/bin/script -q "$session_log" /bin/bash "$fixture_root/invocation/uninstall.sh" > "$fixture_root/tmp/uninstaller-output.log" 2>&1; then
    printf 'Uninstall succeeded despite an injected AGENTS publication failure\n' >&2
    return 1
  fi
  grep -Fq 'retry metadata retained' "$session_log"
  cmp "$expected_agents" "$target"
  cmp "$expected_manifest" "$manifest"
  cmp "$expected_ownership" "$ownership"
  cmp "$fixture_root/rule.expected" "$rule_file"
  jq -e '.instructions == ["personal.md"] and .model == "custom"' "$config" > /dev/null
  run_opencode_uninstall "$fixture_root" "$fixture_root/uninstall-retry.session.log"
  printf 'Before managed content.\nAfter managed content without newline' > "$fixture_root/agents.after-retry.expected"
  cmp "$fixture_root/agents.after-retry.expected" "$target"
  jq -e '.instructions == ["personal.md"] and .model == "custom"' "$config" > /dev/null
  [[ ! -e "$manifest" && ! -e "$ownership" && ! -e "$rule_file" ]]
}

test_install_and_uninstall_reject_malformed_markers_without_mutation() {
  local operation document_index first_document last_document fixture_root base target config ownership manifest rule_file rule_entry log document
  local -a documents=(
    '<!-- elelem:opencode:start -->\n<!-- outer <!-- elelem:opencode:end --> -->\n<!-- elelem:opencode:end -->\n'
    '<!-- elelem:opencode:end -->\n'
    '<!-- elelem:opencode:start -->\none\n<!-- elelem:opencode:end -->\n<!-- elelem:opencode:start -->\ntwo\n<!-- elelem:opencode:end -->\n'
    '<!-- elelem:opencode:end -->\n<!-- elelem:opencode:start -->\n'
    '<!-- elelem:opencode:start -->\n'
    '<!-- note <!-- elelem:opencode:start --> -->\n'
    'prefix <!-- elelem:opencode:start -->\n'
    '<!-- elelem:opencode:unexpected -->\n'
    '<!-- elelem:opencode:start\n'
    '<!-- elelem:opencode:start -->\nGenerated body.\n<!-- elelem:opencode:end -->\r'
  )
  for operation in install uninstall; do
    if [[ "$operation" == install ]]; then
      first_document=2
      last_document=${#documents[@]}
    else
      first_document=1
      last_document=1
    fi
    for (( document_index=first_document; document_index<=last_document; document_index++ )); do
      document="${documents[$((document_index - 1))]}"
      fixture_root="$(mktemp -d "$test_root/malformed-$operation.XXXXXX")"
      base="$fixture_root/home/.config/opencode"
      target="$base/AGENTS.md"
      config="$base/opencode.json"
      ownership="$base/.elelem-opencode-instructions.json"
      manifest="$fixture_root/invocation/.elelem-manifest-opencode"
      log="$fixture_root/$operation.session.log"
      mkdir -p "$fixture_root/invocation" "$fixture_root/project" "$base" "$fixture_root/home" "$fixture_root/xdg" "$fixture_root/tmp"
      if [[ "$operation" == install ]]; then
        prepare_installer_fixture "$fixture_root"
        rule_entry=installed-sentinel.md
        rule_file="$base/$rule_entry"
      else
        mkdir -p "$base/rules/common"
        rule_entry=rules/common/testing.md
        rule_file="$base/$rule_entry"
        cp "$repository_root/uninstall.sh" "$fixture_root/invocation/uninstall.sh"
        cp "$repository_root/_install-common.sh" "$fixture_root/invocation/_install-common.sh"
      fi
      printf '%b' "$document" > "$target"
      printf '{"instructions":["personal.md","rules/common/*.md"],"model":"custom"}\n' > "$config"
      printf '{"instructions":["rules/common/*.md"]}\n' > "$ownership"
      printf 'Installed rule sentinel %s %s.\n' "$operation" "$document_index" > "$rule_file"
      printf '%s\n.elelem-opencode-instructions.json\nopencode.json\nAGENTS.md\n%s\n' "$base" "$rule_entry" > "$manifest"
      cp "$target" "$fixture_root/agents.expected"
      cp "$config" "$fixture_root/config.expected"
      cp "$ownership" "$fixture_root/ownership.expected"
      cp "$manifest" "$fixture_root/manifest.expected"
      cp "$rule_file" "$fixture_root/rule.expected"
      if [[ "$operation" == install ]]; then
        if run_opencode_install "$fixture_root" "$log" $'\033[B\n'; then
          printf 'Installer accepted malformed reserved markers, case %s\n' "$document_index" >&2
          return 1
        fi
        [[ ! -e "$base/skills" && ! -e "$base/rules" ]]
      else
        if run_opencode_uninstall "$fixture_root" "$log"; then
          printf 'Uninstaller accepted malformed reserved markers, case %s\n' "$document_index" >&2
          return 1
        fi
      fi
      cmp "$fixture_root/agents.expected" "$target"
      cmp "$fixture_root/config.expected" "$config"
      cmp "$fixture_root/ownership.expected" "$ownership"
      cmp "$fixture_root/manifest.expected" "$manifest"
      cmp "$fixture_root/rule.expected" "$rule_file"
    done
  done
}

test_uninstall_preserves_opencode_agents_content
test_install_rejects_an_agents_symlink_before_creating_install_files
test_install_and_uninstall_reject_agents_directories_without_mutation
test_user_and_project_scope_lifecycles_preserve_outside_edits_and_config_links
test_uninstall_rejects_an_agents_symlink_before_config_cleanup
test_uninstall_retries_after_staged_agents_publication_failure
test_install_and_uninstall_reject_malformed_markers_without_mutation
