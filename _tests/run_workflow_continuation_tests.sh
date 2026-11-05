set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMP_PARENT="${TMPDIR:-/tmp}"
TEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/elelem-workflow-continuation.XXXXXX")" || {
  printf '[FAIL] temporary_directory: could not create test directory\n' >&2
  exit 1
}
trap '[[ -n "${TEST_TMP:-}" && "$TEST_TMP" == "$TEMP_PARENT"/* ]] && rm -rf -- "$TEST_TMP"' EXIT
export TMPDIR="$TEST_TMP"

source "$REPO_ROOT/_install-common.sh"
source "$REPO_ROOT/install-codex.sh"

passed=0
failed=0
case_result_count=0
case_result_status=""
case_result_detail=""

_pass() {
  (( case_result_count++ )) || true
  case_result_status="PASS"
  case_result_detail=""
}

_fail() {
  (( case_result_count++ )) || true
  case_result_status="FAIL"
  case_result_detail="$2"
}

_has_text() {
  local file="$1"
  local pattern="$2"
  grep -Eiq "$pattern" "$file"
}

_load_array() {
  local array_name="$1"
  local installer="$2"
  local declaration
  declaration="$(awk -v name="$array_name" 'substr($0, 1, length(name) + 2) == name "=(" {copy=1} copy {print} copy && $0 == ")" {exit}' "$installer")"
  [[ -n "$declaration" ]] || return 1
  eval "$declaration"
}

_load_function() {
  local function_name="$1"
  local installer="$2"
  local declaration
  declaration="$(awk -v name="$function_name" 'substr($0, 1, length(name) + 4) == name "() {" {copy=1} copy {print} copy && $0 == "}" {exit}' "$installer")"
  [[ -n "$declaration" ]] || return 1
  eval "$declaration"
}

test_coordinator_validates_returns_before_advancing() {
  local file="$REPO_ROOT/skills/workflow-coordinator/SKILL.md"
  local content
  content="$(tr '\n' ' ' < "$file")"
  if ! grep -Eiq 'validates? the returned (scope|task scope)' <<< "$content" || ! grep -Eiq 'outcome.{0,100}evidence.{0,100}questions.{0,100}blockers' <<< "$content" || ! grep -Eiq 'records? .{0,40}(result|outcome).{0,50}next action.{0,80}workflow\.md' <<< "$content" || ! grep -Eiq 'user instructions.{0,100}approval.{0,100}current phase' <<< "$content"; then
    _fail "coordinator_validates_returns_before_advancing" "expected return validation and workflow.md recording"
    return
  fi
  _pass "coordinator_validates_returns_before_advancing"
}

test_coordinator_preserves_approval_gates() {
  local file="$REPO_ROOT/skills/workflow-coordinator/SKILL.md"
  local content
  content="$(tr '\n' ' ' < "$file")"
  if ! grep -Eiq 'do not skip or bypass.{0,80}(review|verification|TDD|debugging)' <<< "$content"; then
    _fail "$1" "expected the coordinator handoff loop to preserve required gates"
    return
  fi
  _pass "$1"
}

test_coordinator_pauses_for_legitimate_constraints() {
  local file="$REPO_ROOT/skills/workflow-coordinator/SKILL.md"
  local content
  content="$(tr '\n' ' ' < "$file")"
  if ! grep -Eiq 'Plan.mode.{0,100}(limitation|restriction)' <<< "$content" || ! grep -Eiq 'evidence.{0,80}missing.{0,80}state is unsafe.{0,80}capability is unavailable' <<< "$content" || ! grep -Eiq 'outstanding dependency.{0,120}leaves no safe independent work' <<< "$content"; then
    _fail "$1" "expected pauses for Plan-mode limits, unsafe or incomplete state, and pending dependencies"
    return
  fi
  _pass "$1"
}

test_nested_results_return_to_their_owning_phase() {
  local file="$REPO_ROOT/skills/subagent-driven-development/SKILL.md"
  local content
  content="$(tr '\n' ' ' < "$file")"
  if ! grep -Eiq 'workers? return.{0,100}(to|through) the executor' <<< "$content" || ! grep -Eiq 'executor.{0,100}validates? the returned (scope|outcome|evidence)' <<< "$content"; then
    _fail "nested_results_return_to_their_owning_phase" "expected worker results to return through the executor"
    return
  fi
  _pass "nested_results_return_to_their_owning_phase"
}

