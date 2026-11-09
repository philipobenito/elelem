#!/usr/bin/env bash
set -uo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
temporary_directory="$(mktemp -d)"
trap 'rm -rf "$temporary_directory"' EXIT

passed=0
failed=0

run_case() {
  local description="$1"
  shift
  if "$@"; then
    printf '[PASS] %s\n' "$description"
    passed=$((passed + 1))
  else
    printf '[FAIL] %s\n' "$description"
    failed=$((failed + 1))
  fi
}

has_text() {
  local file="$1"
  local text="$2"
  [[ -f "$file" ]] && grep -Fq -- "$text" "$file"
}

is_safe_yaml_description() {
  local description_line="$1"
  if ! grep -Eq '^description: "[^"]*"$' <(printf '%s\n' "$description_line"); then
    grep -Eq '^description: Use (this agent )?when [A-Za-z0-9 .,+/#()&-]+\.$' <(printf '%s\n' "$description_line") || return 1
    return 0
  fi
  ! grep -Fq '\' <(printf '%s\n' "$description_line") || return 1
  ! LC_ALL=C grep -Eq '[[:cntrl:]]' <(printf '%s\n' "$description_line")
}

has_no_legacy_references() {
  local file="$1"
  [[ ! -f "$file" ]] || ! grep -Eiq 'query context manager|requesting_agent|request_type|Integration with other agents' "$file"
}

agents=(architect-reviewer qa-expert typescript-pro python-pro golang-pro rust-engineer react-specialist laravel-specialist java-architect csharp-developer rails-expert)
reporting_agents=(architect-reviewer qa-expert typescript-pro python-pro golang-pro rust-engineer react-specialist laravel-specialist java-architect csharp-developer rails-expert)

test_claude_frontmatter_is_valid_yaml() {
  local validation_root="${1:-$repository_root}"
  local force_fallback="${2:-false}"
  if [[ "$force_fallback" != true ]] && command -v ruby >/dev/null 2>&1 && ruby -e 'require "yaml"' >/dev/null 2>&1; then
    ruby - "$validation_root" "${agents[@]}" <<'RUBY' || return 1
require 'yaml'

root = ARGV.shift
ARGV.each do |name|
  path = File.join(root, 'agents', 'claude', "#{name}.md")
  next unless File.file?(path)
  text = File.read(path)
  match = text.match(/\A---\s*\n(.*?)\n---(?:\s|\z)/m)
  raise "missing Claude frontmatter: #{name}" unless match
  begin
    metadata = YAML.safe_load(match[1], aliases: false)
  rescue Psych::SyntaxError
    abort "invalid Claude YAML frontmatter: #{name}"
  end
  raise "invalid Claude name: #{name}" unless metadata['name'] == name
  raise "missing Claude description: #{name}" unless metadata['description'].is_a?(String) && !metadata['description'].empty?
  raise "forced Claude model: #{name}" if metadata.key?('model')
end
RUBY
  else
    local agent file
    for agent in "${agents[@]}"; do
      file="$validation_root/agents/claude/$agent.md"
      [[ -f "$file" ]] || continue
      [[ "$(sed -n '1p' "$file")" == '---' ]] || return 1
      [[ "$(sed -n '2p' "$file")" == "name: $agent" ]] || return 1
      if ! is_safe_yaml_description "$(sed -n '3p' "$file")"; then
        printf 'Unsafe Claude YAML description: %s\n' "$agent"
        return 1
      fi
      [[ "$(sed -n '4p' "$file")" == '---' ]] || return 1
    done
    printf '[INFO] Ruby Psych unavailable, validated the constrained Claude YAML frontmatter shape, not the complete YAML grammar\n'
  fi
  local agent file
  local scope_instruction='Scope and authorisation: Follow the delegated scope and all parent or user constraints. For review-only assignments, review and report only, do not implement changes or deploy. Deployment and other side effects require explicit authorisation. Specialist workflow lists below are conditional examples and do not override the assignment.'
  for agent in "${reporting_agents[@]}"; do
    file="$validation_root/agents/claude/$agent.md"
    [[ -f "$file" ]] || return 1
    head -n 16 "$file" | grep -Fq -- "$scope_instruction" || return 1
    has_no_legacy_references "$file" || return 1
    grep -Eiq 'Delivery (notification|message):|(implementation|application|architecture review) completed\.|Progress (tracking|reporting):|Status reporting:|"status"[[:space:]]*:' "$file" && return 1
    has_text "$file" 'When reporting progress or outcomes, state only work performed and evidence actually observed. Do not invent counts, measurements or results.' || return 1
  done
}

