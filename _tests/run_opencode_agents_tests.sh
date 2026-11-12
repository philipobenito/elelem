#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
fixture_root="$(mktemp -d "${TMPDIR:?}/preserve-opencode-agents-unit.XXXXXX")"
source "$repository_root/_install-common.sh"

test_exact_static_legacy_is_replaced_during_install() {
  local case_root="$fixture_root/static-legacy"
  local target="$case_root/AGENTS.md"
  local manifest="$case_root/.elelem-manifest-opencode"
  local expected="$case_root/expected.md"
  local manifest_entries=(rules/common/testing.md rules/elelem-language-packs.md)
  mkdir -p "$case_root"
  cp "$repository_root/_tests/fixtures/opencode-agents-legacy-static.md" "$target"
  printf '%s\nAGENTS.md\n' "$case_root" > "$manifest"
  _opencode_agents_render_body manifest_entries > "$expected"
  opencode_agents_update "$target" manifest_entries "$manifest"
  if ! cmp -s "$expected" "$target"; then
    printf 'Exact manifest-owned static legacy AGENTS.md was not replaced\n' >&2
    return 1
  fi
}

test_reinstall_preserves_the_end_marker_terminator_style() {
  local case_root="$fixture_root/mixed-line-endings"
  local target="$case_root/AGENTS.md"
  local body="$case_root/body.md"
  local expected="$case_root/expected.md"
  local manifest_entries=(rules/common/testing.md)
  mkdir -p "$case_root"
  _opencode_agents_render_body manifest_entries > "$body"
  {
    printf 'prefix\r\n'
    perl -0777 -pe 's/\n/\r\n/g; s/<!-- elelem:opencode:end -->\r\n/<!-- elelem:opencode:end -->\n/' "$body"
    printf 'suffix'
  } > "$expected"
  printf 'prefix\r\n<!-- elelem:opencode:start -->\r\nold body\r\n<!-- elelem:opencode:end -->\nsuffix' > "$target"
  opencode_agents_update "$target" manifest_entries
  if ! cmp -s "$expected" "$target"; then
    printf 'Reinstall changed bytes outside the managed block or its end-marker terminator style\n' >&2
    return 1
  fi
}

test_exact_historical_grouped_legacy_is_replaced_during_install() {
  local case_root="$fixture_root/historical-legacy"
  local target="$case_root/AGENTS.md"
  local manifest="$case_root/.elelem-manifest-opencode"
  local expected="$case_root/expected.md"
  local manifest_entries=(rules/common/testing.md rules/python/testing.md rules/typescript/coding-style.md)
  mkdir -p "$case_root"
  cp "$repository_root/_tests/fixtures/opencode-agents-legacy-dynamic.md" "$target"
  printf '%s\nAGENTS.md\n%s\n' "$case_root" "${manifest_entries[@]}" > "$manifest"
  _opencode_agents_render_body manifest_entries > "$expected"
  opencode_agents_update "$target" manifest_entries "$manifest"
  cmp "$expected" "$target"
}

test_exact_current_legacy_is_replaced_during_install() {
  local case_root="$fixture_root/current-legacy"
  local target="$case_root/AGENTS.md"
  local manifest="$case_root/.elelem-manifest-opencode"
  local expected="$case_root/expected.md"
  local manifest_entries=()
  mkdir -p "$case_root"
  for source_file in "$repository_root"/rules/common/*.md; do
    manifest_entries+=("rules/common/${source_file##*/}")
  done
  manifest_entries+=(rules/elelem-language-packs.md)
  cp "$repository_root/_tests/fixtures/opencode-agents-legacy-current.md" "$target"
  printf '%s\nAGENTS.md\n%s\n' "$case_root" "${manifest_entries[@]}" > "$manifest"
  _opencode_agents_render_body manifest_entries > "$expected"
  opencode_agents_update "$target" manifest_entries "$manifest"
  cmp "$expected" "$target"
}

