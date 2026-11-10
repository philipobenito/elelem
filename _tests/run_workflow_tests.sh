#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/elelem-workflow-tests.XXXXXX")" || {
  printf '[FAIL] temporary_directory: could not create test directory\n' >&2
  exit 1
}
trap '[[ -n "${TEST_TMP:-}" ]] && rm -rf -- "$TEST_TMP"' EXIT

source "$REPO_ROOT/_install-common.sh"
source "$REPO_ROOT/install-codex.sh"

passed=0
failed=0
workflow_files=(
  "skills/workflow-coordinator/SKILL.md"
  "skills/research/SKILL.md"
  "skills/brainstorming/SKILL.md"
  "skills/work-on-ticket/SKILL.md"
  "skills/fast-path-implementation/SKILL.md"
  "skills/fast-path-implementation/fast-path-reviewer-prompt.md"
  "skills/wave-planning/SKILL.md"
  "skills/_shared/phase-evidence.md"
  "skills/_shared/workflow-artifacts.md"
  "skills/_shared/task-briefs.md"
  "skills/_shared/wave-readiness.md"
  "skills/_shared/test-pruning.md"
  "skills/test-pruning/SKILL.md"
  "skills/test-driven-development/SKILL.md"
  "skills/subagent-driven-development/SKILL.md"
  "skills/subagent-driven-development/implementer-prompt.md"
  "skills/subagent-driven-development/reviewer-prompt.md"
)
skill_files=(
  "skills/test-pruning/SKILL.md"
  "skills/workflow-coordinator/SKILL.md"
  "skills/research/SKILL.md"
  "skills/wave-planning/SKILL.md"
)

_pass() {
  printf '[PASS] %s\n' "$1"
  (( passed++ )) || true
}

_fail() {
  printf '[FAIL] %s: %s\n' "$1" "$2"
  (( failed++ )) || true
}

_load_array() {
  local array_name="$1"
  local installer="$2"
  local declaration
  declaration="$(awk -v name="$array_name" 'substr($0, 1, length(name) + 2) == name "=(" {copy=1} copy {print} copy && $0 == ")" {exit}' "$installer")"
  if [[ -z "$declaration" ]]; then
    return 1
  fi
  eval "$declaration"
}

_load_function() {
  local function_name="$1"
  local installer="$2"
  local declaration
  declaration="$(awk -v name="$function_name" 'substr($0, 1, length(name) + 4) == name "() {" {copy=1} copy {print} copy && $0 == "}" {exit}' "$installer")"
  if [[ -z "$declaration" ]]; then
    return 1
  fi
  eval "$declaration"
}

_check_required_files() {
  local file
  local missing=0
  for file in "${workflow_files[@]}"; do
    if [[ ! -f "$REPO_ROOT/$file" ]]; then
      _fail "required_file_${file//\//_}" "expected $file to exist"
      missing=1
    else
      _pass "required_file_${file//\//_}"
    fi
  done
  return "$missing"
}

_check_skill_frontmatter() {
  local file relative name frontmatter
  for relative in "${skill_files[@]}"; do
    file="$REPO_ROOT/$relative"
    name="${relative#skills/}"
    name="${name%/SKILL.md}"
    if [[ ! -f "$file" ]]; then
      continue
    fi
    frontmatter="$(sed -n '2,/^---$/p' "$file" | sed '$d')"
    if [[ "$(head -n 1 "$file")" != '---' ]] || ! awk 'NR > 1 && $0 == "---" {found=1; exit} END {exit !found}' "$file" || ! printf '%s\n' "$frontmatter" | grep -Eq "^name: ${name//\//-}$" || ! printf '%s\n' "$frontmatter" | grep -Eq '^name: [a-z0-9]+(-[a-z0-9]+)*$'; then
      _fail "skill_frontmatter_${name//\//_}" "expected YAML frontmatter with name ${name//\//-}"
    else
      _pass "skill_frontmatter_${name//\//_}"
    fi
  done
}

_copy_and_substitute_harness() {
  local harness="$1"
  local target="$2"
  local resolve_function="$3"
  local placeholders_ref="$4"
  local substitutions_ref="$5"
  local file manifest=() files=()
  local source_dir="$REPO_ROOT/skills"
  mkdir -p "$target"
  for file in "${workflow_files[@]}"; do
    if [[ ! -f "$source_dir/${file#skills/}" ]]; then
      _fail "${harness}_installer_copy_and_substitution" "source files are incomplete; cannot exercise installer helpers"
      return
    fi
    files+=("${file#skills/}")
  done
  install_files_from_dir "$source_dir" "$target" skills manifest files "$resolve_function"
  substitute_tool_names "$target" "$placeholders_ref" "$substitutions_ref"
  for file in "${files[@]}"; do
    if [[ ! -f "$target/$file" ]]; then
      _fail "${harness}_installer_copy_and_substitution" "installer helper did not copy $file"
      return
    fi
    if grep -q '{{' "$target/$file"; then
      _fail "${harness}_installer_copy_and_substitution" "unsubstituted tool placeholder remains in $file"
      return
    fi
  done
  _pass "${harness}_installer_copy_and_substitution"
}

test_claude_installer_copy_and_substitution() {
  local installer="$REPO_ROOT/install-claude.sh"
  SKILLS_SOURCE="$REPO_ROOT/skills"
  if ! _load_array CLAUDE_PLACEHOLDERS "$installer" || ! _load_array CLAUDE_SUBSTITUTIONS "$installer" || ! _load_function _skill_resolve_dst "$installer"; then
    _fail "claude_installer_copy_and_substitution" "could not extract installer maps or destination resolver"
    return
  fi
  _copy_and_substitute_harness claude "$TEST_TMP/claude/skills" _skill_resolve_dst CLAUDE_PLACEHOLDERS CLAUDE_SUBSTITUTIONS
}

test_opencode_installer_copy_and_substitution() {
  local installer="$REPO_ROOT/install-opencode.sh"
  SKILLS_SOURCE="$REPO_ROOT/skills"
  if ! _load_array OPENCODE_PLACEHOLDERS "$installer" || ! _load_array OPENCODE_SUBSTITUTIONS "$installer" || ! _load_function _skill_resolve_dst "$installer"; then
    _fail "opencode_installer_copy_and_substitution" "could not extract installer maps or destination resolver"
    return
  fi
  _copy_and_substitute_harness opencode "$TEST_TMP/opencode/skills" _skill_resolve_dst OPENCODE_PLACEHOLDERS OPENCODE_SUBSTITUTIONS
}

test_codex_installer_copy_and_substitution() {
  local target="$TEST_TMP/codex/skills"
  local file manifest=() files=()
  local source_dir="$REPO_ROOT/skills"
  mkdir -p "$target"
  for file in "${workflow_files[@]}"; do
    if [[ ! -f "$source_dir/${file#skills/}" ]]; then
      _fail "codex_installer_copy_and_substitution" "source files are incomplete; cannot exercise installer helpers"
      return
    fi
    files+=("${file#skills/}")
  done
  install_files_from_dir "$source_dir" "$target" .agents/skills manifest files _codex_skill_resolve_dst
  _codex_substitute_placeholders_tree "$target"
  if ! scan_no_unsubstituted_placeholders "$target"; then
    _fail "codex_installer_copy_and_substitution" "Codex installer scan found unresolved placeholders"
    return
  fi
  for file in "${files[@]}"; do
    if [[ ! -f "$target/$file" ]]; then
      _fail "codex_installer_copy_and_substitution" "installer helper did not copy $file"
      return
    fi
    if grep -q '{{' "$target/$file"; then
      _fail "codex_installer_copy_and_substitution" "unsubstituted tool placeholder remains in $file"
      return
    fi
  done
  _pass "codex_installer_copy_and_substitution"
}

test_test_pruning_contract_is_documented() {
  local file token requirement normalized missing=0
  local requirements=(
    "rules/common/testing.md|Meaningful Assertions"
    "rules/common/testing.md|named defect"
    "skills/_shared/test-pruning.md|uncertain"
    "skills/_shared/test-pruning.md|distinct"
    "skills/_shared/test-pruning.md|survivor"
    "skills/_shared/test-pruning.md|read-only"
    "skills/_shared/test-pruning.md|canonical value rule"
    "skills/_shared/test-pruning.md|pre-prune"
    "skills/_shared/test-pruning.md|discovery-count"
    "skills/_shared/test-pruning.md|workflow.md"
    "skills/_shared/test-pruning.md|{{DISPATCH_AGENT_TOOL}}"
    "skills/_shared/test-pruning.md|COMPLETE CURRENT MEANINGFUL ASSERTIONS SECTION VERBATIM"
    "skills/_shared/test-pruning.md|TASK_START_HEAD_AND_BASELINE_REFERENCE"
    "skills/_shared/test-pruning.md|PRE_EXISTING_CONTENT_IDENTITIES_OR_SNAPSHOTS"
    "skills/_shared/test-pruning.md|ACTUAL_TASK_DIFF_PATHS_AND_SCOPE_EVIDENCE"
    "skills/_shared/test-pruning.md|TEST_SOURCE_AND_CONTEXT"
    "skills/_shared/test-pruning.md|INPUT_PATHS_AND_CONTENT_IDENTITIES"
    "skills/_shared/test-pruning.md|ACTIVE_TASK_OWNERSHIP_AND_STABILITY_EVIDENCE"
    "skills/_shared/test-pruning.md|APPROVED_BEHAVIOUR_TO_REQUIREMENT_MAP"
    "skills/_shared/test-pruning.md|PRE_PRUNE_CHECKS_AND_DISCOVERY_COUNTS"
    "skills/_shared/test-pruning.md|POST_PRUNE_COMMAND_AND_COUNTING_METHOD"
    "skills/_shared/test-pruning.md|RECOVERY"
    "skills/_shared/test-pruning.md|survivor stability"
    "skills/test-driven-development/SKILL.md|TDD-only skip"
    "skills/test-driven-development/SKILL.md|Assertions protect named behaviour"
    "skills/subagent-driven-development/SKILL.md|pre-prune"
    "skills/subagent-driven-development/SKILL.md|post-prune"
    "skills/subagent-driven-development/SKILL.md|no nested audit dispatch"
    "skills/subagent-driven-development/implementer-prompt.md|baseline"
    "skills/subagent-driven-development/implementer-prompt.md|recovery"
    "skills/subagent-driven-development/implementer-prompt.md|Do not prune"
    "skills/subagent-driven-development/implementer-prompt.md|audit your own work"
    "skills/_shared/test-pruning.md|survivor requirements"
    "skills/subagent-driven-development/reviewer-prompt.md|Important finding"
    "README.md|test pruning"
    "README.md|live"
  )
  for requirement in "${requirements[@]}"; do
    file="${requirement%%|*}"
    token="${requirement#*|}"
    if [[ ! -f "$REPO_ROOT/$file" ]]; then
      _fail "test_pruning_contract_${file//\//_}_${token//[^[:alnum:]]/_}" "expected $file to document $token"
      missing=1
      continue
    fi
    normalized="$(tr '\n' ' ' < "$REPO_ROOT/$file" | tr -s '[:space:]' ' ')"
    if ! grep -Fqi "$token" <<< "$normalized"; then
      _fail "test_pruning_contract_${file//\//_}_${token//[^[:alnum:]]/_}" "expected $file to document $token"
      missing=1
    fi
  done
  if (( missing == 0 )); then
    _pass "test_pruning_contract_is_documented"
  fi
}