test_opencode_frontmatter_is_valid_yaml() {
  if command -v ruby >/dev/null 2>&1 && ruby -e 'require "yaml"' >/dev/null 2>&1; then
    ruby - "$repository_root" "${agents[@]}" <<'RUBY' || return 1
require 'yaml'

root = ARGV.shift
ARGV.each do |name|
  path = File.join(root, 'agents', 'opencode', "#{name}.md")
  next unless File.file?(path)
  text = File.read(path)
  match = text.match(/\A---\s*\n(.*?)\n---(?:\s|\z)/m)
  raise "missing OpenCode frontmatter: #{name}" unless match
  begin
    metadata = YAML.safe_load(match[1], aliases: false)
  rescue Psych::SyntaxError
    abort "invalid OpenCode YAML frontmatter: #{name}"
  end
  raise "missing OpenCode description: #{name}" unless metadata['description'].is_a?(String) && !metadata['description'].empty?
  raise "invalid OpenCode mode: #{name}" unless metadata['mode'] == 'subagent'
  raise "forced OpenCode model: #{name}" if metadata.key?('model') || metadata.key?('intended-tier')
end
RUBY
  else
    local agent file
    for agent in "${agents[@]}"; do
      file="$repository_root/agents/opencode/$agent.md"
      [[ -f "$file" ]] || continue
      [[ "$(sed -n '1p' "$file")" == '---' ]] || return 1
      is_safe_yaml_description "$(sed -n '2p' "$file")" || return 1
      [[ "$(sed -n '3p' "$file")" == 'mode: subagent' ]] || return 1
      [[ "$(sed -n '4p' "$file")" == '---' ]] || return 1
    done
    printf '[INFO] Ruby Psych unavailable, validated the constrained OpenCode YAML frontmatter shape, not the complete YAML grammar\n'
  fi
  local agent file
  local scope_instruction='Scope and authorisation: Follow the delegated scope and all parent or user constraints. For review-only assignments, review and report only, do not implement changes or deploy. Deployment and other side effects require explicit authorisation. Specialist workflow lists below are conditional examples and do not override the assignment.'
  for agent in "${reporting_agents[@]}"; do
    file="$repository_root/agents/opencode/$agent.md"
    [[ -f "$file" ]] || return 1
    head -n 16 "$file" | grep -Fq -- "$scope_instruction" || return 1
    has_no_legacy_references "$file" || return 1
    grep -Eiq 'Delivery (notification|message):|(implementation|application|architecture review) completed\.|Progress (tracking|reporting):|Status reporting:|"status"[[:space:]]*:' "$file" && return 1
    has_text "$file" 'When reporting progress or outcomes, state only work performed and evidence actually observed. Do not invent counts, measurements or results.' || return 1
  done
}