test_owned_edited_static_legacy_is_preserved_as_unmanaged_content() {
  local case_root="$fixture_root/edited-static-legacy"
  local target="$case_root/AGENTS.md"
  local manifest="$case_root/.elelem-manifest-opencode"
  local original="$case_root/original.md"
  local manifest_entries=(rules/common/testing.md)
  mkdir -p "$case_root"
  cp "$repository_root/_tests/fixtures/opencode-agents-legacy-static.md" "$target"
  printf '\nUser edit.\n' >> "$target"
  cp "$target" "$original"
  printf '%s\nAGENTS.md\n' "$case_root" > "$manifest"
  opencode_agents_update "$target" manifest_entries "$manifest"
  tail -n "$(wc -l < "$original" | tr -d '[:space:]')" "$target" | cmp - "$original"
}

test_unmanifested_static_legacy_lookalike_is_preserved() {
  local case_root="$fixture_root/unowned-static-legacy"
  local target="$case_root/AGENTS.md"
  local expected="$case_root/expected.md"
  local original="$case_root/original.md"
  local manifest="$case_root/.elelem-manifest-opencode"
  local manifest_entries=(rules/common/testing.md)
  mkdir -p "$case_root"
  cp "$repository_root/_tests/fixtures/opencode-agents-legacy-static.md" "$target"
  cp "$target" "$original"
  printf '%s\n' "$case_root" > "$manifest"
  _opencode_agents_render_body manifest_entries > "$expected"
  cat "$original" >> "$expected"
  opencode_agents_update "$target" manifest_entries "$manifest"
  cmp "$expected" "$target"
}

test_exact_static_legacy_is_removed_without_deleting_the_file() {
  local case_root="$fixture_root/remove-static-legacy"
  local target="$case_root/AGENTS.md"
  local manifest="$case_root/.elelem-manifest-opencode"
  mkdir -p "$case_root"
  cp "$repository_root/_tests/fixtures/opencode-agents-legacy-static.md" "$target"
  printf '%s\nAGENTS.md\n' "$case_root" > "$manifest"
  opencode_agents_remove "$target" "$manifest"
  [[ -f "$target" && ! -s "$target" ]]
}

test_exact_dynamic_and_current_legacy_are_removed_without_deleting_the_file() {
  local case_root target manifest legacy_kind
  local -a manifest_entries=()
  for legacy_kind in historical current; do
    case_root="$fixture_root/remove-$legacy_kind-legacy"
    target="$case_root/AGENTS.md"
    manifest="$case_root/.elelem-manifest-opencode"
    mkdir -p "$case_root"
    manifest_entries=()
    if [[ "$legacy_kind" == historical ]]; then
      manifest_entries=(rules/common/testing.md rules/python/testing.md rules/typescript/coding-style.md)
      cp "$repository_root/_tests/fixtures/opencode-agents-legacy-dynamic.md" "$target"
    else
      for source_file in "$repository_root"/rules/common/*.md; do
        manifest_entries+=("rules/common/${source_file##*/}")
      done
      manifest_entries+=(rules/elelem-language-packs.md)
      cp "$repository_root/_tests/fixtures/opencode-agents-legacy-current.md" "$target"
    fi
    printf '%s\nAGENTS.md\n%s\n' "$case_root" "${manifest_entries[@]}" > "$manifest"
    opencode_agents_remove "$target" "$manifest"
    [[ -f "$target" && ! -s "$target" ]]
  done
}

test_unmanaged_bytes_are_restored_after_install_and_uninstall() {
  local case_root="$fixture_root/round-trip"
  local target="$case_root/AGENTS.md"
  local expected="$case_root/expected.md"
  local manifest_entries=(rules/common/testing.md)
  mkdir -p "$case_root"
  printf 'Custom bytes without a final newline' > "$target"
  cp "$target" "$expected"
  opencode_agents_update "$target" manifest_entries
  opencode_agents_remove "$target"
  cmp "$expected" "$target"
}

test_whitespace_only_remainder_is_retained_after_uninstall() {
  local case_root="$fixture_root/whitespace-remainder"
  local target="$case_root/AGENTS.md"
  local expected="$case_root/expected.md"
  local manifest_entries=(rules/common/testing.md)
  mkdir -p "$case_root"
  printf ' \r\n\t' > "$target"
  cp "$target" "$expected"
  opencode_agents_update "$target" manifest_entries
  opencode_agents_remove "$target"
  cmp "$expected" "$target"
}