test_auditor_policy_categories_and_decisions_are_explicit() {
  local testing_rules="$REPO_ROOT/rules/common/testing.md"
  local content requirement pattern missing=0
  content="$(tr '\n' ' ' < "$testing_rules" | tr -s '[:space:]' ' ')"
  local requirements=(
    'decision categories|scaffolding.{0,120}implementation-detail.{0,120}duplicate.{0,120}timing-dependent'
    'verdicts|KEEP.{0,100}REMOVE.{0,100}MERGE'
    'category-first ordering|Classify each test.{0,160}scaffolding'
    'removal without defect claim|cannot name a production defect.{0,160}(remove|REMOVE)'
    'duplicate shared defect|duplicate when one retained survivor.{0,120}defect shared'
    'merge condition|small assertion.{0,120}KEEP survivor.{0,120}MERGE'
    'project precedence|higher-priority instructions.{0,100}canonical.{0,100}project rules.{0,100}generic categories'
    'category guard continuation|category guard.{0,120}later removal'
    'category guard condition|category guard permits removal only when a retained survivor detects the named defect or the auditor states that no defect can be caught, unless applicable project rules relax the guard'
    'wrong-layer source|wrong-layer.{0,120}project rules define'
    'survivor constraints|stable.{0,80}retained.{0,80}non-cyclic'
    'last-test protection|Never delete a test file or its last test'
  )
  for requirement in "${requirements[@]}"; do
    pattern="${requirement#*|}"
    if ! grep -Eiq "$pattern" <<< "$content"; then
      _fail "auditor_policy_${requirement%%|*}" "expected canonical policy for ${requirement%%|*}"
      missing=1
    fi
  done
  if (( missing == 0 )); then
    _pass "auditor_policy_categories_and_decisions_are_explicit"
  fi
}

test_auditor_rule_discovery_freezes_complete_harness_sources() {
  local helper="$REPO_ROOT/skills/_shared/test-pruning.md"
  local content requirement pattern missing=0
  content="$(tr '\n' ' ' < "$helper" | tr -s '[:space:]' ' ')"
  local requirements=(
    'Claude active sources|Claude Code.{0,220}(active user|user-scope).{0,120}project.{0,120}globs'
    'Claude scope caveat|Claude Code.{0,220}(user-scope caveat|globs.{0,80}not honoured)'
    'OpenCode active sources|OpenCode.{0,220}configured instruction globs.{0,140}project instructions'
    'OpenCode Claude fallback|OpenCode.{0,180}Claude Code fallback when enabled'
    'Codex active sources|Codex.{0,220}(active user|user and project).{0,160}AGENTS\.md'
    'Codex selected packs|Codex.{0,220}(selected packs|managed blocks)'
    'complete empty source set|none.{0,120}complete applicable project-rule set.{0,80}empty'
    'uncertain applicability blocks|applicability.{0,120}(cannot be established|uncertain).{0,100}block'
    'frozen identity|freeze.{0,120}(source identities|identity).{0,180}dispatch.{0,120}acceptance'
    'old active instructions|older conflicting active instructions.{0,160}(installed|active)'
    'source edit is not activation|source edit alone is not activation'
  )
  for requirement in "${requirements[@]}"; do
    pattern="${requirement#*|}"
    if ! grep -Eiq "$pattern" <<< "$content"; then
      _fail "auditor_discovery_${requirement%%|*}" "expected complete source discovery for ${requirement%%|*}"
      missing=1
    fi
  done
  if (( missing == 0 )); then
    _pass "auditor_rule_discovery_freezes_complete_harness_sources"
  fi
}

test_auditor_inventory_merge_recovery_and_dependency_invalidation() {
  local helper="$REPO_ROOT/skills/_shared/test-pruning.md"
  local content requirement pattern missing=0
  content="$(tr '\n' ' ' < "$helper" | tr -s '[:space:]' ' ')"
  local requirements=(
    'initial full inventory|initial (live )?inventory.{0,160}every test.{0,120}(older|parameterised)'
    'stable input identity|stable input identities.{0,120}(test|case|production|fixture)'
    'nonzero per-file and total counts|non-zero.{0,120}(per-file.{0,120}total.{0,120}discovery|discovery counts.{0,100}per current-live file and total)'
    'executed-case trace|trace.{0,160}(each|every).{0,100}(case|invocation)'
    'three auditor decisions|KEEP.{0,80}REMOVE.{0,80}MERGE'
    'merge source and keep survivor|MERGE.{0,180}current-audit KEEP survivor'
    'merge assertion evidence|added assertion.{0,120}production line.{0,120}reachable path.{0,120}failure reason'
    'withhold unsupported merge|otherwise report and withhold'
    'accepted merged snapshot|combined authorised edits.{0,120}accepted post-prune snapshot'
    'accepted edits do not self-invalidate|authorised.{0,100}do not invalidate'
    'transitive survivor invalidation|transitive.{0,160}survivor.{0,120}invalidation'
    're-audit after green|after GREEN.{0,120}re-audit'
    'removed source reassessment|removed source.{0,160}(reassess|reassessment)'
    'restore only unsupported removals|restore.{0,160}no longer supports removal'
    'scoped restoration safety|scoped recovery.{0,160}cannot apply without overwriting later work.{0,120}stop and ask'
    'recalculate actual coverage|actually applied and withheld.{0,160}coverage'
    'required coverage blocks|missing required behaviour coverage.{0,100}blocks'
  )
  for requirement in "${requirements[@]}"; do
    pattern="${requirement#*|}"
    if ! grep -Eiq "$pattern" <<< "$content"; then
      _fail "auditor_lifecycle_${requirement%%|*}" "expected audit lifecycle for ${requirement%%|*}"
      missing=1
    fi
  done
  if (( missing == 0 )); then
    _pass "auditor_inventory_merge_recovery_and_dependency_invalidation"
  fi
}

test_removal_handoff_requires_survivors_only_when_the_criterion_does() {
  local helper="$REPO_ROOT/skills/_shared/test-pruning.md"
  local content requirement pattern missing=0
  content="$(tr '\n' ' ' < "$helper" | tr -s '[:space:]' ' ')"
  local requirements=(
    'source and decision evidence always|Before assigning any removal or merge.{0,220}exact source.{0,160}decision evidence'
    'no survivor explicitly recorded|If the criterion requires no survivor, explicitly record `no survivor required`'
    'survivor evidence is criterion-dependent|Record survivor identity and evidence only when the decision criterion requires it'
    'duplicate removal survivor proof|duplicate.{0,20}REMOVE.{0,100}retained survivor.{0,120}shared defect'
    'merge survivor proof|MERGE.{0,100}current-audit `KEEP` survivor.{0,200}added assertion.{0,100}production line.{0,100}reachable path.{0,100}failure reason'
  )
  if grep -Fqi 'For removal, record the source and survivor.' <<< "$content"; then
    _fail "removal_handoff_unconditional_survivor" "removal handoff still requires a survivor unconditionally"
    missing=1
  fi
  for requirement in "${requirements[@]}"; do
    pattern="${requirement#*|}"
    if ! grep -Eiq "$pattern" <<< "$content"; then
      _fail "removal_handoff_${requirement%%|*}" "expected removal handoff to cover ${requirement%%|*}"
      missing=1
    fi
  done
  if (( missing == 0 )); then
    _pass "removal_handoff_requires_survivors_only_when_the_criterion_does"
  fi
}

test_uncertain_survivor_handling_does_not_override_named_removal() {
  local helper="$REPO_ROOT/skills/_shared/test-pruning.md"
  local content requirement pattern missing=0
  content="$(tr '\n' ' ' < "$helper" | tr -s '[:space:]' ' ')"
  local requirements=(
    'stable survivor requirements|Survivors must be real, stable, retained, and non-cyclic'
    'uncertain proof does not establish coverage|Uncertain survivor proof cannot establish retained coverage'
    'uncertain application is not applied|Uncertain safe application blocks applying a proposed removal or merge'
    'unverified coverage is not claimed|do not claim unverified coverage is preserved'
    'canonical removal criterion remains|These uncertainties do not override a REMOVE otherwise permitted by the canonical rule when the auditor cannot name a production defect'
  )
  if grep -Fqi 'Keep uncertain coverage' <<< "$content"; then
    _fail "uncertain_survivor_handling_unqualified_keep" "unqualified uncertainty handling can override the canonical removal criterion"
    missing=1
  fi
  for requirement in "${requirements[@]}"; do
    pattern="${requirement#*|}"
    if ! grep -Eiq "$pattern" <<< "$content"; then
      _fail "uncertain_survivor_${requirement%%|*}" "expected uncertainty handling for ${requirement%%|*}"
      missing=1
    fi
  done
  if (( missing == 0 )); then
    _pass "uncertain_survivor_handling_does_not_override_named_removal"
  fi
}