test_parallel_checks_require_stable_inputs() {
  local file="$REPO_ROOT/skills/subagent-driven-development/SKILL.md"
  local content
  content="$(tr '\n' ' ' < "$file")"
  if ! grep -Eiq 'task.local checks may run while other tasks are active only when.{0,100}stable' <<< "$content"; then
    _fail "$1" "expected concurrent task checks to require stable inputs"
    return
  fi
  _pass "$1"
}

test_parallel_checks_respect_dependency_barriers() {
  local file="$REPO_ROOT/skills/subagent-driven-development/SKILL.md"
  local content
  content="$(tr '\n' ' ' < "$file")"
  if ! grep -Eiq 'task dependencies and wave barriers' <<< "$content" || ! grep -Eiq 'do not dispatch a dependent wave until its prerequisites' <<< "$content"; then
    _fail "$1" "expected dependencies and wave barriers to gate further work"
    return
  fi
  _pass "$1"
}

test_research_returns_questions_to_coordinator() {
  local file="$REPO_ROOT/skills/research/SKILL.md"
  local content
  content="$(tr '\n' ' ' < "$file")"
  if ! grep -Eiq 'return findings.{0,100}remaining questions.{0,100}coordinator' <<< "$content" || ! grep -Eiq 'blockers to the active coordinator' <<< "$content" || ! grep -Eiq 'or treat an unanswered question or missing input as resolved' <<< "$content"; then
    _fail "$1" "expected Research to return findings, questions and blockers without resolving missing inputs"
    return
  fi
  _pass "$1"
}

test_planning_router_returns_selected_mode_result_to_coordinator() {
  local file="$REPO_ROOT/skills/brainstorming/SKILL.md"
  local content
  content="$(tr '\n' ' ' < "$file")"
  if ! grep -Eiq 'selected mode.{0,100}(returns?|return).{0,100}coordinator' <<< "$content" || ! grep -Eiq 'stop after hand.off ends the current phase procedure only' <<< "$content" || ! grep -Eiq 'not the overall workflow' <<< "$content"; then
    _fail "$1" "expected the router handoff to end only its current procedure"
    return
  fi
  _pass "$1"
}

test_coordinator_never_invokes_itself_recursively() {
  local file="$REPO_ROOT/skills/workflow-coordinator/SKILL.md"
  local content
  content="$(tr '\n' ' ' < "$file")"
  if ! grep -Eiq 'never invoke a coordinator recursively' <<< "$content" || ! grep -Eiq 'create another owner for the same workflow' <<< "$content"; then
    _fail "$1" "expected one active coordinator without recursive invocation or duplicate ownership"
    return
  fi
  _pass "$1"
}

test_standard_planning_returns_proposal_without_advancing_phase() {
  local file="$REPO_ROOT/skills/brainstorming-standard/SKILL.md"
  local content
  content="$(tr '\n' ' ' < "$file")"
  if ! grep -Eiq 'return.{0,100}(proposal|proposed design).{0,100}coordinator' <<< "$content" || ! grep -Eiq 'does not advance the workflow' <<< "$content"; then
    _fail "$1" "expected proposal return at Planning boundary"
    return
  fi
  _pass "$1"
}

test_guided_planning_returns_proposal_without_advancing_phase() {
  local file="$REPO_ROOT/skills/brainstorming-guided/SKILL.md"
  local content
  content="$(tr '\n' ' ' < "$file")"
  if ! grep -Eiq 'return.{0,100}proposed design.{0,100}coordinator' <<< "$content" || ! grep -Eiq 'not the overall workflow' <<< "$content"; then
    _fail "$1" "expected guided proposal return at Planning boundary"
    return
  fi
  _pass "$1"
}

test_committee_results_return_through_planning_owner() {
  local file="$REPO_ROOT/skills/brainstorming-committee/SKILL.md"
  local content
  content="$(tr '\n' ' ' < "$file")"
  if ! grep -Eiq '(committee members|members).{0,100}return.{0,100}committee skill' <<< "$content" || ! grep -Eiq 'return.{0,100}proposed design.{0,100}coordinator' <<< "$content"; then
    _fail "$1" "expected nested results to return through committee Planning"
    return
  fi
  _pass "$1"
}

test_lightweight_planning_returns_proposal_to_coordinator() {
  local file="$REPO_ROOT/skills/brainstorming-skip/SKILL.md"
  local content
  content="$(tr '\n' ' ' < "$file")"
  if ! grep -Eiq 'return.{0,100}proposed.design block.{0,100}coordinator' <<< "$content" || ! grep -Eiq 'does not stop the overall workflow' <<< "$content"; then
    _fail "$1" "expected lightweight proposal return without phase skip"
    return
  fi
  _pass "$1"
}

