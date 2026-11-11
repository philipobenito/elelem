#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$REPO_ROOT/_install-common.sh"
source "$REPO_ROOT/install-codex.sh"

passed=0
failed=0

_pass() {
  echo "[PASS] $1"
  (( passed++ )) || true
}

_fail() {
  echo "[FAIL] $1: $2"
  (( failed++ )) || true
}

test_full_install_to_tmp_user_scope() {
  local name="full_install_to_tmp_user_scope"
  local tmphome agents_target skills_target payload_file
  tmphome="$(mktemp -d)" || return 1
  tmphome="$(cd "$tmphome" && pwd -P)" || return 1
  trap "rm -rf '$tmphome'" RETURN

  agents_target="$tmphome/.codex/AGENTS.md"
  skills_target="$tmphome/.agents/skills"
  payload_file="$(mktemp)"
  trap "rm -rf '$tmphome'; rm -f '$payload_file'" RETURN

  local common_files=()
  local f
  for f in "$REPO_ROOT/rules/common/"*.md; do
    common_files+=("$(basename "$f")")
  done

  _codex_render_agents_payload "$payload_file" common_files
  _codex_upsert_managed_block "$agents_target" "$payload_file"
  _codex_scan_file_for_placeholders "$agents_target" || { _fail "$name" "AGENTS.md placeholder scan failed"; return; }

  mkdir -p "$skills_target"
  local manifest=()
  install_language_packs "$REPO_ROOT/rules" "$skills_target" .agents/skills "$tmphome/absent-manifest" manifest CODEX_PLACEHOLDERS CODEX_SUBSTITUTIONS
  local skills_files=()
  while IFS= read -r -d '' f; do
    skills_files+=("${f#"$REPO_ROOT/skills"/}")
  done < <(find "$REPO_ROOT/skills" -type f -print0)
  install_files_from_dir "$REPO_ROOT/skills" "$skills_target" ".agents/skills" manifest skills_files _codex_skill_resolve_dst
  _codex_substitute_placeholders_tree "$skills_target"
  scan_no_unsubstituted_placeholders "$skills_target" || { _fail "$name" "skills placeholder scan failed"; return; }

  if [[ ! -f "$agents_target" ]]; then
    _fail "$name" "expected $agents_target to exist"
    return
  fi

  if ! grep -q 'elelem:codex:start' "$agents_target"; then
    _fail "$name" "managed block start marker missing from AGENTS.md"
    return
  fi

  if ! grep -q 'rules/common/coding-style.md' "$agents_target"; then
    _fail "$name" "expected common rule heading missing from AGENTS.md"
    return
  fi

  if ! grep -q '^# On-demand language packs' "$agents_target" ||
    [[ ! -f "$skills_target/elelem-language-python/references/coding-style.md" ]] ||
    grep -q 'rules/python/coding-style.md' "$agents_target"; then
    _fail "$name" "expected on-demand Python skill instead of embedded language rules"
    return
  fi

  if grep -q '^globs:' "$agents_target"; then
    _fail "$name" "language-pack frontmatter leaked into AGENTS.md"
    return
  fi

  local skill_md="$skills_target/debugging/SKILL.md"
  if [[ ! -f "$skill_md" ]]; then
    _fail "$name" "expected skills/debugging/SKILL.md not present"
    return
  fi

  if ! grep -q '^name: debugging$' "$skill_md"; then
    _fail "$name" "debugging SKILL.md lost its frontmatter"
    return
  fi

  if ! grep -RIlF '/skills or $skill-name' "$skills_target" >/dev/null 2>&1; then
    _fail "$name" "skills did not receive Codex INVOKE_SKILL_TOOL substitution"
    return
  fi

  if ! grep -RIlF 'request_user_input' "$skills_target" >/dev/null 2>&1; then
    _fail "$name" "skills did not receive Codex ASK_USER_QUESTION_TOOL substitution"
    return
  fi

  if ! grep -RIlF 'update_plan' "$skills_target" >/dev/null 2>&1; then
    _fail "$name" "skills did not receive Codex TASK_TRACKER_TOOL substitution"
    return
  fi

  if ! grep -RIlF 'spawn_agent' "$skills_target" >/dev/null 2>&1; then
    _fail "$name" "skills did not receive Codex DISPATCH_AGENT_TOOL substitution"
    return
  fi

  _pass "$name"
}