test_archived_removed_sources_are_separate_from_live_execution() {
  local helper="$REPO_ROOT/skills/_shared/test-pruning.md"
  local content requirement pattern missing=0
  content="$(tr '\n' ' ' < "$helper" | tr -s '[:space:]' ' ')"
  local requirements=(
    'complete live inventory|complete initial live inventory.{0,120}every test and parameterised case'
    'archive separate from live|archived removed-source records.{0,100}separate from the current live inventory'
    'trace live executions|trace.{0,80}each current-live case invocation'
    'archived reassessment input|Archived removed-source reassessments, separate from current-live cases'
    'preserved archived source|ARCHIVED_REMOVED_SOURCE_AND_CONTEXT'
    'archived snapshot identity|ARCHIVED_PRE_REMOVAL_SNAPSHOT_IDENTITIES'
    'archived prior checks and discovery|ARCHIVED_PRIOR_CHECKS_AND_DISCOVERY_EVIDENCE'
    'archive not expected to execute now|Archived cases are not required to execute in the current live run'
    'no invented archive evidence|Do not invent or fabricate prior evidence'
    'separate archived report rows|separate report rows for current-live cases and archived reassessments'
  )
  for requirement in "${requirements[@]}"; do
    pattern="${requirement#*|}"
    if ! grep -Eiq "$pattern" <<< "$content"; then
      _fail "archived_live_inventory_${requirement%%|*}" "expected archived-source separation for ${requirement%%|*}"
      missing=1
    fi
  done
  if (( missing == 0 )); then
    _pass "archived_removed_sources_are_separate_from_live_execution"
  fi
}

test_archived_trace_is_required_only_when_original_runner_needs_it() {
  local helper="$REPO_ROOT/skills/_shared/test-pruning.md"
  local content requirement pattern missing=0
  content="$(tr '\n' ' ' < "$helper" | tr -s '[:space:]' ' ')"
  local requirements=(
    'exact archived source and context|preserved exact source and surrounding context'
    'archived snapshot always required|pre-removal snapshot identities'
    'prior checks and discovery always required|Archived removed-source reassessments.{0,250}Always require.{0,240}actual prior check and discovery evidence'
    'original runner determines trace applicability|original runner.{0,100}whether historical trace evidence was applicable'
    'indirect original runner requires trace|Require prior trace-to-case evidence.{0,100}original runner was indirect'
    'direct original runner needs no trace|when the original runner was direct.{0,160}prior check and discovery evidence is sufficient.{0,40}trace is not required'
    'complete archive evidence blocks|If any required archived evidence is missing, unstable, or inconsistent, return.{0,20}BLOCKED'
    'complete archive evidence inputs|Archived evidence is complete only when.{0,200}(snapshot identities|prior check and discovery evidence)'
    'prompt identifies trace applicability|ARCHIVED_ORIGINAL_RUNNER_AND_TRACE_APPLICABILITY'
    'prompt has conditional trace field|ARCHIVED_PRIOR_TRACE_EVIDENCE_IF_APPLICABLE'
    'report explains conditional trace|Archived reassessment rows.{0,240}actual prior check/discovery evidence.{0,220}trace applicability'
    'live green remains mandatory|fresh.{0,50}stable GREEN result with exit status zero'
    'live discovery remains nonzero|non-zero discovery counts per current-live file and total'
    'pre-green removal remains blocked|A non-zero exit status blocks removal and auditor dispatch'
  )
  for requirement in "${requirements[@]}"; do
    pattern="${requirement#*|}"
    if ! grep -Eiq "$pattern" <<< "$content"; then
      _fail "archived_trace_applicability_${requirement%%|*}" "expected archived trace handling for ${requirement%%|*}"
      missing=1
    fi
  done
  if (( missing == 0 )); then
    _pass "archived_trace_is_required_only_when_original_runner_needs_it"
  fi
}

test_canonical_rule_resolution_uses_verified_active_scope() {
  local helper="$REPO_ROOT/skills/_shared/test-pruning.md"
  local content requirement pattern missing=0
  content="$(tr '\n' ' ' < "$helper" | tr -s '[:space:]' ' ')"
  local requirements=(
    'active source set|Claude Code and OpenCode.{0,180}complete, verified active instruction source set and current harness instruction context'
    'different install scopes|skill and active rule may be installed in different user or project scopes'
    'active source authority|select the source using active rule applicability.{0,120}harness'
    'frozen identity validation|verify.{0,20}selected source identity.{0,120}frozen inputs'
    'ambiguous authority blocks|If the active authoritative source.{0,160}missing, inconsistent, or ambiguous, block before dispatch'
    'no adjacency or guessed path|Do not infer the canonical rule source from adjacency to this helper or a guessed path'
    'no uninstalled fallback|Do not guess a path or fall back to an uninstalled source'
    'Codex managed block retained|Codex.{0,100}active elelem-managed `AGENTS.md` block'
    'Codex unique testing rule entry|unique `## rules/common/testing.md` rule entry'
    'canonical section copied verbatim|complete Meaningful Assertions section verbatim'
  )
  for requirement in "${requirements[@]}"; do
    pattern="${requirement#*|}"
    if ! grep -Eiq "$pattern" <<< "$content"; then
      _fail "canonical_rule_scope_${requirement%%|*}" "expected active-rule resolution for ${requirement%%|*}"
      missing=1
    fi
  done
  if (( missing == 0 )); then
    _pass "canonical_rule_resolution_uses_verified_active_scope"
  fi
}

test_auditor_contract_is_wired_to_workers_reviewers_docs_and_scenarios() {
  local requirement file token content missing=0
  local requirements=(
    'final application merge handoff|skills/_shared/test-pruning.md|MERGE'
    'final application current keep survivor|skills/_shared/test-pruning.md|current-audit KEEP'
    'final audit three decisions|skills/_shared/test-pruning.md|KEEP, REMOVE, or MERGE'
    'final delta review merged snapshot|skills/_shared/test-pruning.md|accepted post-prune snapshot'
    'readme category policy|README.md|timing-dependent'
    'readme merge policy|README.md|MERGE'
    'readme authority policy|README.md|active instruction sources'
    'manual shared defect policy|_tests/workflow_scenarios.md|shared defect'
    'manual no-defect case|_tests/workflow_scenarios.md|cannot name a production defect'
    'manual source change case|_tests/workflow_scenarios.md|source-set change'
    'manual withheld merge case|_tests/workflow_scenarios.md|withheld'
    'manual deleted-source case|_tests/workflow_scenarios.md|deleted source'
    'manual survivor invalidation case|_tests/workflow_scenarios.md|transitively'
    'manual tests remain unrun|_tests/workflow_scenarios.md|were not run'
    'manual dirty baseline recovery case|_tests/workflow_scenarios.md|Start with a dirty pre-existing test file and untracked fixture'
    'manual audit input stability case|_tests/workflow_scenarios.md|Change an exercised fixture or test while the auditor is reviewing'
    'manual empty scope and skip case|_tests/workflow_scenarios.md|Compare a task with no touched test-bearing files'
  )
  for requirement in "${requirements[@]}"; do
    file="${requirement#*|}"
    file="${file%%|*}"
    token="${requirement##*|}"
    content="$(tr '\n' ' ' < "$REPO_ROOT/$file" | tr -s '[:space:]' ' ')"
    if ! grep -Fqi "$token" <<< "$content"; then
      _fail "auditor_wiring_${requirement%%|*}" "expected $file to document $token"
      missing=1
    fi
  done
  if (( missing == 0 )); then
    _pass "auditor_contract_is_wired_to_workers_reviewers_docs_and_scenarios"
  fi
}

test_auditor_prompt_supplies_category_definitions_and_authority_inputs() {
  local helper="$REPO_ROOT/skills/_shared/test-pruning.md"
  local content requirement pattern missing=0
  content="$(tr '\n' ' ' < "$helper" | tr -s '[:space:]' ' ')"
  local requirements=(
    'classification-only purpose|Generic category meanings.{0,120}classify observable test shape only'
    'scaffolding without crashing|Scaffolding.{0,120}renders-without-crashing'
    'scaffolding exported shape|Scaffolding.{0,160}export/module/type-shape'
    'scaffolding literal constant|Scaffolding.{0,200}literal constant'
    'scaffolding own mock|Scaffolding.{0,220}its own mock'
    'scaffolding intermediate flow|Scaffolding.{0,240}intermediate full-flow step'
    'scaffolding redundant input classes|Scaffolding.{0,220}redundant input-class cases'
    'implementation detail examples|Implementation-detail.{0,180}internal call counts.{0,80}CSS class names.{0,80}DOM structure.{0,80}child props'
    'duplicate category definition|Duplicate.{0,120}same shared production defect'
    'timing category definition|Timing-dependent.{0,180}real timers.{0,100}waitFor.{0,20}chains.{0,100}deterministic signal'
    'wrong-layer definition|Wrong-layer.{0,120}only when applicable project test rules define the category'
    'categories are not value rules|do not infer KEEP, REMOVE, or MERGE solely from a category'
    'higher-priority instructions input|Applicable higher-priority testing instructions.{0,80}verbatim'
    'higher-priority empty set condition|none.{0,20}only when the complete active higher-priority set is established empty'
    'higher-priority source block|If applicable higher-priority testing instructions are missing or ambiguous, return BLOCKED'
    'exact merge paths input|Exact permitted write paths for automatic MERGE application'
    'merge path authority input|Authority and task-scope evidence for those paths'
    'merge path blocker|If exact permitted MERGE write paths or their scope evidence are missing or ambiguous, return BLOCKED'
    'no history fallback|Do not use inherited session history to fill missing instruction or write-scope inputs'
    'merge survivor path gate|current-audit KEEP.{0,160}path exactly matches an authorised path in the supplied permitted-write-path list'
    'merge outside scope withheld|path is outside the permitted write paths.{0,100}withhold'
  )
  for requirement in "${requirements[@]}"; do
    pattern="${requirement#*|}"
    if ! grep -Eiq "$pattern" <<< "$content"; then
      _fail "auditor_prompt_${requirement%%|*}" "expected shared auditor prompt to supply ${requirement%%|*}"
      missing=1
    fi
  done
  if (( missing == 0 )); then
    _pass "auditor_prompt_supplies_category_definitions_and_authority_inputs"
  fi
}