test_design_review_result_returns_before_approval_phase() {
  local file="$REPO_ROOT/skills/design-review/SKILL.md"
  local content
  content="$(tr '\n' ' ' < "$file")"
  if ! grep -Eiq 'reviewer.{0,100}returns? the verdict.{0,100}review phase' <<< "$content" || ! grep -Eiq 'coordinator.{0,100}explicit user approval' <<< "$content"; then
    _fail "$1" "expected review to return through its phase owner before approval"
    return
  fi
  _pass "$1"
}

test_ticket_context_returns_to_coordinator_without_claiming_phase_completion() {
  local file="$REPO_ROOT/skills/work-on-ticket/SKILL.md"
  local content
  content="$(tr '\n' ' ' < "$file")"
  if ! grep -Eiq 'route.{0,100}recovered ticket context.{0,100}coordinator' <<< "$content" || ! grep -Eiq 'does not satisfy upstream phases' <<< "$content"; then
    _fail "$1" "expected ticket return to undergo coordinator validation"
    return
  fi
  _pass "$1"
}

test_debugging_investigators_return_to_debugging_owner() {
  local file="$REPO_ROOT/skills/debugging/SKILL.md"
  local content
  content="$(tr '\n' ' ' < "$file")"
  if ! grep -Eiq 'investigators? return.{0,100}to the debugging phase' <<< "$content" || ! grep -Eiq 'debugging phase returns.{0,100}evidence.{0,100}coordinator' <<< "$content"; then
    _fail "$1" "expected investigation results to reconcile before coordinator handoff"
    return
  fi
  _pass "$1"
}

test_wave_readiness_result_returns_to_wave_planning_owner() {
  local file="$REPO_ROOT/skills/wave-planning/SKILL.md"
  local content
  content="$(tr '\n' ' ' < "$file")"
  if ! grep -Eiq 'reviewer.{0,100}returns? the verdict.{0,100}wave.planning' <<< "$content" || ! grep -Eiq 'return.{0,100}schedule.{0,100}coordinator' <<< "$content"; then
    _fail "$1" "expected readiness result to return through wave planning"
    return
  fi
  _pass "$1"
}

test_handoff_preserves_exact_skip_provenance() {
  local file="$REPO_ROOT/skills/_shared/workflow-artifacts.md"
  local content
  content="$(tr '\n' ' ' < "$file")"
  if ! grep -Eiq 'handoff, preserve the original baseline and exact skip provenance' <<< "$content"; then
    _fail "$1" "expected handoff state to retain exact skip provenance"
    return
  fi
  _pass "$1"
}

test_resume_reuses_valid_phase_evidence() {
  local file="$REPO_ROOT/skills/_shared/workflow-artifacts.md"
  local content
  content="$(tr '\n' ' ' < "$file")"
  if ! grep -Eiq 'on resume, validate provenance and current validity of evidence' <<< "$content" || ! grep -Eiq 'without repeating valid completed phases' <<< "$content"; then
    _fail "$1" "expected resume to validate and reuse still-valid evidence"
    return
  fi
  _pass "$1"
}

handoff_skill_files=(workflow-coordinator/SKILL.md _shared/workflow-artifacts.md research/SKILL.md brainstorming/SKILL.md brainstorming-standard/SKILL.md brainstorming-guided/SKILL.md brainstorming-committee/SKILL.md brainstorming-skip/SKILL.md design-review/SKILL.md work-on-ticket/SKILL.md debugging/SKILL.md wave-planning/SKILL.md subagent-driven-development/SKILL.md)

_prepare_claude_install() {
  local root="$1"
  local skills_target="$root/skills"
  local rules_target="$root/rules"
  local installer="$REPO_ROOT/install-claude.sh"
  local files=("${handoff_skill_files[@]}")
  local manifest=()
  local common_files=(workflow.md)
  local common_manifest=()
  SKILLS_SOURCE="$REPO_ROOT/skills"
  if ! _load_array CLAUDE_PLACEHOLDERS "$installer" || ! _load_array CLAUDE_SUBSTITUTIONS "$installer" || ! _load_function _skill_resolve_dst "$installer"; then
    return 1
  fi
  install_files_from_dir "$SKILLS_SOURCE" "$skills_target" skills manifest files _skill_resolve_dst || return 1
  substitute_tool_names "$skills_target" CLAUDE_PLACEHOLDERS CLAUDE_SUBSTITUTIONS || return 1
  install_files_from_dir "$REPO_ROOT/rules/common" "$rules_target" rules/common common_manifest common_files || return 1
  substitute_tool_names "$rules_target" CLAUDE_PLACEHOLDERS CLAUDE_SUBSTITUTIONS || return 1
}