test_uninstall_retains_a_file_when_no_managed_content_remains() {
  local case_root="$fixture_root/empty-remainder"
  local target="$case_root/AGENTS.md"
  local manifest_entries=(rules/common/testing.md)
  mkdir -p "$case_root"
  _opencode_agents_render_body manifest_entries > "$target"
  opencode_agents_remove "$target"
  [[ -f "$target" && ! -s "$target" ]]
}

test_uninstall_does_not_create_an_absent_agents_file() {
  local case_root="$fixture_root/absent-agents"
  mkdir -p "$case_root"
  opencode_agents_remove "$case_root/AGENTS.md"
  [[ ! -e "$case_root/AGENTS.md" && ! -L "$case_root/AGENTS.md" ]]
}

test_permission_preservation_does_not_require_bsd_stat() {
  local case_root="$fixture_root/portable-mode"
  local target="$case_root/AGENTS.md"
  local bin_directory="$case_root/bin"
  local manifest_entries=(rules/common/testing.md)
  mkdir -p "$bin_directory"
  printf 'Custom instructions.\n' > "$target"
  chmod 640 "$target"
  cat > "$bin_directory/stat" <<'STAT'
#!/usr/bin/env bash
if [[ "$1" == -f ]]; then
  touch "$ELELEM_TEST_BSD_STAT_USED"
  exit 2
fi
exec /usr/bin/stat "$@"
STAT
  chmod +x "$bin_directory/stat"
  if ! ELELEM_TEST_BSD_STAT_USED="$case_root/bsd-stat-used" PATH="$bin_directory:$PATH" opencode_agents_update "$target" manifest_entries 2> "$case_root/error.log"; then
    printf 'AGENTS permission preservation required BSD stat options\n' >&2
    return 1
  fi
  [[ ! -e "$case_root/bsd-stat-used" ]]
  [[ "$(perl -e 'my @status = stat($ARGV[0]); printf "%04o", $status[2] & 07777' "$target")" == 0640 ]]
}

test_missing_perl_reports_an_actionable_agents_error() {
  local case_root="$fixture_root/missing-perl"
  local target="$case_root/AGENTS.md"
  local bin_directory="$case_root/bin"
  local expected="$case_root/expected.md"
  local manifest_entries=(rules/common/testing.md)
  mkdir -p "$bin_directory"
  printf 'Existing instructions.\n' > "$target"
  cp "$target" "$expected"
  cat > "$bin_directory/perl" <<'PERL'
#!/usr/bin/env bash
printf 'Injected unavailable Perl boundary.\n' >&2
exit 127
PERL
  chmod +x "$bin_directory/perl"
  if PATH="$bin_directory:$PATH" opencode_agents_update "$target" manifest_entries 2> "$case_root/error.log"; then
    printf 'OpenCode AGENTS update succeeded without Perl\n' >&2
    return 1
  fi
  grep -Fq 'ensure Perl is available' "$case_root/error.log"
  cmp "$expected" "$target"
}

test_malformed_reserved_markers_are_rejected_without_changing_agents() {
  local case_root="$fixture_root/malformed-markers"
  local target="$case_root/AGENTS.md"
  local expected="$case_root/expected.md"
  local document
  local manifest_entries=(rules/common/testing.md)
  local -a documents=(
    '<!-- elelem:opencode:start -->\n<!-- elelem:opencode:start -->\n<!-- elelem:opencode:end -->\n'
  )
  mkdir -p "$case_root"
  for document in "${documents[@]}"; do
    printf '%b' "$document" > "$target"
    cp "$target" "$expected"
    if opencode_agents_update "$target" manifest_entries 2> "$case_root/error.log"; then
      printf 'Malformed reserved OpenCode marker was accepted: %s\n' "$document" >&2
      return 1
    fi
    cmp "$expected" "$target"
  done
}

