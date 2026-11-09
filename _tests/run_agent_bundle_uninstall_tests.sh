#!/usr/bin/env bash
set -euo pipefail

checkout_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_root="${ELELEM_TEST_ROOT:?Set ELELEM_TEST_ROOT to the retained fixture root}"

prepare_case() {
  local case_name="$1"
  case_root="$(mktemp -d "$fixture_root/$case_name.XXXXXX")"
  mkdir -p "$case_root/invocation" "$case_root/project" "$case_root/home/.codex/agents" "$case_root/xdg" "$case_root/tmp"
  ln -s "$checkout_root/uninstall.sh" "$case_root/invocation/uninstall.sh"
  ln -s "$checkout_root/_install-common.sh" "$case_root/invocation/_install-common.sh"
  printf 'agent fixture bytes\n' > "$case_root/home/.codex/agents/architect-reviewer.toml"
  printf 'notice fixture bytes\n' > "$case_root/home/.codex/agents.LICENSE"
  printf '%s\n%s\n%s\n' "$case_root/home" '.codex/agents/architect-reviewer.toml' '.codex/agents.LICENSE' > "$case_root/invocation/.elelem-manifest-codex"
  cp "$case_root/home/.codex/agents/architect-reviewer.toml" "$case_root/tmp/agent.expected"
  cp "$case_root/home/.codex/agents.LICENSE" "$case_root/tmp/notice.expected"
  cp "$case_root/invocation/.elelem-manifest-codex" "$case_root/tmp/manifest.expected"
}

run_uninstall() {
  local input="$1"
  (
    cd "$case_root/project"
    printf '%s' "$input" | HOME="$case_root/home" XDG_CONFIG_HOME="$case_root/xdg" TMPDIR="$case_root/tmp" ELELEM_TEST_ROOT="$fixture_root" TERM=dumb NO_COLOR=1 /usr/bin/script -q "$case_root/session.log" /bin/bash "$case_root/invocation/uninstall.sh" > "$case_root/tmp/stdout.log" 2>&1
  )
  grep -Fq 'delete: .codex/agents/architect-reviewer.toml' "$case_root/session.log"
  grep -Fq 'delete: .codex/agents.LICENSE' "$case_root/session.log"
}

uninstall_refusal_preserves_manifest_listed_bundle_files() {
  prepare_case refusal
  run_uninstall $' \n\n'
  grep -Fq 'Aborted. No changes made.' "$case_root/session.log"
  cmp "$case_root/tmp/agent.expected" "$case_root/home/.codex/agents/architect-reviewer.toml"
  cmp "$case_root/tmp/notice.expected" "$case_root/home/.codex/agents.LICENSE"
  cmp "$case_root/tmp/manifest.expected" "$case_root/invocation/.elelem-manifest-codex"
  printf 'PASS: uninstall refusal preserves manifest-listed bundle files (%s)\n' "$case_root"
}

uninstall_confirmation_removes_tracked_bundle_files() {
  prepare_case confirmation
  run_uninstall $' \n \n'
  [[ ! -e "$case_root/home/.codex/agents/architect-reviewer.toml" ]]
  [[ ! -e "$case_root/home/.codex/agents.LICENSE" ]]
  [[ ! -e "$case_root/invocation/.elelem-manifest-codex" ]]
  printf 'PASS: uninstall confirmation removes tracked bundle files (%s)\n' "$case_root"
}

mkdir -p "$fixture_root"
uninstall_refusal_preserves_manifest_listed_bundle_files
uninstall_confirmation_removes_tracked_bundle_files