test_coexistence_three_manifests() {
  local name="coexistence_three_manifests"
  local tmphome
  tmphome="$(mktemp -d)"
  trap "rm -rf '$tmphome'" RETURN

  local claude_base="$tmphome/.claude"
  local opencode_base="$tmphome/.config/opencode"
  local codex_base="$tmphome"

  mkdir -p "$claude_base/rules/common" "$opencode_base/rules/common" "$codex_base/.agents/skills/debugging"

  local manifest_claude=("rules/common/coding-style.md")
  local manifest_opencode=("rules/common/coding-style.md")
  local manifest_codex=(".agents/skills/debugging/SKILL.md")

  cp "$REPO_ROOT/rules/common/coding-style.md" "$claude_base/rules/common/"
  cp "$REPO_ROOT/rules/common/coding-style.md" "$opencode_base/rules/common/"
  cp "$REPO_ROOT/skills/debugging/SKILL.md" "$codex_base/.agents/skills/debugging/"

  local mf_claude="$tmphome/.elelem-manifest-claude"
  local mf_opencode="$tmphome/.elelem-manifest-opencode"
  local mf_codex="$tmphome/.elelem-manifest-codex"

  write_manifest "$mf_claude" "$claude_base" manifest_claude
  write_manifest "$mf_opencode" "$opencode_base" manifest_opencode
  write_manifest "$mf_codex" "$codex_base" manifest_codex

  if [[ ! -f "$mf_claude" ]] || [[ ! -f "$mf_opencode" ]] || [[ ! -f "$mf_codex" ]]; then
    _fail "$name" "expected three distinct manifest files"
    return
  fi

  _pass "$name"
}

test_install_dot_sh_offers_codex() {
  local name="front_controller_offers_codex"
  if grep -q '"Codex"' "$REPO_ROOT/install.sh"; then
    _pass "$name"
  else
    _fail "$name" "install.sh harness_items array does not include Codex"
  fi
}

test_post_install_scan_ignores_unrelated_files_under_skills_root() {
  local name="post_install_scan_ignores_unrelated_files_under_skills_root"
  local tmpbase
  tmpbase="$(mktemp -d)"
  trap "rm -rf '$tmpbase'" RETURN

  mkdir -p "$tmpbase/.agents/skills"
  mkdir -p "$tmpbase/third-party/plugin/skills/foo"

  cat > "$tmpbase/third-party/plugin/skills/foo/SKILL.md" <<'PLUGIN'
---
name: foo
description: third-party
---

TODO: this is fine, it belongs to a different installer.
PLUGIN

  local manifest=()
  local skills_files=("debugging/SKILL.md")
  install_files_from_dir "$REPO_ROOT/skills" "$tmpbase/.agents/skills" ".agents/skills" manifest skills_files _codex_skill_resolve_dst
  _codex_substitute_placeholders_tree "$tmpbase/.agents/skills"

  local scoped_exit=0
  ( scan_no_unsubstituted_placeholders "$tmpbase/.agents/skills" ) || scoped_exit=$?
  if (( scoped_exit != 0 )); then
    _fail "$name" "scoped scan tripped on a clean install"
    return
  fi

  local broad_exit=0
  ( scan_no_unsubstituted_placeholders "$tmpbase" ) > "$tmpbase/broad-scan.log" 2>&1 || broad_exit=$?
  if (( broad_exit == 0 )); then
    _fail "$name" "broad scan against base did not trip on unrelated TODO marker; test setup is wrong"
    return
  fi

  _pass "$name"
}

create_codex_language_fixture() {
  fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/codex-language.XXXXXX")"
  fixture_root="$(cd "$fixture_root" && pwd -P)"
  mkdir -p "$fixture_root/repo" "$fixture_root/home" "$fixture_root/project" "$fixture_root/tmp"
  cp "$REPO_ROOT/install-codex.sh" "$REPO_ROOT/_install-common.sh" "$fixture_root/repo/"
  cp -R "$REPO_ROOT/rules" "$REPO_ROOT/skills" "$REPO_ROOT/agents" "$fixture_root/repo/"
  cat > "$fixture_root/run.sh" <<'EOF'
#!/usr/bin/env bash
cd "$(dirname "$0")/project" || exit 1
../repo/install-codex.sh
status=$?
printf '\nCODEX_LANGUAGE_EXIT=%s\n' "$status"
exit "$status"
EOF
  chmod +x "$fixture_root/run.sh"
}

run_codex_language_fixture() {
  local input="$1" session="$2"
  printf '%b' "$input" | HOME="$fixture_root/home" TMPDIR="$fixture_root/tmp" TERM=dumb \
    /usr/bin/script -q "$fixture_root/$session.log" "$fixture_root/run.sh" >/dev/null
  grep -Fq 'CODEX_LANGUAGE_EXIT=0' "$fixture_root/$session.log"
}

assert_codex_language_packs() {
  local base="$1" source language topic relative
  for source in "$fixture_root/repo/rules/"*/; do
    language="$(basename "$source")"
    [[ "$language" != common ]] || continue
    relative=".agents/skills/elelem-language-$language"
    [[ -f "$base/$relative/SKILL.md" ]] || return 1
    grep -Fxq "$relative/SKILL.md" "$fixture_root/repo/.elelem-manifest-codex" || return 1
    for topic in "$source"*.md; do
      [[ -f "$base/$relative/references/${topic##*/}" ]] || return 1
      grep -Fq "references/${topic##*/}" "$base/$relative/SKILL.md" || return 1
      grep -Fxq "$relative/references/${topic##*/}" "$fixture_root/repo/.elelem-manifest-codex" || return 1
    done
  done
  ! grep -R -F '{{' "$base/.agents/skills"
}