validate_codex_toml_shape() {
  local file="$1"
  local agent="$2"
  [[ "$(sed -n '1p' "$file")" == "name = \"$agent\"" ]] || return 1
  grep -Eq '^description = "[^"\\]+"$' <(sed -n '2p' "$file") || return 1
  [[ "$(sed -n '3p' "$file")" == 'developer_instructions = """' ]] || return 1
  [[ -n "$(sed -n '4p' "$file")" ]] || return 1
  [[ "$(tail -n 1 "$file")" == '"""' ]] || return 1
  [[ "$(grep -Fc '"""' "$file")" == 2 ]] || return 1
  [[ "$(grep -Fxc '"""' "$file")" == 1 ]] || return 1
  ! grep -Fq '\' "$file" || return 1
  ! LC_ALL=C grep -Eq '[[:cntrl:]]' "$file"
}

test_codex_definitions_are_native_toml() {
  local agent candidate python_command=''
  local scope_instruction='Scope and authorisation: Follow the delegated scope and all parent or user constraints. For review-only assignments, review and report only, do not implement changes or deploy. Deployment and other side effects require explicit authorisation. Specialist workflow lists below are conditional examples and do not override the assignment.'
  for agent in "${agents[@]}"; do
    local file="$repository_root/agents/codex/$agent.toml"
    [[ -f "$file" ]] || return 1
    validate_codex_toml_shape "$file" "$agent" || return 1
    has_no_legacy_references "$file" || return 1
  done
  for agent in "${reporting_agents[@]}"; do
    local file="$repository_root/agents/codex/$agent.toml"
    [[ -f "$file" ]] || continue
    head -n 16 "$file" | grep -Fq -- "$scope_instruction" || return 1
    grep -Eiq 'Delivery (notification|message):|(implementation|application|architecture review) completed\.|Progress (tracking|reporting):|Status reporting:|"status"[[:space:]]*:' "$file" && return 1
    has_text "$file" 'When reporting progress or outcomes, state only work performed and evidence actually observed. Do not invent counts, measurements or results.' || return 1
  done
  for candidate in python3.13 python3.12 python3.11 python3; do
    if command -v "$candidate" >/dev/null 2>&1 && "$candidate" -c 'import tomllib' >/dev/null 2>&1; then
      python_command="$candidate"
      break
    fi
  done
  if [[ -z "$python_command" ]]; then
    printf '[INFO] native TOML parser unavailable; constrained TOML format validation passed, general TOML grammar was not parsed\n'
    return 0
  fi
  "$python_command" - "$repository_root/agents/codex" "${agents[@]}" <<'PY'
import pathlib
import sys
import tomllib

directory = pathlib.Path(sys.argv[1])
for name in sys.argv[2:]:
    with (directory / f"{name}.toml").open("rb") as definition_file:
        definition = tomllib.load(definition_file)
    assert definition.get("name") == name
    assert isinstance(definition.get("description"), str) and definition["description"]
    assert isinstance(definition.get("developer_instructions"), str) and definition["developer_instructions"]
    assert "model" not in definition
PY
}

test_bundled_licence_and_fork_provenance_are_documented() {
  local expected_notice actual_notice
  expected_notice="$(cat <<'MIT'
MIT License

Copyright (c) 2025 VoltAgent

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
MIT
  )"
  actual_notice="$(cat "$repository_root/agents/LICENSE")"
  [[ "$actual_notice" == "$expected_notice" ]] || return 1
  has_text "$repository_root/agents/README.md" 'ampedweb/awesome-subagents' || return 1
  has_text "$repository_root/agents/README.md" 'VoltAgent' || return 1
  has_text "$repository_root/agents/README.md" '4ce4267485e1a5491488548b3474007e1e6bddfb'
}

test_committee_fallback_discovers_available_type_and_blocks_when_absent() {
  local skill="$repository_root/skills/brainstorming-committee/SKILL.md"
  local prompt="$repository_root/skills/brainstorming-committee/committee-member-prompt.md"
  [[ -f "$skill" && -f "$prompt" ]] || return 1
  grep -Fq "When a specialised type is unavailable, inspect the dispatch tool's currently exposed type options and select an available type whose description indicates broad general-purpose capability." "$skill" || return 1
  grep -Fq 'If no suitable available type exists, return a blocker to the coordinator and do not dispatch.' "$skill" || return 1
  grep -Fq "If any specialised type is unavailable at dispatch time, inspect the dispatch tool's currently exposed type options and choose an available type whose description indicates broad general-purpose capability." "$prompt" || return 1
  grep -Fq 'If no suitable available type exists, report a blocker to the coordinator and do not dispatch.' "$prompt" || return 1
  has_text "$prompt" '{{DISPATCH_AGENT_TOOL}} ([PRAGMATIST_SUBAGENT_TYPE]):' || return 1
  has_text "$prompt" '{{DISPATCH_AGENT_TOOL}} ([ARCHITECT_SUBAGENT_TYPE]):' || return 1
  has_text "$prompt" '{{DISPATCH_AGENT_TOOL}} ([ADVOCATE_SUBAGENT_TYPE]):' || return 1
  has_text "$prompt" '{{DISPATCH_AGENT_TOOL}} ([TIEBREAKER_SUBAGENT_TYPE]):' || return 1
  ! grep -Eq '^\{\{DISPATCH_AGENT_TOOL\}\} \((architect-reviewer|qa-expert)\):' "$prompt" || return 1
  ! grep -Fq '`general-purpose`' "$skill" "$prompt"
}

run_case 'Claude agent frontmatter parses as valid YAML' test_claude_frontmatter_is_valid_yaml
run_case 'OpenCode agent frontmatter parses as valid YAML' test_opencode_frontmatter_is_valid_yaml
run_case 'Codex definitions parse as native TOML with required fields' test_codex_definitions_are_native_toml
run_case 'bundled MIT licence and fork provenance are documented' test_bundled_licence_and_fork_provenance_are_documented
run_case 'committee fallback discovers available agent types and blocks if none fit' test_committee_fallback_discovers_available_type_and_blocks_when_absent

printf 'Tests: %d passed, %d failed\n' "$passed" "$failed"
(( failed == 0 ))