test_final_pruning_task_honors_scoped_pruning_audit_skips() {
  local requirement file token content missing=0
  local requirements=(
    'exact scope|exact user authorisation and the skipped file/case scope'
    'no pruning|confirm no removal or merge was applied in that scope'
    'skipped status|`SKIPPED` and unverified'
    'no audit evidence|not pruning-audit evidence'
    'no skipped audit|Do not dispatch or repeat a pruning audit for the skipped scope'
    'includes skipped-audit files|Prior task and cumulative reviews remain required for all task changes, including changes in files with skipped pruning audits'
    'skips only pruning evidence|Only skip pruning-evidence inspection for the explicitly skipped file/case scope'
    'continues unskipped checks|Continue all unskipped checks'
    'skip-record field|PRUNING_AUDIT_SKIP_RECORDS_OR_NONE'
    'explicit none|`none` when no pruning-audit skip was authorised'
    'skip source|exact source and instruction text'
    'skip file scope|skipped test-bearing file/case scope'
    'skip reason and consequence|reason and consequence'
    'absent record blocks|If the skip record is absent or incomplete, report BLOCKED'
    'no inferred skip|Do not infer an authorised skip from a missing record or audit evidence'
  )
  for requirement in "${requirements[@]}"; do
    file='skills/_shared/test-pruning.md'
    token="${requirement##*|}"
    content="$(tr '\n' ' ' < "$REPO_ROOT/$file" | tr -s '[:space:]' ' ')"
    if ! grep -Fqi "$token" <<< "$content"; then
      _fail "reviewer_audit_skip_${requirement%%|*}" "expected $file to document $token"
      missing=1
    fi
  done
  if (( missing == 0 )); then
    _pass "final_pruning_task_honors_scoped_pruning_audit_skips"
  fi
}

test_final_pruning_review_accepts_runner_appropriate_pruning_evidence() {
  local file requirement token content missing=0
  local reviewer_prompts=(
    'skills/_shared/test-pruning.md'
  )
  local requirements=(
    'current live discovery counts|non-zero per-file and total discovery counts'
    'indirect runner trace requirement|For indirect runners, require trace-to-case execution evidence'
    'direct runner evidence accepted|For direct runners, accept actual check output and discovery evidence without requiring a trace'
    'post-prune counts remain checked|post-prune discovery counts must match actual applied decisions and remain non-zero per file and in total'
    'last test protection remains|No file or last test may be deleted'
    'archived source snapshot and prior checks|verify exact preserved source and context, pre-removal snapshot identity, and actual prior check and discovery evidence for each archived source'
    'archived trace conditional|Require historical trace evidence only for an indirect original runner; for a direct original runner, prior check and discovery evidence is sufficient without a trace.'
    'missing archive evidence blocks|Missing or unstable required archived evidence blocks reassessment'
  )
  for file in "${reviewer_prompts[@]}"; do
    content="$(tr '\n' ' ' < "$REPO_ROOT/$file" | tr -s '[:space:]' ' ')"
    for requirement in "${requirements[@]}"; do
      token="${requirement#*|}"
      if ! grep -Fq "$token" <<< "$content"; then
        _fail "reviewer_runner_evidence_${file##*/}_${requirement%%|*}" "expected $file to check ${requirement%%|*}"
        missing=1
      fi
    done
  done
  if (( missing == 0 )); then
    _pass "final_pruning_review_accepts_runner_appropriate_pruning_evidence"
  fi
}

test_final_pruning_runs_once_after_cumulative_reviewer_pass() {
  local requirement file pattern content missing=0
  local requirements=(
    'executor ordering|skills/subagent-driven-development/SKILL.md|cumulative final reviewer.*PASS.*invoke.*test-pruning'
    'coordinator ordering|skills/workflow-coordinator/SKILL.md|cumulative final reviewer.*PASS.*test-pruning'
    'one final task|skills/subagent-driven-development/SKILL.md|one separate final review-phase task'
    'approval is not trigger|skills/test-pruning/SKILL.md|not user approval'
    'single detailed procedure|skills/test-pruning/SKILL.md|../_shared/test-pruning.md'
    'union scope|skills/_shared/test-pruning.md|union of actually touched test-bearing paths across all implementation tasks'
    'correction history|skills/_shared/test-pruning.md|reviewer corrections, reverted edits and rename mappings'
    'missing path blocker|skills/_shared/test-pruning.md|Missing or unexplained deleted paths block'
    'no unrelated scope|skills/_shared/test-pruning.md|Do not include unrelated user work'
    'workflow baseline|skills/_shared/test-pruning.md|immutable workflow baseline'
    'task baseline|skills/_shared/test-pruning.md|task-start.*baseline'
    'empty live scope|skills/_shared/test-pruning.md|NOT APPLICABLE.*empty live scope, dispatch no auditor, apply no edits and perform no delta review.*Final verification still follows'
    'rename resolution|skills/_shared/test-pruning.md|resolve rename chains to current live destinations, deduplicate destinations'
    'reverted path retained|skills/_shared/test-pruning.md|Include a touched file even when its final contents equal its baseline'
    'auditor final review input|skills/_shared/test-pruning.md|CUMULATIVE_FINAL_REVIEW_PASS_AND_REVISION_OR_SEQUENCING_AUTHORISATION'
    'bounded delta review scope|skills/_shared/test-pruning.md|Do not expand this review into another cumulative implementation review or whole-workflow pruning audit'
    'pruning skip preserves gates|skills/_shared/test-pruning.md|pruning skip authorises no pruning edits and waives neither ordinary coverage review nor final verification'
    'substantive correction boundary|skills/_shared/test-pruning.md|Substantive corrections return to the proper implementation/review boundary'
    'conditional delta review|skills/_shared/test-pruning.md|Only if pruning actually edits tests.*independent.*pruning-delta review'
    'no-change review|skills/_shared/test-pruning.md|No-change audits need no delta review'
    'verification last|skills/subagent-driven-development/SKILL.md|final verification after the last pruning edit and review correction'
    'no automatic loop|skills/_shared/test-pruning.md|Do not repeat cumulative review or restart pruning by default'
    'review skip sequencing|skills/_shared/test-pruning.md|cumulative-review skip is not a passing verdict.*explicit sequencing authorisation'
    'failure blocks|skills/_shared/test-pruning.md|Failures block completion'
    'targeted recovery|skills/_shared/test-pruning.md|one scheduled final task.*targeted evidence recovery'
    'ordinary worker handoff|skills/subagent-driven-development/implementer-prompt.md|Report changed paths and rename mappings, not a whole-file test/case inventory'
    'TDD handoff|skills/test-driven-development/SKILL.md|not a whole-file test/case inventory'
    'task history state|skills/_shared/workflow-artifacts.md|touched-path history.*reverted edits.*rename mappings'
    'brief history|skills/_shared/task-briefs.md|changed paths and rename mappings'
    'canonical timing|rules/common/testing.md|separate final task after cumulative final reviewer.*PASS'
    'workflow timing|rules/common/workflow.md|final test-pruning task.*final verification'
    'skill timing|rules/common/skills-policy.md|test-pruning.*cumulative final reviewer.*PASS'
  )
  for requirement in "${requirements[@]}"; do
    file="${requirement#*|}"
    pattern="${file#*|}"
    file="${file%%|*}"
    content=''
    [[ -f "$REPO_ROOT/$file" ]] && content="$(tr '\n' ' ' < "$REPO_ROOT/$file" | tr -s '[:space:]' ' ')"
    if ! grep -Eiq "$pattern" <<< "$content"; then
      _fail "final_pruning_${requirement%%|*}" "expected $file to protect ${requirement%%|*}"
      missing=1
    fi
  done
  (( missing != 0 )) || _pass "final_pruning_runs_once_after_cumulative_reviewer_pass"
}

test_cumulative_review_pass_adapts_the_actual_reviewer_result() {
  local file requirement pattern content missing=0
  local files=(
    'skills/subagent-driven-development/SKILL.md'
    'skills/_shared/test-pruning.md'
  )
  local requirements=(
    'favourable performed review|PASS.{0,180}only.{0,180}actually performed.{0,180}cumulative review'
    'producer status and readiness|Status.{0,30}REVIEWED.{0,80}Ready to merge.{0,30}Yes'
    'severity gate|no unresolved Critical or Important findings'
    'exact current revision|exact current cumulative revision'
    'raw result retained|retain.{0,120}raw reviewer result'
    'reviewer provenance retained|reviewer provenance.{0,160}(identity|session|source)'
    'reviewed alone rejected|REVIEWED.{0,30}alone is not sufficient'
    'adverse result rejected|With fixes.{0,30}No.{0,30}BLOCKED.{0,30}SKIPPED.{0,120}never map to.{0,20}PASS'
    'stale result rejected|stale.{0,80}missing.{0,120}never map to.{0,20}PASS'
    'skip exception preserves truth|explicit sequencing authorisation.{0,180}without inventing.{0,20}PASS'
  )
  for file in "${files[@]}"; do
    content="$(tr '\n' ' ' < "$REPO_ROOT/$file" | tr -s '[:space:]' ' ')"
    for requirement in "${requirements[@]}"; do
      pattern="${requirement#*|}"
      if ! grep -Eiq "$pattern" <<< "$content"; then
        _fail "cumulative_review_adapter_${file//\//_}_${requirement%%|*}" "expected $file to protect ${requirement%%|*}"
        missing=1
      fi
    done
  done
  (( missing != 0 )) || _pass 'cumulative_review_pass_adapts_the_actual_reviewer_result'
}

test_ordinary_task_handoffs_do_not_require_pruning_evidence() {
  local file content missing=0
  local files=(
    'skills/subagent-driven-development/reviewer-prompt.md'
    'skills/fast-path-implementation/fast-path-reviewer-prompt.md'
  )
  for file in "${files[@]}"; do
    content="$(tr '\n' ' ' < "$REPO_ROOT/$file" | tr -s '[:space:]' ' ')"
    if ! grep -Fq 'No pruning evidence or whole-file inventory is a task-review prerequisite' <<< "$content" || grep -Eq 'PRUNING_AUDIT_SKIP_RECORDS_OR_NONE|For a task that touched test-bearing files, inspect the pruning evidence' <<< "$content"; then
      _fail "ordinary_review_${file//\//_}" 'task review must not depend on a pruning audit or inventory'
      missing=1
    fi
  done
  (( missing != 0 )) || _pass 'ordinary_task_handoffs_do_not_require_pruning_evidence'
}

test_tdd_completion_gate_is_behaviour_based() {
  local file="$REPO_ROOT/skills/test-driven-development/SKILL.md"
  local content
  content="$(tr '\n' ' ' < "$file")"
  if grep -Fq 'Every new function or method has a test' <<< "$content" || grep -Fq 'Edge cases and error paths covered' <<< "$content"; then
    _fail "tdd_completion_gate_is_behaviour_based" "generic function and edge-case checklist remains"
    return
  fi
  if ! grep -Eiq 'Every new (or changed )?behaviour' <<< "$content" || ! grep -Eiq 'cases?[^.]{0,120}(defined|derived|mapped)[^.]{0,120}approved behaviours' <<< "$content"; then
    _fail "tdd_completion_gate_is_behaviour_based" "expected new behaviours and behaviour-defined cases in the completion gate"
    return
  fi
  _pass "tdd_completion_gate_is_behaviour_based"
}

