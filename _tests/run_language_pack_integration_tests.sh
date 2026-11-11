#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "$0")/.." && pwd -P)"
fixture_parent="$(mktemp -d "${TMPDIR:-/tmp}/language-pack-integration.XXXXXX")"
fixture_parent="$(cd "$fixture_parent" && pwd -P)"

prepare_fixture() {
  harness="$1"
  scope="$2"
  case_root="$(mktemp -d "$fixture_parent/$harness-$scope.XXXXXX")"
  mkdir -p "$case_root/installer" "$case_root/project" "$case_root/home" "$case_root/tmp" "$case_root/xdg"
  cp "$repository_root/install-$harness.sh" "$repository_root/uninstall.sh" "$repository_root/_install-common.sh" "$case_root/installer/"
  cp -R "$repository_root/rules" "$repository_root/skills" "$repository_root/agents" "$case_root/installer/"
  base="$case_root/home/.claude"
  [[ "$harness" != opencode ]] || base="$case_root/home/.config/opencode"
  [[ "$scope" != project ]] || base="$case_root/project/.$harness"
  [[ "$harness" != codex ]] || base="$case_root/$([[ "$scope" == user ]] && printf home || printf project)"
  skills_prefix=skills
  [[ "$harness" != codex ]] || skills_prefix=.agents/skills
  manifest="$case_root/installer/.elelem-manifest-$harness"
  eager="$base/rules/elelem-language-packs.md"
  [[ "$harness" != codex ]] || eager="$base/$([[ "$scope" == user ]] && printf .codex/AGENTS.md || printf AGENTS.md)"
}

run_installer() {
  local common_count
  common_count="$(find "$case_root/installer/rules/common" -name '*.md' | wc -l | tr -d ' ')"
  (cd "$case_root/project"
    HOME="$case_root/home" XDG_CONFIG_HOME="$case_root/xdg" TMPDIR="$case_root/tmp" TERM=xterm NO_COLOR=1 expect -f - "$case_root/installer/install-$harness.sh" "$scope" "$common_count" "$harness" > "$case_root/install-$1.log" 2>&1 <<'EOF'
set timeout 30
spawn /bin/bash [lindex $argv 0]
expect_before {
  eof {set result [wait]; exit [lindex $result 3]}
  timeout {puts stderr "Installer prompt timed out"; exit 124}
}
expect "Use"
if {[lindex $argv 1] eq "project"} {send "\033\[A"}
send "\r"
if {[lindex $argv 1] eq "project"} {expect "Project path"; send "\r"}
expect "Common instruction files to install:"
expect "Select items"
for {set index 0} {$index < [lindex $argv 2]} {incr index} {send " \033\[B"}
send "\r"
if {[lindex $argv 3] eq "codex"} {
  expect "Continue without optional common instructions"
} else {
  expect "Continue with no common rules"
}
send " \r"
expect -re {> \[x\] Install skills}
send " \r"
expect -re {> \[ \] Elelem agent bundle}
send "\r"
expect {
  timeout {exit 124}
  eof {set result [wait]; exit [lindex $result 3]}
}
EOF
  )
}

seed_legacy_install() {
  mkdir -p "$base/$skills_prefix/personal" "$(dirname "$eager")"
  printf 'Personal {{READ_FILE_TOOL}} skill\n' > "$base/$skills_prefix/personal/SKILL.md"
  cp "$base/$skills_prefix/personal/SKILL.md" "$case_root/personal.expected"
  printf '%s\n' "$base" > "$manifest"
  if [[ "$harness" == codex ]]; then
    printf 'Personal before.\n<!-- elelem:codex:start -->\n# Python Coding Style\nLegacy eager body\n<!-- elelem:codex:end -->\nPersonal after.\n' > "$eager"
  else
    mkdir -p "$base/rules/python"
    printf 'Legacy eager body\n' > "$base/rules/python/testing.md"
    printf 'rules/python/testing.md\n' >> "$manifest"
  fi
  [[ "$harness" != opencode ]] || seed_legacy_opencode
}

seed_legacy_opencode() {
  printf '%s\n' '{"instructions":["personal.md","rules/python/*.md"],"model":"personal-model","permission":{"edit":"ask"}}' > "$case_root/shared.json"
  ln -s "$case_root/shared.json" "$base/opencode.json"
  printf 'opencode.json\n' >> "$manifest"
}

assert_reference() {
  local source="$1" pack="$2" topic="${1##*/}" line
  [[ -f "$pack/references/$topic" ]]
  grep -Fq "references/$topic" "$pack/SKILL.md"
  grep -Fxq "$skills_prefix/${pack##*/}/references/$topic" "$manifest"
  while IFS= read -r line; do
    [[ "$line" == *'{{'* ]] || grep -Fxq -- "$line" "$pack/references/$topic"
  done < "$source"
}