test_eof_end_marker_without_a_terminator_is_supported() {
  local case_root="$fixture_root/eof-marker"
  local target="$case_root/AGENTS.md"
  local expected="$case_root/expected.md"
  local body="$case_root/body.md"
  local restored="$case_root/restored.md"
  local manifest_entries=(rules/common/testing.md)
  mkdir -p "$case_root"
  _opencode_agents_render_body manifest_entries > "$body"
  printf 'Prefix.\n' > "$expected"
  perl -0777 -pe 's/\n\z//' "$body" >> "$expected"
  printf 'Prefix.\n<!-- elelem:opencode:start -->\nOld block\n<!-- elelem:opencode:end -->' > "$target"
  opencode_agents_update "$target" manifest_entries
  cmp "$expected" "$target"
  opencode_agents_remove "$target"
  printf 'Prefix.\n' > "$restored"
  cmp "$restored" "$target"
}

test_publish_aborts_when_agents_changes_after_staging() {
  local case_root="$fixture_root/source-change"
  local target="$case_root/AGENTS.md"
  local bin_directory="$case_root/bin"
  local manifest_entries=(rules/common/testing.md)
  mkdir -p "$bin_directory"
  printf 'Original instructions.\n' > "$target"
  cat > "$bin_directory/perl" <<'PERL'
#!/usr/bin/env bash
if [[ "$1" == -e ]]; then
  exec /usr/bin/perl "$@"
fi
printf 'External edit during staging.\n' > "$ELELEM_TEST_TARGET"
exec /usr/bin/perl "$@"
PERL
  chmod +x "$bin_directory/perl"
  if ELELEM_TEST_TARGET="$target" PATH="$bin_directory:$PATH" opencode_agents_update "$target" manifest_entries 2> "$case_root/error.log"; then
    printf 'OpenCode AGENTS update published after its source changed\n' >&2
    return 1
  fi
  grep -Fqx 'External edit during staging.' "$target"
  grep -Fq 'changed during processing' "$case_root/error.log"
  [[ -z "$(find "$case_root" -maxdepth 1 -name 'elelem-opencode-agents.*' -print -quit)" ]]
}

test_opencode_pruning_retains_manifest_owned_agents() {
  local case_root="$fixture_root/prune-agents"
  local target="$case_root/AGENTS.md"
  local config="$case_root/opencode.json"
  local manifest="$case_root/.elelem-manifest-opencode"
  local manifest_entries=(rules/common/testing.md)
  mkdir -p "$case_root"
  printf 'Managed OpenCode preamble.\n' > "$target"
  printf '{"model":"custom"}\n' > "$config"
  printf 'Stale tracked content.\n' > "$case_root/stale.md"
  printf '%s\n./AGENTS.md\n./opencode.json\nstale.md\n' "$case_root" > "$manifest"
  prune_stale_manifest_entries "$manifest" "$case_root" manifest_entries agents opencode
  [[ -f "$target" ]]
  [[ -f "$config" ]]
  grep -Fxq AGENTS.md <(printf '%s\n' "${manifest_entries[@]}")
  [[ ! -e "$case_root/stale.md" ]]
}

test_exact_static_legacy_is_replaced_during_install
test_reinstall_preserves_the_end_marker_terminator_style
test_exact_historical_grouped_legacy_is_replaced_during_install
test_exact_current_legacy_is_replaced_during_install
test_owned_edited_static_legacy_is_preserved_as_unmanaged_content
test_unmanifested_static_legacy_lookalike_is_preserved
test_exact_static_legacy_is_removed_without_deleting_the_file
test_exact_dynamic_and_current_legacy_are_removed_without_deleting_the_file
test_unmanaged_bytes_are_restored_after_install_and_uninstall
test_whitespace_only_remainder_is_retained_after_uninstall
test_uninstall_retains_a_file_when_no_managed_content_remains
test_uninstall_does_not_create_an_absent_agents_file
test_permission_preservation_does_not_require_bsd_stat
test_missing_perl_reports_an_actionable_agents_error
test_malformed_reserved_markers_are_rejected_without_changing_agents
test_eof_end_marker_without_a_terminator_is_supported
test_publish_aborts_when_agents_changes_after_staging
test_opencode_pruning_retains_manifest_owned_agents