test_pruning_safety_gates_are_explicit() {
  local helper="$REPO_ROOT/skills/_shared/test-pruning.md"
  local helper_content
  helper_content="$(tr '\n' ' ' < "$helper")"
  if ! grep -Eiq 'non-zero exit (status|code)' <<< "$helper_content" || ! grep -Eiq 'blocks? (any )?removal' <<< "$helper_content"; then
    _fail "pruning_safety_gates_are_explicit" "a non-zero pre-prune check must block removals"
    return
  fi
  if ! grep -Eiq 'coordinator[^.]{0,100}assigns[^.]{0,100}restoration[^.]{0,100}implementation worker' <<< "$helper_content" || ! grep -Eiq 'coordinator[^.]{0,100}(must not|does not|never)[^.]{0,80}(edit|restor|apply)' <<< "$helper_content"; then
    _fail "pruning_safety_gates_are_explicit" "restoration must be assigned to a worker, not coordinator edits"
    return
  fi
  _pass "pruning_safety_gates_are_explicit"
}

test_auditor_rule_source_is_harness_aware_and_bounded() {
  local helper="$REPO_ROOT/skills/_shared/test-pruning.md"
  local content requirement pattern missing=0
  content="$(tr '\n' ' ' < "$helper")"
  local requirements=(
    'Claude Code source|Claude Code.{0,160}rules/common/testing\.md'
    'OpenCode source|OpenCode.{0,160}rules/common/testing\.md'
    'Codex source|Codex.{0,200}(AGENTS\.md.{0,100}rules/common/testing\.md|rules/common/testing\.md.{0,100}AGENTS\.md)'
    'Codex managed block|Codex.{0,200}(active.{0,100}elelem-managed.{0,100}AGENTS\.md|AGENTS\.md.{0,100}active.{0,100}elelem-managed)'
    'exact section|only.{0,100}Meaningful Assertions section.{0,100}verbatim'
    'section boundary|next level-two heading'
    'unavailable authority|authoritative.{0,160}(unavailable|cannot be retrieved)'
    'blocked dispatch|block.{0,100}dispatch'
  )
  for requirement in "${requirements[@]}"; do
    pattern="${requirement#*|}"
    if ! grep -Eiq "$pattern" <<< "$content"; then
      _fail "auditor_rule_source_${requirement%%|*}" "expected harness-specific authoritative rule retrieval contract"
      missing=1
    fi
  done
  if (( missing == 0 )); then
    _pass "auditor_rule_source_is_harness_aware_and_bounded"
  fi
}

test_audit_invalidation_uses_accepted_green_snapshot() {
  local helper="$REPO_ROOT/skills/_shared/test-pruning.md"
  local content
  content="$(tr '\n' ' ' < "$helper")"
  if ! grep -Eiq 'accepted post-prune snapshot' <<< "$content" || ! grep -Eiq 'exact authorised pruning changes' <<< "$content" || ! grep -Eiq 'authorised pruning changes.{0,80}(do not|must not) invalidate' <<< "$content"; then
    _fail "audit_invalidation_uses_accepted_green_snapshot" "invalidation must distinguish accepted pruning changes from later input changes"
    return
  fi
  _pass "audit_invalidation_uses_accepted_green_snapshot"
}

test_test_pruning_helper_installs_and_skill_links_resolve() {
  local harness root skill relative target unresolved=0
  local harnesses=(claude opencode codex)
  local skills=("test-driven-development/SKILL.md" "subagent-driven-development/SKILL.md" "test-pruning/SKILL.md")
  for harness in "${harnesses[@]}"; do
    root="$TEST_TMP/$harness/skills"
    for skill in "${skills[@]}"; do
      relative="../_shared/test-pruning.md"
      if [[ ! -f "$root/$skill" ]] || ! grep -Fq "$relative" "$root/$skill" || [[ ! -f "$root/$(dirname "$skill")/$relative" ]]; then
        _fail "${harness}_test_pruning_skill_link_${skill//\//_}" "expected the installed skill link to resolve to the shared helper"
        unresolved=1
      else
        _pass "${harness}_test_pruning_skill_link_${skill//\//_}"
      fi
    done
  done
  (( unresolved == 0 ))
}

test_stale_workflow_lifecycle_instructions_are_absent() {
  local file stale=0
  local targets=(
    "rules/common/workflow.md"
    "rules/common/skills-policy.md"
    "skills/brainstorming/SKILL.md"
  )
  local patterns=(
    'The Brainstorming Router Is the Design Step'
    'The router enters plan mode and asks the user to pick one of four modes'
    'Before any code edit, no matter how small: brainstorming'
  )
  local index
  for file in "${targets[@]}"; do
    if [[ ! -f "$REPO_ROOT/$file" ]]; then
      continue
    fi
    for index in "${!patterns[@]}"; do
      if grep -Fq "${patterns[$index]}" "$REPO_ROOT/$file"; then
        _fail "stale_workflow_lifecycle_${index}_${file//\//_}" "obsolete lifecycle instruction remains in $file"
        stale=1
      fi
    done
  done
  if (( stale == 0 )); then
    _pass "stale_workflow_lifecycle_instructions_are_absent"
  fi
}

test_gitignore_excludes_workflow_artifacts() {
  local synthetic="$REPO_ROOT/.elelem/workflows/automated-test-probe.md"
  if git -C "$REPO_ROOT" check-ignore -q --no-index "$synthetic"; then
    _pass "gitignore_excludes_workflow_artifacts"
  else
    _fail "gitignore_excludes_workflow_artifacts" "git check-ignore did not exclude /.elelem/workflows/"
  fi
}

_is_source_reference() {
  local reference="$1"
  [[ "$reference" =~ ^(\./|\.\./)[A-Za-z0-9_./-]+\.md$ ]] && return 0
  case "$reference" in
    workflow-artifacts.md|task-briefs.md|wave-readiness.md) return 0 ;;
  esac
  return 1
}

test_new_backticked_source_references_resolve() {
  local relative file reference target unresolved=0 inspected=0
  for relative in "${workflow_files[@]}"; do
    file="$REPO_ROOT/$relative"
    [[ -f "$file" ]] || continue
    while IFS= read -r reference; do
      _is_source_reference "$reference" || continue
      (( inspected++ )) || true
      if [[ "$reference" == "./"* || "$reference" == "../"* ]]; then
        target="$(dirname "$file")/$reference"
      else
        target="$REPO_ROOT/skills/_shared/$reference"
      fi
      if [[ ! -e "$target" ]]; then
        _fail "source_reference_${relative//\//_}" "referenced source file does not exist: $reference"
        unresolved=1
      fi
    done < <(grep -Eo '`[^`]+\.md`' "$file" | sed -E 's/^`([^`]*)`$/\1/' || true)
  done
  if (( inspected == 0 )); then
    _fail "new_backticked_source_references_resolve" "no source references were available to inspect"
  elif (( unresolved == 0 )); then
    _pass "new_backticked_source_references_resolve"
  fi
}

_check_readiness_contract_reference() {
  local relative="$1"
  local test_name="$2"
  local file="$REPO_ROOT/$relative"
  local token
  local missing=0
  local tokens=(
    '../_shared/wave-readiness.md'
    'readiness review'
    'SKIPPED'
    'scope'
    'planner'
    'checks'
  )
  for token in "${tokens[@]}"; do
    if [[ "$token" == 'readiness review' ]]; then
      grep -Eiq 'readiness[[:space:]-]+review' "$file" && continue
    elif grep -Fq "$token" "$file"; then
      continue
    fi
    _fail "$test_name" "expected $relative to reference readiness contract token: $token"
    missing=1
  done
  if (( missing == 0 )); then
    _pass "$test_name"
  fi
}

test_parallel_agent_readiness_contract_reference() {
  _check_readiness_contract_reference "skills/dispatching-parallel-agents/SKILL.md" "parallel_agent_readiness_contract_reference"
}

test_fast_path_readiness_contract_reference() {
  _check_readiness_contract_reference "skills/fast-path-implementation/SKILL.md" "fast_path_readiness_contract_reference"
}

test_phase_evidence_contract() {
  local relative="skills/_shared/phase-evidence.md"
  local content="" requirement pattern
  local requirements=(
    'boundary validation|entry, transitions, handover, resume, reuse and execution'
    'ordered upstream gate|validate applicable upstream phases in order'
    'scope identity|scope, revision and current assumptions'
    'procedure provenance|actual procedure provenance'
    'required outputs|outputs and required user choices'
    'invocation is insufficient|Loading a skill.*cannot establish procedural work'
    'later approval is insufficient|later review or approval cannot establish omitted procedures'
    'Research dialogue|Research:.*dialogue.*separately user-selected alternative'
    'Planning method|Planning:.*explicit method selection.*selected-mode invocation.*proposal'
    'separate committee choice|Planning committee.*cannot retrospectively authorise autonomous Research'
    'skip provenance|exact-source user instruction.*scope, reason and consequence'
    'implement is not skip|implement.*mode switch.*not.*skip'
    'lightweight method is not skip|brainstorming-skip.*not a phase skip'
    'missing dependent inputs|Missing dependent inputs still block'
    'valid delayed recording|Record legitimate prior evidence later only with accessible provenance'
    'unsupported recovery|earliest unsupported phase'
    'no fabricated history|Do not invent history or backfill unsupported claims'
    'preserve valid work|Preserve useful findings, code, user work and genuinely valid evidence'
    'affected downstream revalidation|revalidate affected downstream reviews, approval and readiness'
    'bounded persistence|existing.*workflow.md.*no separate report'
    'not per tool call|not.*per-tool-call.*checks'
    'procedural limitation|procedural gate, not runtime enforcement'
  )
  if [[ -f "$REPO_ROOT/$relative" ]]; then
    content="$(tr '\n' ' ' < "$REPO_ROOT/$relative" | tr -s '[:space:]' ' ')"
  fi
  for requirement in "${requirements[@]}"; do
    pattern="${requirement#*|}"
    if grep -Eiq "$pattern" <<< "$content"; then
      _pass "phase_evidence_${requirement%%|*}"
    else
      _fail "phase_evidence_${requirement%%|*}" "expected $relative to protect this phase evidence requirement"
    fi
  done
}