test_codex_installs_all_packs_without_optional_instructions() {
  local scope="$1" fixture_root input base target file
  create_codex_language_fixture
  trap 'rm -rf "$fixture_root"' RETURN
  base="$fixture_root/home"; target="$base/.codex/AGENTS.md"; input='\n'
  if [[ "$scope" == project ]]; then
    base="$fixture_root/project"; target="$base/AGENTS.md"; input='\033[A\n\n'
  fi
  for file in "$fixture_root/repo/rules/common/"*.md; do input="$input \033[B"; done
  input="$input\n \n \n\n"
  mkdir -p "$(dirname "$target")"
  printf 'User instructions before.\n' > "$target"
  if ! run_codex_language_fixture "$input" first || ! assert_codex_language_packs "$base"; then
    _fail "codex_${scope}_mandatory_packs" "declined optional instructions did not install every pack"; return
  fi
  assert_codex_deferred_payload "$target" "$scope" || return
  printf 'User instructions after.\n' >> "$target"
  if ! run_codex_language_fixture "$input" second || ! assert_codex_language_packs "$base"; then
    _fail "codex_${scope}_mandatory_packs" "reinstall lost pack ownership"; return
  fi
  assert_codex_preserved_instructions "$target" "$scope"
}

assert_codex_deferred_payload() {
  local target="$1" scope="$2"
  if ! grep -Fq '/skills or $skill-name' "$target" ||
    grep -Eq 'rules/(common|python|go|javascript|typescript|php|rust)/|^globs:|^# Python Coding Style' "$target" ||
    grep -Fq 'Language packs to install' "$fixture_root/first.log"; then
    _fail "codex_${scope}_deferred_payload" "optional instructions, language menu or embedded bodies present"; return 1
  fi
  [[ ! -e "$base/.agents/skills/debugging/SKILL.md" ]] || { _fail "codex_${scope}_deferred_payload" "workflow skills installed despite declining"; return 1; }
}

assert_codex_preserved_instructions() {
  local target="$1" scope="$2"
  if grep -Fxq 'User instructions before.' "$target" && grep -Fxq 'User instructions after.' "$target" &&
    [[ "$(grep -c 'elelem:codex:start' "$target")" == 1 ]]; then
    _pass "codex_${scope}_mandatory_packs_preserve_user_content_on_reinstall"
  else
    _fail "codex_${scope}_mandatory_packs" "reinstall changed user content or duplicated managed block"
  fi
}

prepare_codex_bundle_conflict() {
  local agent
  create_codex_language_fixture
  mkdir -p "$fixture_root/home/.codex"
  for agent in "$fixture_root/repo/agents/codex/"*.toml; do break; done
  agent="${agent##*/}"
  printf '[agents.%s]\nconfig_file = "custom.toml"\n' "${agent%.toml}" > "$fixture_root/home/.codex/config.toml"
  printf 'User instructions before.\n' > "$fixture_root/home/.codex/AGENTS.md"
}

test_codex_bundle_conflict_allows_corrected_retry() {
  local fixture_root premature_packs=0 input='\n\n \n \n'
  prepare_codex_bundle_conflict
  trap 'rm -rf "$fixture_root"' RETURN
  if run_codex_language_fixture "$input" conflict || ! grep -Fq 'identity conflict' "$fixture_root/conflict.log" ||
    ! grep -Fq '# On-demand language packs' "$fixture_root/home/.codex/AGENTS.md" ||
    ! grep -Fxq 'User instructions before.' "$fixture_root/home/.codex/AGENTS.md"; then
    _fail codex_bundle_conflict_allows_corrected_retry "expected bundle conflict after preserved user content and activation policy"; return
  fi
  [[ ! -d "$fixture_root/home/.agents/skills/elelem-language-go" ]] || premature_packs=1
  rm -f "$fixture_root/home/.codex/config.toml"
  if ! run_codex_language_fixture "$input" retry || ! assert_codex_language_packs "$fixture_root/home"; then
    grep -E 'Error:|CODEX_LANGUAGE_EXIT=' "$fixture_root/conflict.log" "$fixture_root/retry.log"
    _fail codex_bundle_conflict_allows_corrected_retry "corrected retry failed to install manifested packs"; return
  fi
  if (( premature_packs != 0 )) || ! grep -Fxq 'User instructions before.' "$fixture_root/home/.codex/AGENTS.md"; then
    _fail codex_bundle_conflict_allows_corrected_retry "failed optional processing published packs or user instructions changed"; return
  fi
  _pass codex_bundle_conflict_allows_corrected_retry
}

test_install_dot_sh_offers_codex
test_full_install_to_tmp_user_scope
test_coexistence_three_manifests
test_post_install_scan_ignores_unrelated_files_under_skills_root
test_codex_installs_all_packs_without_optional_instructions user
test_codex_installs_all_packs_without_optional_instructions project
test_codex_bundle_conflict_allows_corrected_retry

total=$(( passed + failed ))
echo
echo "${passed}/${total} tests passed"
(( failed == 0 )) || exit 1