_prepare_opencode_install() {
  local root="$1"
  local skills_target="$root/skills"
  local rules_target="$root/rules"
  local installer="$REPO_ROOT/install-opencode.sh"
  local files=("${handoff_skill_files[@]}")
  local manifest=()
  local common_files=(workflow.md)
  local common_manifest=()
  SKILLS_SOURCE="$REPO_ROOT/skills"
  if ! _load_array OPENCODE_PLACEHOLDERS "$installer" || ! _load_array OPENCODE_SUBSTITUTIONS "$installer" || ! _load_function _skill_resolve_dst "$installer"; then
    return 1
  fi
  install_files_from_dir "$SKILLS_SOURCE" "$skills_target" skills manifest files _skill_resolve_dst || return 1
  substitute_tool_names "$skills_target" OPENCODE_PLACEHOLDERS OPENCODE_SUBSTITUTIONS || return 1
  install_files_from_dir "$REPO_ROOT/rules/common" "$rules_target" rules/common common_manifest common_files || return 1
  substitute_tool_names "$rules_target" OPENCODE_PLACEHOLDERS OPENCODE_SUBSTITUTIONS || return 1
}

_prepare_codex_install() {
  local root="$1"
  local skills_target="$root/skills"
  local files=("${handoff_skill_files[@]}")
  local manifest=()
  local common_files=(workflow.md)
  local lang_selected=()
  local payload="$root/AGENTS.payload"
  local agents="$root/AGENTS.md"
  SKILLS_SOURCE="$REPO_ROOT/skills"
  RULES_SOURCE="$REPO_ROOT/rules"
  mkdir -p "$root" || return 1
  printf 'user-owned content\n' > "$agents" || return 1
  install_files_from_dir "$SKILLS_SOURCE" "$skills_target" .agents/skills manifest files _codex_skill_resolve_dst || return 1
  _codex_substitute_placeholders_tree "$skills_target" || return 1
  scan_no_unsubstituted_placeholders "$skills_target" || return 1
  _codex_render_agents_payload "$payload" common_files lang_selected || return 1
  _codex_upsert_managed_block "$agents" "$payload" || return 1
}