test_phase_evidence_boundary_references() {
  local requirement file token content
  local requirements=(
    'rules/common/workflow.md|skills/_shared/phase-evidence.md'
    'rules/common/workflow.md|before implementation-oriented proposals'
    'rules/common/skills-policy.md|skills/_shared/phase-evidence.md'
    'skills/workflow-coordinator/SKILL.md|../_shared/phase-evidence.md'
    'skills/workflow-coordinator/SKILL.md|entry, transitions, handover, resume, reuse and execution'
    'skills/_shared/workflow-artifacts.md|./phase-evidence.md'
    'skills/research/SKILL.md|../_shared/phase-evidence.md'
    'skills/brainstorming/SKILL.md|../_shared/phase-evidence.md'
    'skills/work-on-ticket/SKILL.md|upstream gaps to the coordinator'
    'skills/fast-path-implementation/SKILL.md|upstream gaps to the coordinator'
    'skills/subagent-driven-development/SKILL.md|upstream gaps to the coordinator'
    'README.md|procedural gate, not runtime enforcement'
  )
  for requirement in "${requirements[@]}"; do
    file="${requirement%%|*}"
    token="${requirement#*|}"
    content="$(tr '\n' ' ' < "$REPO_ROOT/$file" | tr -s '[:space:]' ' ')"
    if grep -Fqi "$token" <<< "$content"; then
      _pass "phase_evidence_boundary_${file//\//_}_${token//[^[:alnum:]]/_}"
    else
      _fail "phase_evidence_boundary_${file//\//_}_${token//[^[:alnum:]]/_}" "expected boundary contract: $token"
    fi
  done
}

test_phase_evidence_installed_links_resolve() {
  local harness root relative link
  local harnesses=(claude opencode codex)
  local files=(
    'workflow-coordinator/SKILL.md' 'research/SKILL.md' 'brainstorming/SKILL.md'
    'work-on-ticket/SKILL.md' 'fast-path-implementation/SKILL.md'
    'subagent-driven-development/SKILL.md' '_shared/workflow-artifacts.md'
  )
  for harness in "${harnesses[@]}"; do
    root="$TEST_TMP/$harness/skills"
    for relative in "${files[@]}"; do
      link='../_shared/phase-evidence.md'
      [[ "$relative" == '_shared/workflow-artifacts.md' ]] && link='./phase-evidence.md'
      if [[ -f "$root/$relative" ]] && grep -Fq "$link" "$root/$relative" && [[ -f "$root/$(dirname "$relative")/$link" ]]; then
        _pass "${harness}_phase_evidence_link_${relative//\//_}"
      else
        _fail "${harness}_phase_evidence_link_${relative//\//_}" "expected installed boundary reference to resolve to the canonical helper"
      fi
    done
  done
}

test_required_files_check_is_registered() {
  local test_call_count
  test_call_count="$(sed -n '/^_check_skill_frontmatter$/,/^total=/p' "$0" | grep -Fxc 'test_required_files_exist' || true)"
  if [[ "$test_call_count" != 1 ]]; then
    _fail "required_files_check_is_registered" "expected test_required_files_exist once in the suite invocation block, found $test_call_count"
    return
  fi
  _pass "required_files_check_is_registered"
}

test_required_files_exist() {
  _check_required_files || true
}

test_wave_planning_maximises_safe_static_width() {
  local file content requirement pattern missing=0
  local requirements=(
    'skills/wave-planning/SKILL.md|earliest safe wave.{0,100}verified.{0,40}capacity'
    'skills/wave-planning/SKILL.md|concrete reasons.{0,100}serialisation.{0,100}concurrency one'
    'skills/wave-planning/SKILL.md|cohesive.{0,100}multiple.{0,100}RED/GREEN cycles'
    'skills/_shared/wave-readiness.md|earliest safe wave.{0,100}verified.{0,40}capacity'
    'skills/_shared/wave-readiness.md|concrete reasons.{0,100}serialisation.{0,100}concurrency one'
    'skills/_shared/task-briefs.md|multiple.{0,100}RED/GREEN cycles'
    'skills/subagent-driven-development/SKILL.md|batch.{0,100}in-scope.{0,100}corrections.{0,100}re-review'
  )
  for requirement in "${requirements[@]}"; do
    file="${requirement%%|*}"
    pattern="${requirement#*|}"
    content="$(tr '\n' ' ' < "$REPO_ROOT/$file" | tr -s '[:space:]' ' ')"
    if ! grep -Eiq "$pattern" <<< "$content"; then
      _fail "wave_width_${file//\//_}" "expected safe wave-width behaviour: $pattern"
      missing=1
    fi
  done
  if (( missing == 0 )); then
    _pass "wave_planning_maximises_safe_static_width"
  fi
}

test_cumulative_audit_follows_reviews_and_barriers() {
  local file content requirement pattern missing=0
  local requirements=(
    'rules/common/workflow.md|cumulative.{0,100}audit.{0,160}task reviews.{0,100}wave barriers.{0,160}final.{0,40}review'
    'rules/common/skills-policy.md|cumulative.{0,100}audit.{0,140}task reviews.{0,100}wave barriers'
    'skills/workflow-coordinator/SKILL.md|cumulative.{0,100}audit.{0,140}task reviews.{0,100}wave barriers.{0,140}final.{0,40}review'
    'skills/subagent-driven-development/SKILL.md|cumulative.{0,100}audit.{0,140}task reviews.{0,100}wave barriers.{0,140}final.{0,40}review'
    'skills/_shared/test-pruning.md|union of actual.{0,100}test-bearing.{0,100}tasks.{0,100}corrections'
    'skills/_shared/test-pruning.md|newly touched files.{0,100}audit.{0,40}full'
    'skills/_shared/test-pruning.md|unaffected decisions.{0,100}stable.{0,40}evidence'
    'skills/subagent-driven-development/reviewer-prompt.md|task review.{0,100}deferred.{0,100}final.{0,40}audit'
    'skills/fast-path-implementation/fast-path-reviewer-prompt.md|task review.{0,100}deferred.{0,100}final.{0,40}audit'
    'skills/test-driven-development/SKILL.md|cumulative.{0,100}final.{0,40}audit'
    'README.md|cumulative.{0,100}audit.{0,140}task reviews.{0,100}wave barriers'
    '_tests/workflow_scenarios.md|cumulative.{0,100}audit.{0,140}task reviews.{0,100}wave barriers'
  )
  for requirement in "${requirements[@]}"; do
    file="${requirement%%|*}"
    pattern="${requirement#*|}"
    content="$(tr '\n' ' ' < "$REPO_ROOT/$file" | tr -s '[:space:]' ' ')"
    if ! grep -Eiq "$pattern" <<< "$content"; then
      _fail "cumulative_audit_${file//\//_}" "expected cumulative audit behaviour: $pattern"
      missing=1
    fi
  done
  if (( missing == 0 )); then
    _pass "cumulative_audit_follows_reviews_and_barriers"
  fi
}

_write_expected_installed_skill() {
  perl -0777 -e '
    my @names = qw(ASK_USER_QUESTION_TOOL ENTER_PLAN_TOOL EXIT_PLAN_TOOL TASK_TRACKER_TOOL DISPATCH_AGENT_TOOL INVOKE_SKILL_TOOL READ_FILE_TOOL WRITE_FILE_TOOL EDIT_FILE_TOOL GREP_TOOL GLOB_TOOL SHELL_EXEC_TOOL MODEL_ENUMERATION);
    my %values = (
      claude => [q~AskUserQuestion~, q~EnterPlanMode~, q~ExitPlanMode~, q~TodoWrite~, q~Agent~, q~Skill~, q~Read~, q~Write~, q~Edit~, q~Grep~, q~Glob~, q~Bash~, q~reading the `model` enum on the Agent tool schema, which is the set of values the harness will accept~],
      opencode => [q~question~, q~entering plan mode (in OpenCode, plan mode is toggled by the user pressing Tab; ask the user to enter plan mode before reviewing the design)~, q~exiting plan mode (in OpenCode, the user toggles out of plan mode with Tab after approving the design; present the design and wait for explicit approval before any code edit)~, q~todowrite~, q~subagent~, q~skill~, q~read~, q~write~, q~edit~, q~grep~, q~glob~, q~bash~, q~running `opencode models` with the bash tool, which lists every available model, one per line~],
      codex => [q~request_user_input~, q~STOP and ask the user to switch to Plan mode, do not continue until in Plan mode~, q~ask the user to approve the plan and then leave plan mode~, q~update_plan task list~, q~spawn_agent~, q~/skills or $skill-name~, q~read the file~, q~write or create the file~, q~apply_patch~, q~exec_command with rg~, q~exec_command with rg --files or find~, q~exec_command~, q~running `codex debug models` with exec_command, which prints the raw model catalogue~],
    );
    my $harness = shift;
    my $substitutions = $values{$harness} or die "Unknown harness: $harness\n";
    my $content = <>;
    for my $index (0 .. $#names) {
      my $placeholder = "{{" . $names[$index] . "}}";
      $content =~ s/\Q$placeholder\E/$substitutions->[$index]/g;
    }
    print $content;
  ' "$1" "$2"
}