assert_deferred_delivery() {
  local directory language topic pack
  for directory in "$case_root/installer"/rules/*; do
    language="${directory##*/}"
    [[ "$language" != common ]] || continue
    pack="$base/$skills_prefix/elelem-language-$language"
    [[ -f "$pack/SKILL.md" ]]
    grep -Fq "name: elelem-language-$language" "$pack/SKILL.md"
    grep -Fxq "$skills_prefix/elelem-language-$language/SKILL.md" "$manifest"
    for topic in "$directory"/*.md; do assert_reference "$topic" "$pack"; done
    ! grep -Fq "# $(sed -n 's/^# //p' "$directory/coding-style.md" | head -n 1)" "$eager"
    [[ ! -d "$base/rules/$language" ]]
  done
  assert_substitutions
  ! grep -Fq 'Language packs to install' "$case_root/install-first.log"
  [[ ! -e "$base/$skills_prefix/workflow-coordinator/SKILL.md" && ! -e "$base/rules/common" ]]
  grep -Fq 'not a repository language inventory or incidental Markdown mentions' "$eager"
}

assert_substitutions() {
  local markdown read_tool=Read skill_tool=Skill
  [[ "$harness" != opencode ]] || { read_tool=read; skill_tool=skill; }
  [[ "$harness" != codex ]] || { read_tool='read the file'; skill_tool='/skills or $skill-name'; }
  grep -Fq "$skill_tool" "$eager"
  grep -Fq "$read_tool" "$base/$skills_prefix/elelem-language-python/SKILL.md"
  while IFS= read -r markdown; do
    [[ "$markdown" != *.md ]] || ! grep -Fq '{{' "$base/$markdown"
  done < <(tail -n +2 "$manifest")
  ! grep -Fq '{{' "$eager"
}

assert_preserved_content() {
  cmp "$case_root/personal.expected" "$base/$skills_prefix/personal/SKILL.md"
  if [[ "$harness" == opencode ]]; then
    [[ -L "$base/opencode.json" && "$(readlink "$base/opencode.json")" == "$case_root/shared.json" ]]
    jq -e '.instructions == ["personal.md","rules/elelem-language-packs.md"] and .model == "personal-model" and .permission.edit == "ask"' "$base/opencode.json" >/dev/null
    ! grep -Eq 'rules/(go|javascript|php|python|rust|typescript)/' "$base/AGENTS.md"
    ! grep -Fxq opencode.json "$manifest"
  elif [[ "$harness" == codex ]]; then
    grep -Fxq 'Personal before.' "$eager"
    grep -Fxq 'Personal after.' "$eager"
    [[ "$(grep -c 'elelem:codex:start' "$eager")" == 1 ]]
    ! grep -Fq 'Legacy eager body' "$eager"
  fi
}

run_uninstaller() {
  (cd "$case_root/project"
    HOME="$case_root/home" XDG_CONFIG_HOME="$case_root/xdg" TMPDIR="$case_root/tmp" TERM=xterm NO_COLOR=1 expect -f - "$case_root/installer/uninstall.sh" > "$case_root/uninstall.log" 2>&1 <<'EOF'
set timeout 30
spawn /bin/bash [lindex $argv 0]
expect_before {
  eof {set result [wait]; exit [lindex $result 3]}
  timeout {puts stderr "Uninstaller prompt timed out"; exit 124}
}
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

assert_uninstalled() {
  local entry
  [[ ! -e "$manifest" ]]
  while IFS= read -r entry; do [[ ! -e "$base/$entry" && ! -L "$base/$entry" ]]; done < <(tail -n +2 "$case_root/manifest.expected")
  cmp "$case_root/personal.expected" "$base/$skills_prefix/personal/SKILL.md"
  if [[ "$harness" == opencode ]]; then
    [[ -L "$base/opencode.json" && "$(readlink "$base/opencode.json")" == "$case_root/shared.json" ]]
    jq -e '.instructions == ["personal.md"] and .model == "personal-model" and .permission.edit == "ask"' "$base/opencode.json" >/dev/null
  elif [[ "$harness" == codex ]]; then
    grep -Fxq 'Personal before.' "$eager"
    grep -Fxq 'Personal after.' "$eager"
    ! grep -Fq 'elelem:codex:' "$eager"
  fi
}

test_migration_reinstall_uninstall() {
  prepare_fixture "$1" "$2"
  seed_legacy_install
  run_installer first
  assert_deferred_delivery
  assert_preserved_content
  cp "$manifest" "$case_root/manifest.expected"
  run_installer second
  cmp "$case_root/manifest.expected" "$manifest"
  assert_deferred_delivery
  assert_preserved_content
  run_uninstaller
  assert_uninstalled
  printf '[PASS] %s %s migration, deferred delivery, reinstall and uninstall\n' "$harness" "$scope"
}

for selected_harness in claude opencode codex; do
  for selected_scope in user project; do
    test_migration_reinstall_uninstall "$selected_harness" "$selected_scope"
  done
done
printf 'Retained integration fixtures: %s\n' "$fixture_parent"