test_supported_installers_deliver_workflow_continuation_policy() {
  local claude_root="$TEST_TMP/claude-policy"
  local opencode_root="$TEST_TMP/opencode-policy"
  local codex_root="$TEST_TMP/codex-policy"
  local codex_agents="$codex_root/AGENTS.md"
  local claude_rule_content
  local opencode_rule_content
  local codex_managed_content
  local harness_root
  local file
  local harness
  local index
  if ! _prepare_claude_install "$claude_root"; then
    _fail "$1" "Claude installer helper failed"
    return
  fi
  if ! _prepare_opencode_install "$opencode_root"; then
    _fail "$1" "OpenCode installer helper failed"
    return
  fi
  if ! _prepare_codex_install "$codex_root"; then
    _fail "$1" "Codex installer helper failed"
    return
  fi
  local harness_roots=("$claude_root" "$opencode_root" "$codex_root")
  local harness_names=(Claude OpenCode Codex)
  for index in "${!harness_roots[@]}"; do
    harness_root="${harness_roots[$index]}"
    harness="${harness_names[$index]}"
    for file in "${handoff_skill_files[@]}"; do
      if [[ ! -f "$harness_root/skills/$file" ]]; then
        _fail "$1" "$harness installer did not copy $file"
        return
      fi
      if grep -q '{{' "$harness_root/skills/$file"; then
        _fail "$1" "$harness installer left a placeholder in $file"
        return
      fi
    done
  done
  if ! grep -Fq 'invoke that phase through `Skill`' "$claude_root/skills/workflow-coordinator/SKILL.md" || ! grep -Fq 'invoke that phase through `skill`' "$opencode_root/skills/workflow-coordinator/SKILL.md" || ! grep -Fq 'invoke that phase through `/skills or $skill-name`' "$codex_root/skills/workflow-coordinator/SKILL.md"; then
    _fail "$1" "an installer did not apply its native skill substitution"
    return
  fi
  claude_rule_content="$(tr '\n' ' ' < "$claude_root/rules/workflow.md")"
  opencode_rule_content="$(tr '\n' ' ' < "$opencode_root/rules/workflow.md")"
  if ! grep -Eiq 'actual coordinator-managed phase or assigned-task handoffs?' <<< "$claude_rule_content" || ! grep -Fq 'Pause for an actual user choice or approval' <<< "$claude_rule_content" || ! grep -Fq 'invoke that phase without routine prompting' <<< "$claude_rule_content" || ! grep -Fq 'not to each tool call or each interactive question' <<< "$claude_rule_content" || grep -q '{{' "$claude_root/rules/workflow.md"; then
    _fail "$1" "Claude rules lack the substituted common workflow policy"
    return
  fi
  if ! grep -Eiq 'actual coordinator-managed phase or assigned-task handoffs?' <<< "$opencode_rule_content" || ! grep -Fq 'Pause for an actual user choice or approval' <<< "$opencode_rule_content" || ! grep -Fq 'invoke that phase without routine prompting' <<< "$opencode_rule_content" || ! grep -Fq 'not to each tool call or each interactive question' <<< "$opencode_rule_content" || grep -q '{{' "$opencode_root/rules/workflow.md"; then
    _fail "$1" "OpenCode rules lack the substituted common workflow policy"
    return
  fi
  codex_managed_content="$(awk '/^<!-- elelem:codex:start -->$/ {inside=1; next} /^<!-- elelem:codex:end -->$/ {inside=0} inside' "$codex_agents" | tr '\n' ' ')"
  if ! grep -Fq '<!-- elelem:codex:start -->' "$codex_agents" || ! grep -Fq 'user-owned content' "$codex_agents" || ! grep -Eiq 'actual coordinator-managed phase or assigned-task handoffs?' <<< "$codex_managed_content" || ! grep -Fq 'Pause for an actual user choice or approval' <<< "$codex_managed_content" || ! grep -Fq 'invoke that phase without routine prompting' <<< "$codex_managed_content" || ! grep -Fq 'not to each tool call or each interactive question' <<< "$codex_managed_content" || grep -q '{{' "$codex_agents"; then
    _fail "$1" "Codex managed AGENTS content lacks the substituted workflow continuation rule"
    return
  fi
  _pass "$1"
}

run_case() {
  local name="$1"
  local function_name="test_$name"
  local function_status=0
  case_result_count=0
  case_result_status=""
  case_result_detail=""
  if ! declare -F "$function_name" > /dev/null; then
    case_result_count=1
    case_result_status="FAIL"
    case_result_detail="test function is missing: $function_name"
  elif "$function_name" "$name"; then
    function_status=0
  else
    function_status=$?
  fi
  if (( case_result_count != 1 )); then
    printf '[FAIL] %s: expected one case result, got %d (function exit %d)\n' "$name" "$case_result_count" "$function_status"
    (( failed++ )) || true
  elif [[ "$case_result_status" != "PASS" ]]; then
    printf '[FAIL] %s: %s\n' "$name" "$case_result_detail"
    (( failed++ )) || true
  elif (( function_status != 0 )); then
    printf '[FAIL] %s: test function exited %d after reporting pass\n' "$name" "$function_status"
    (( failed++ )) || true
  else
    printf '[PASS] %s\n' "$name"
    (( passed++ )) || true
  fi
  return 0
}

test_names=(
  coordinator_validates_returns_before_advancing
  coordinator_preserves_approval_gates
  coordinator_pauses_for_legitimate_constraints
  nested_results_return_to_their_owning_phase
  parallel_checks_require_stable_inputs
  parallel_checks_respect_dependency_barriers
  research_returns_questions_to_coordinator
  planning_router_returns_selected_mode_result_to_coordinator
  coordinator_never_invokes_itself_recursively
  standard_planning_returns_proposal_without_advancing_phase
  guided_planning_returns_proposal_without_advancing_phase
  committee_results_return_through_planning_owner
  lightweight_planning_returns_proposal_to_coordinator
  design_review_result_returns_before_approval_phase
  ticket_context_returns_to_coordinator_without_claiming_phase_completion
  debugging_investigators_return_to_debugging_owner
  wave_readiness_result_returns_to_wave_planning_owner
  handoff_preserves_exact_skip_provenance
  resume_reuses_valid_phase_evidence
  supported_installers_deliver_workflow_continuation_policy
)

for name in "${test_names[@]}"; do
  run_case "$name"
done

printf 'Cases: %d, Passed: %d, Failed: %d\n' "${#test_names[@]}" "$passed" "$failed"
(( failed == 0 ))