test_changed_workflow_skills_are_installed_in_all_harnesses() {
  local harness file relative question_tool skill_tool dispatch_tool expected missing=0
  local files=(
    'wave-planning/SKILL.md' '_shared/wave-readiness.md' '_shared/task-briefs.md'
    '_shared/test-pruning.md' 'workflow-coordinator/SKILL.md'
    'subagent-driven-development/SKILL.md' 'subagent-driven-development/reviewer-prompt.md'
    'fast-path-implementation/fast-path-reviewer-prompt.md' 'test-driven-development/SKILL.md'
  )
  for harness in claude opencode codex; do
    case "$harness" in
      claude) question_tool='AskUserQuestion'; skill_tool='Skill'; dispatch_tool='Agent' ;;
      opencode) question_tool='question'; skill_tool='skill'; dispatch_tool='subagent' ;;
      codex) question_tool='request_user_input'; skill_tool='/skills or $skill-name'; dispatch_tool='spawn_agent' ;;
    esac
    for file in "${files[@]}"; do
      if [[ ! -f "$TEST_TMP/$harness/skills/$file" ]] || grep -Fq '{{' "$TEST_TMP/$harness/skills/$file"; then
        _fail "installed_workflow_${harness}_${file//\//_}" "missing installed file or unresolved placeholder"
        missing=1
      fi
    done
    for file in "${workflow_files[@]}"; do
      relative="${file#skills/}"
      expected="$TEST_TMP/expected-$harness/$relative"
      mkdir -p "$(dirname "$expected")"
      if ! _write_expected_installed_skill "$harness" "$REPO_ROOT/$file" > "$expected" || ! cmp -s "$expected" "$TEST_TMP/$harness/skills/$relative"; then
        _fail "installed_content_${harness}_${relative//\//_}" "installed skill differs from its correctly substituted source"
        missing=1
      fi
    done
    if ! grep -Fxq "\`$question_tool\` to resolve the task identity and any user choices." "$TEST_TMP/$harness/skills/workflow-coordinator/SKILL.md"; then
      _fail "installed_tool_${harness}_question" "expected the harness question tool in its source context"
      missing=1
    fi
    if ! grep -Fxq "\`$skill_tool\`, using the skill name. The paths below identify" "$TEST_TMP/$harness/skills/workflow-coordinator/SKILL.md"; then
      _fail "installed_tool_${harness}_skill" "expected the harness skill tool in its source context"
      missing=1
    fi
    if ! grep -Fxq "$dispatch_tool ([VERIFIED_TEST_OR_QUALITY_SPECIALIST]):" "$TEST_TMP/$harness/skills/_shared/test-pruning.md"; then
      _fail "installed_tool_${harness}_dispatch" "expected the harness dispatch tool in its source context"
      missing=1
    fi
  done
  if (( missing == 0 )); then
    _pass "changed_workflow_skills_are_installed_in_all_harnesses"
  fi
}

test_changed_common_rules_are_installed_in_all_harnesses() {
  local harness file target skill_tool expected actual codex_output missing=0
  local rule_files=('workflow.md' 'skills-policy.md')
  local manifest=() languages=()
  RULES_SOURCE="$REPO_ROOT/rules"
  for harness in claude opencode; do
    target="$TEST_TMP/$harness/rules/common"
    install_files_from_dir "$RULES_SOURCE/common" "$target" rules/common manifest rule_files
    if [[ "$harness" == claude ]]; then
      substitute_tool_names "$target" CLAUDE_PLACEHOLDERS CLAUDE_SUBSTITUTIONS
      skill_tool='Skill'
    else
      substitute_tool_names "$target" OPENCODE_PLACEHOLDERS OPENCODE_SUBSTITUTIONS
      skill_tool='skill'
    fi
    for file in "${rule_files[@]}"; do
      if [[ ! -f "$target/$file" ]] || grep -Fq '{{' "$target/$file" || ! grep -Fq 'cumulative' "$target/$file"; then
        _fail "installed_rule_${harness}_${file}" "missing installed cumulative policy or unresolved placeholder"
        missing=1
      else
        expected="$(sed "s|{{INVOKE_SKILL_TOOL}}|$skill_tool|g" "$RULES_SOURCE/common/$file")"
        actual="$(cat "$target/$file")"
        if [[ "$actual" != "$expected" ]]; then
          _fail "installed_rule_${harness}_${file}" "installed rule differs from its correctly substituted source"
          missing=1
        fi
      fi
    done
  done
  target="$TEST_TMP/codex/AGENTS.md"
  _codex_render_agents_payload "$TEST_TMP/codex/payload.md" rule_files languages
  _codex_upsert_managed_block "$target" "$TEST_TMP/codex/payload.md"
  codex_output="$(test_codex_common_rules_are_in_the_managed_block)"
  for file in "${rule_files[@]}"; do
    if ! grep -Fq "## rules/common/$file" "$target" || ! grep -Fq 'cumulative' "$target" || grep -Fq '{{' "$target"; then
      _fail "installed_rule_codex_${file}" "missing rendered rule or unresolved placeholder"
      missing=1
    elif grep -Fq "[FAIL] codex_rule_content_${file}" <<< "$codex_output"; then
      _fail "installed_rule_codex_${file}" "managed rule differs from its correctly substituted source"
      missing=1
    fi
  done
  if (( missing == 0 )); then
    _pass "changed_common_rules_are_installed_in_all_harnesses"
  fi
}

test_final_audit_rechecks_only_affected_evidence_after_corrections() {
  local file content requirement pattern missing=0
  local requirements=(
    'skills/_shared/test-pruning.md|targeted recheck.{0,160}affected.{0,100}transitive.{0,100}survivor'
    'skills/_shared/test-pruning.md|newly touched files.{0,100}audit.{0,40}full'
    'skills/_shared/test-pruning.md|missing.{0,100}evidence.{0,100}block'
    'skills/_shared/test-pruning.md|coverage gap.{0,120}in-scope.{0,120}TDD.{0,120}review.{0,120}checks'
    'skills/subagent-driven-development/SKILL.md|final.{0,40}review.{0,160}audit evidence.{0,160}actual.{0,40}diff.{0,80}pruning'
    'skills/subagent-driven-development/SKILL.md|repeat affected review and checks.{0,100}final verification'
    'skills/subagent-driven-development/implementer-prompt.md|multiple.{0,100}RED/GREEN cycles'
    'skills/fast-path-implementation/SKILL.md|cumulative.{0,100}audit.{0,100}final.{0,40}review'
    'README.md|earliest safe wave.{0,100}verified.{0,40}capacity'
    '_tests/workflow_scenarios.md|concurrency one.{0,140}concrete reason'
    '_tests/workflow_scenarios.md|multiple.{0,100}RED/GREEN cycles'
  )
  for requirement in "${requirements[@]}"; do
    file="${requirement%%|*}"
    pattern="${requirement#*|}"
    content="$(tr '\n' ' ' < "$REPO_ROOT/$file" | tr -s '[:space:]' ' ')"
    if ! grep -Eiq "$pattern" <<< "$content"; then
      _fail "final_audit_recheck_${file//\//_}" "expected correction lifecycle: $pattern"
      missing=1
    fi
  done
  if (( missing == 0 )); then
    _pass "final_audit_rechecks_only_affected_evidence_after_corrections"
  fi
}

test_cumulative_audit_preserves_each_task_baseline_and_skip_provenance() {
  local content requirement pattern missing=0
  local requirements=(
    'all task baselines|each task.{0,100}immutable task-start.{0,100}(dirty|untracked)'
    'baseline inputs|each task.{0,80}baseline.{0,100}pre-existing.{0,100}snapshots'
    'skip provenance|skip.{0,100}exact.{0,40}source.{0,100}scope.{0,100}reason.{0,100}consequence'
    'final prompt inputs|each task.{0,80}baseline.{0,100}pre-existing.{0,100}snapshots'
  )
  content="$(tr '\n' ' ' < "$REPO_ROOT/skills/_shared/test-pruning.md" | tr -s '[:space:]' ' ')"
  for requirement in "${requirements[@]}"; do
    pattern="${requirement#*|}"
    if ! grep -Eiq "$pattern" <<< "$content"; then
      _fail "cumulative_baseline_${requirement%%|*}" "expected cumulative provenance: $pattern"
      missing=1
    fi
  done
  if (( missing == 0 )); then
    _pass "cumulative_audit_preserves_each_task_baseline_and_skip_provenance"
  fi
}

test_codex_common_rules_are_in_the_managed_block() {
  local target="$TEST_TMP/codex/AGENTS.md" file actual expected missing=0
  if ! grep -Fxq "$CODEX_MANAGED_START" "$target" || ! grep -Fxq "$CODEX_MANAGED_END" "$target"; then
    _fail "codex_common_rules_are_in_the_managed_block" "expected the installed Codex managed block"
    return
  fi
  for file in workflow.md skills-policy.md; do
    actual="$(awk -v start="$CODEX_MANAGED_START" -v end="$CODEX_MANAGED_END" -v label="## rules/common/$file" '
      $0 == start {inside=1; next}
      $0 == end {inside=0; capture=0; next}
      inside && $0 == label {count++; capture=1; skip=1; next}
      capture && /^## rules\/common\// {capture=0}
      capture && skip {skip=0; if ($0 == "") next}
      capture {print}
      END {if (count != 1) exit 1}
    ' "$target")" || actual=''
    expected="$(sed 's|{{INVOKE_SKILL_TOOL}}|/skills or $skill-name|g' "$REPO_ROOT/rules/common/$file")"
    if [[ "$actual" != "$expected" ]]; then
      _fail "codex_rule_content_${file}" "expected the complete substituted rule inside the managed block"
      missing=1
    fi
  done
  if (( missing == 0 )); then
    _pass "codex_common_rules_are_in_the_managed_block"
  fi
}

test_coordinator_runs_the_audit_once_within_executor_phase() {
  local file content requirement pattern missing=0
  local requirements=(
    'skills/workflow-coordinator/SKILL.md|coordinator owns and executes.{0,80}cumulative.{0,40}audit.{0,120}executor.{0,80}phase'
    'skills/workflow-coordinator/SKILL.md|executor returns.{0,80}audit.{0,80}final review.{0,80}verification evidence'
    'skills/workflow-coordinator/SKILL.md|coordinator.{0,120}reuses.{0,100}evidence.{0,100}(never|not).{0,80}automatically repeat'
    'skills/subagent-driven-development/SKILL.md|coordinator owns and executes.{0,80}cumulative.{0,40}audit.{0,120}executor.{0,80}phase'
  )
  for requirement in "${requirements[@]}"; do
    file="${requirement%%|*}"
    pattern="${requirement#*|}"
    content="$(tr '\n' ' ' < "$REPO_ROOT/$file" | tr -s '[:space:]' ' ')"
    if ! grep -Eiq "$pattern" <<< "$content"; then
      _fail "audit_phase_ownership_${file//\//_}" "expected one audit handoff: $pattern"
      missing=1
    fi
  done
  if (( missing == 0 )); then
    _pass "coordinator_runs_the_audit_once_within_executor_phase"
  fi
}

test_final_review_dispatch_receives_audit_evidence_and_criteria() {
  local file content requirement pattern missing=0
  local requirements=(
    'skills/subagent-driven-development/SKILL.md|final review dispatch.{0,200}audit record.{0,160}approved scope'
    'skills/subagent-driven-development/SKILL.md|final review dispatch.{0,255}.{0,45}skip.{0,80}provenance.{0,80}none'
    'skills/subagent-driven-development/SKILL.md|final review dispatch.{0,250}.{0,250}reviewer.prompt.md.{0,160}criteria'
    'skills/subagent-driven-development/SKILL.md|final review dispatch.{0,250}.{0,250}.{0,200}actual post-prune diff'
    'skills/subagent-driven-development/SKILL.md|DESCRIPTION.{0,160}inspect.{0,80}audit evidence'
    'skills/subagent-driven-development/reviewer-prompt.md|FINAL_AUDIT_RECORD'
    'skills/subagent-driven-development/reviewer-prompt.md|APPROVED_CUMULATIVE_SCOPE'
    'skills/subagent-driven-development/reviewer-prompt.md|ACTUAL_POST_PRUNE_DIFF'
    'skills/subagent-driven-development/reviewer-prompt.md|missing.{0,100}audit.{0,100}BLOCKED'
  )
  for requirement in "${requirements[@]}"; do
    file="${requirement%%|*}"
    pattern="${requirement#*|}"
    content="$(tr '\n' ' ' < "$REPO_ROOT/$file" | tr -s '[:space:]' ' ')"
    if ! grep -Eiq "$pattern" <<< "$content"; then
      _fail "final_review_handoff_${file//\//_}" "expected review dispatch input: $pattern"
      missing=1
    fi
  done
  if (( missing == 0 )); then
    _pass "final_review_dispatch_receives_audit_evidence_and_criteria"
  fi
}

test_installed_skill_checks_reject_wrong_harness_tool_mappings() {
  local harness copy fixture expected output missing=0
  for harness in claude opencode codex; do
    fixture="$TEST_TMP/wrong-mapping-$harness"
    for copy in claude opencode codex; do
      mkdir -p "$fixture/$copy"
      cp -R "$TEST_TMP/$copy/skills" "$fixture/$copy/skills"
    done
    case "$harness" in
      claude) expected='AskUserQuestion' ;;
      opencode) expected='question' ;;
      codex) expected='request_user_input' ;;
    esac
    perl -i -pe "s/${expected}/wrong_tool/g" "$fixture/$harness/skills/workflow-coordinator/SKILL.md"
    output="$(TEST_TMP="$fixture"; passed=0; failed=0; test_changed_workflow_skills_are_installed_in_all_harnesses)"
    if ! grep -Fq "[FAIL] installed_tool_${harness}_question" <<< "$output"; then
      _fail "wrong_mapping_${harness}" "the installer check accepted an incorrect question tool"
      missing=1
    fi
  done
  if (( missing == 0 )); then
    _pass "installed_skill_checks_reject_wrong_harness_tool_mappings"
  fi
}

test_installed_skill_checks_reject_wrong_tracker_mappings() {
  local harness copy fixture output missing=0
  for harness in claude opencode codex; do
    fixture="$TEST_TMP/wrong-tracker-$harness"
    for copy in claude opencode codex; do
      mkdir -p "$fixture/$copy"
      cp -R "$TEST_TMP/$copy/skills" "$fixture/$copy/skills"
    done
    output="$(
      TEST_TMP="$fixture"
      passed=0
      failed=0
      if [[ "$harness" == claude ]]; then
        CLAUDE_SUBSTITUTIONS[3]='wrong_tracker'
        _copy_and_substitute_harness claude "$fixture/claude/skills" _skill_resolve_dst CLAUDE_PLACEHOLDERS CLAUDE_SUBSTITUTIONS
      elif [[ "$harness" == opencode ]]; then
        OPENCODE_SUBSTITUTIONS[3]='wrong_tracker'
        _copy_and_substitute_harness opencode "$fixture/opencode/skills" _skill_resolve_dst OPENCODE_PLACEHOLDERS OPENCODE_SUBSTITUTIONS
      else
        CODEX_SUBSTITUTIONS[3]='wrong_tracker'
        test_codex_installer_copy_and_substitution
      fi
      if ! grep -Fq 'wrong_tracker' "$fixture/$harness/skills/subagent-driven-development/SKILL.md"; then
        printf 'MUTATION_NOT_APPLIED\n'
      fi
      test_changed_workflow_skills_are_installed_in_all_harnesses
    )"
    if grep -Fq 'MUTATION_NOT_APPLIED' <<< "$output" || ! grep -Fq "[FAIL] installed_content_${harness}_subagent-driven-development_SKILL.md" <<< "$output"; then
      _fail "wrong_tracker_mapping_${harness}" "the installer check accepted an incorrect tracker mapping"
      missing=1
    fi
  done
  if (( missing == 0 )); then
    _pass "installed_skill_checks_reject_wrong_tracker_mappings"
  fi
}

test_codex_rule_check_rejects_content_moved_outside_the_managed_block() {
  local file fixture target output missing=0
  for file in workflow.md skills-policy.md; do
    fixture="$TEST_TMP/outside-block-$file"
    mkdir -p "$fixture/codex"
    target="$fixture/codex/AGENTS.md"
    awk -v label="## rules/common/$file" -v end="$CODEX_MANAGED_END" -v moved="$fixture/moved.md" '
      $0 == label {moving=1; print > moved; next}
      moving && ($0 ~ /^## rules\/common\// || $0 == end) {moving=0}
      moving {print > moved; next}
      {print}
    ' "$TEST_TMP/codex/AGENTS.md" > "$target"
    cat "$fixture/moved.md" >> "$target"
    output="$(TEST_TMP="$fixture"; passed=0; failed=0; test_codex_common_rules_are_in_the_managed_block)"
    if ! grep -Fq "[FAIL] codex_rule_content_${file}" <<< "$output"; then
      _fail "codex_rule_outside_${file}" "the rule check accepted content outside the managed block"
      missing=1
    fi
  done
  if (( missing == 0 )); then
    _pass "codex_rule_check_rejects_content_moved_outside_the_managed_block"
  fi
}

test_codex_rule_check_rejects_changed_rule_content() {
  local fixture="$TEST_TMP/codex-altered-rule" output
  mkdir -p "$fixture/codex"
  cp "$TEST_TMP/codex/AGENTS.md" "$fixture/codex/AGENTS.md"
  perl -i -pe 's/cumulative pruning audit/per-task pruning audit/' "$fixture/codex/AGENTS.md"
  output="$(TEST_TMP="$fixture"; passed=0; failed=0; test_codex_common_rules_are_in_the_managed_block)"
  if grep -Fq '[FAIL] codex_rule_content_workflow.md' <<< "$output"; then
    _pass "codex_rule_check_rejects_changed_rule_content"
  else
    _fail "codex_rule_check_rejects_changed_rule_content" "the rule check accepted altered policy content"
  fi
}

test_common_rule_checks_reject_wrong_skill_tool_mappings() {
  local harness fixture output missing=0
  for harness in claude opencode codex; do
    fixture="$TEST_TMP/wrong-rule-tool-$harness"
    mkdir -p "$fixture/codex"
    output="$(
      TEST_TMP="$fixture"
      passed=0
      failed=0
      if [[ "$harness" == claude ]]; then
        CLAUDE_SUBSTITUTIONS[5]='wrong_tool'
      elif [[ "$harness" == opencode ]]; then
        OPENCODE_SUBSTITUTIONS[5]='wrong_tool'
      else
        CODEX_SUBSTITUTIONS[5]='wrong_tool'
      fi
      test_changed_common_rules_are_installed_in_all_harnesses
    )"
    if ! grep -Fq "[FAIL] installed_rule_${harness}_skills-policy.md" <<< "$output"; then
      _fail "wrong_rule_mapping_${harness}" "the common rule check accepted an incorrect skill tool"
      missing=1
    fi
  done
  if (( missing == 0 )); then
    _pass "common_rule_checks_reject_wrong_skill_tool_mappings"
  fi
}

_check_skill_frontmatter
test_coordinator_runs_the_audit_once_within_executor_phase
test_final_review_dispatch_receives_audit_evidence_and_criteria
test_wave_planning_maximises_safe_static_width
test_cumulative_audit_follows_reviews_and_barriers
test_final_audit_rechecks_only_affected_evidence_after_corrections
test_cumulative_audit_preserves_each_task_baseline_and_skip_provenance
test_required_files_check_is_registered
test_phase_evidence_contract
test_phase_evidence_boundary_references
test_claude_installer_copy_and_substitution
test_opencode_installer_copy_and_substitution
test_codex_installer_copy_and_substitution
test_changed_workflow_skills_are_installed_in_all_harnesses
test_installed_skill_checks_reject_wrong_harness_tool_mappings
test_installed_skill_checks_reject_wrong_tracker_mappings
test_changed_common_rules_are_installed_in_all_harnesses
test_common_rule_checks_reject_wrong_skill_tool_mappings
test_codex_common_rules_are_in_the_managed_block
test_codex_rule_check_rejects_content_moved_outside_the_managed_block
test_codex_rule_check_rejects_changed_rule_content
test_test_pruning_contract_is_documented
test_auditor_policy_categories_and_decisions_are_explicit
test_auditor_rule_discovery_freezes_complete_harness_sources
test_auditor_inventory_merge_recovery_and_dependency_invalidation
test_removal_handoff_requires_survivors_only_when_the_criterion_does
test_uncertain_survivor_handling_does_not_override_named_removal
test_archived_removed_sources_are_separate_from_live_execution
test_archived_trace_is_required_only_when_original_runner_needs_it
test_canonical_rule_resolution_uses_verified_active_scope
test_auditor_contract_is_wired_to_workers_reviewers_docs_and_scenarios
test_auditor_prompt_supplies_category_definitions_and_authority_inputs
test_final_pruning_task_honors_scoped_pruning_audit_skips
test_final_pruning_review_accepts_runner_appropriate_pruning_evidence
test_final_pruning_runs_once_after_cumulative_reviewer_pass
test_cumulative_review_pass_adapts_the_actual_reviewer_result
test_ordinary_task_handoffs_do_not_require_pruning_evidence
test_test_pruning_helper_installs_and_skill_links_resolve
test_tdd_completion_gate_is_behaviour_based
test_pruning_safety_gates_are_explicit
test_auditor_rule_source_is_harness_aware_and_bounded
test_audit_invalidation_uses_accepted_green_snapshot
test_stale_workflow_lifecycle_instructions_are_absent
test_gitignore_excludes_workflow_artifacts
test_new_backticked_source_references_resolve
test_parallel_agent_readiness_contract_reference
test_fast_path_readiness_contract_reference
test_phase_evidence_installed_links_resolve

total=$(( passed + failed ))
printf '\n%s/%s tests passed\n' "$passed" "$total"
(( failed == 0 )) || exit 1
