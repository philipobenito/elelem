#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../_install-common.sh
source "$REPO_ROOT/_install-common.sh"

# Source install-cursor.sh but do not execute the main flow
# shellcheck source=../install-cursor.sh
source "$REPO_ROOT/install-cursor.sh"

passed=0
failed=0

test_guard_user_scope_no_claude() {
  local name="guard_user_scope_no_claude"

  # Set up a temporary home directory with no .claude
  local tmphome
  tmphome="$(mktemp -d)"
  trap "rm -rf '$tmphome'" RETURN

  local base="$tmphome/.cursor"

  # Should pass: no .claude directory exists
  local exit_code=0
  cursor_assert_not_under_claude "$base" 2>/dev/null || exit_code=$?

  if [[ $exit_code -eq 0 ]]; then
    echo "[PASS] $name"
    (( passed++ )) || true
  else
    echo "[FAIL] $name: expected exit code 0, got $exit_code"
    (( failed++ )) || true
  fi
}

test_guard_user_scope_rules_symlink_collision() {
  local name="guard_user_scope_rules_symlink_collision"

  local tmphome
  tmphome="$(mktemp -d)"
  trap "rm -rf '$tmphome'" RETURN

  # Create a real .claude/rules directory
  mkdir -p "$tmphome/.claude/rules"

  # Create a .cursor directory and symlink rules to the .claude version
  mkdir -p "$tmphome/.cursor"
  ln -s "$tmphome/.claude/rules" "$tmphome/.cursor/rules"

  local base="$tmphome/.cursor"

  # Should fail: $base/rules resolves under $HOME/.claude/rules
  local stderr_output
  local exit_code=0
  stderr_output="$(cursor_assert_not_under_claude "$base" 2>&1)" || exit_code=$?

  if [[ $exit_code -ne 0 ]] && [[ "$stderr_output" == *"ERROR"* ]]; then
    echo "[PASS] $name"
    (( passed++ )) || true
  else
    echo "[FAIL] $name: expected non-zero exit and ERROR message"
    echo "  exit_code: $exit_code, stderr: $stderr_output"
    (( failed++ )) || true
  fi
}

test_guard_user_scope_skills_symlink_collision() {
  local name="guard_user_scope_skills_symlink_collision"

  local tmphome
  tmphome="$(mktemp -d)"
  trap "rm -rf '$tmphome'" RETURN

  # Create a real .claude/skills directory
  mkdir -p "$tmphome/.claude/skills"

  # Create a .cursor directory and symlink skills to the .claude version
  mkdir -p "$tmphome/.cursor"
  ln -s "$tmphome/.claude/skills" "$tmphome/.cursor/skills"

  local base="$tmphome/.cursor"

  # Should fail: $base/skills resolves under $HOME/.claude/skills
  local stderr_output
  local exit_code=0
  stderr_output="$(cursor_assert_not_under_claude "$base" 2>&1)" || exit_code=$?

  if [[ $exit_code -ne 0 ]] && [[ "$stderr_output" == *"ERROR"* ]]; then
    echo "[PASS] $name"
    (( passed++ )) || true
  else
    echo "[FAIL] $name: expected non-zero exit and ERROR message"
    echo "  exit_code: $exit_code, stderr: $stderr_output"
    (( failed++ )) || true
  fi
}

test_guard_project_scope_rules_collision() {
  local name="guard_project_scope_rules_collision"

  local tmpproj
  tmpproj="$(mktemp -d)"
  trap "rm -rf '$tmpproj'" RETURN

  # Create project-level directories
  mkdir -p "$tmpproj/.claude/rules"
  mkdir -p "$tmpproj/.cursor"

  # Symlink .cursor/rules to .claude/rules (simulating collision)
  ln -s "$tmpproj/.claude/rules" "$tmpproj/.cursor/rules"

  local base="$tmpproj/.cursor"

  # Should fail: project-scope base with .cursor/rules under .claude/rules
  local stderr_output
  local exit_code=0
  stderr_output="$(cursor_assert_not_under_claude "$base" 2>&1)" || exit_code=$?

  if [[ $exit_code -ne 0 ]] && [[ "$stderr_output" == *"ERROR"* ]]; then
    echo "[PASS] $name"
    (( passed++ )) || true
  else
    echo "[FAIL] $name: expected non-zero exit and ERROR message"
    echo "  exit_code: $exit_code, stderr: $stderr_output"
    (( failed++ )) || true
  fi
}

test_guard_benign_realpath() {
  local name="guard_benign_realpath"

  local tmphome
  tmphome="$(mktemp -d)"
  trap "rm -rf '$tmphome'" RETURN

  # Create a clean .cursor directory with no symlinks into .claude
  mkdir -p "$tmphome/.cursor/rules"
  mkdir -p "$tmphome/.cursor/skills"

  local base="$tmphome/.cursor"

  # Should pass: no resolution under .claude
  local exit_code=0
  cursor_assert_not_under_claude "$base" 2>/dev/null || exit_code=$?

  if [[ $exit_code -eq 0 ]]; then
    echo "[PASS] $name"
    (( passed++ )) || true
  else
    echo "[FAIL] $name: expected exit code 0, got $exit_code"
    (( failed++ )) || true
  fi
}

test_install_cursor_exists() {
  local name="install_cursor_exists"

  if [[ -f "$REPO_ROOT/install-cursor.sh" ]]; then
    echo "[PASS] $name"
    (( passed++ )) || true
  else
    echo "[FAIL] $name: install-cursor.sh does not exist"
    (( failed++ )) || true
  fi
}

test_install_cursor_executable() {
  local name="install_cursor_executable"

  if [[ -x "$REPO_ROOT/install-cursor.sh" ]]; then
    echo "[PASS] $name"
    (( passed++ )) || true
  else
    echo "[FAIL] $name: install-cursor.sh is not executable"
    (( failed++ )) || true
  fi
}

test_cursor_rule_resolve_dst_emits_flat_prefixed_basename() {
  local name="cursor_rule_resolve_dst_emits_flat_prefixed_basename"

  CURSOR_RULE_GROUP_PREFIX="common"
  local result
  result="$(_cursor_rule_resolve_dst /foo/bar.md /out)"
  CURSOR_RULE_GROUP_PREFIX=""

  if [[ "$result" == "/out/elelem-common-bar.mdc" ]]; then
    echo "[PASS] $name"
    (( passed++ )) || true
  else
    echo "[FAIL] $name: expected /out/elelem-common-bar.mdc, got $result"
    (( failed++ )) || true
  fi
}

test_cursor_rule_resolve_dst_preserves_non_md_basename_structure() {
  local name="cursor_rule_resolve_dst_preserves_non_md_basename_structure"

  CURSOR_RULE_GROUP_PREFIX="python"
  local result
  result="$(_cursor_rule_resolve_dst /foo/bar.baz.md /out)"
  CURSOR_RULE_GROUP_PREFIX=""

  if [[ "$result" == "/out/elelem-python-bar.baz.mdc" ]]; then
    echo "[PASS] $name"
    (( passed++ )) || true
  else
    echo "[FAIL] $name: expected /out/elelem-python-bar.baz.mdc, got $result"
    (( failed++ )) || true
  fi
}

test_cursor_rule_resolve_dst_groups_do_not_collide() {
  local name="cursor_rule_resolve_dst_groups_do_not_collide"

  CURSOR_RULE_GROUP_PREFIX="common"
  local common_dst
  common_dst="$(_cursor_rule_resolve_dst /src/coding-style.md /out)"
  CURSOR_RULE_GROUP_PREFIX="python"
  local python_dst
  python_dst="$(_cursor_rule_resolve_dst /src/coding-style.md /out)"
  CURSOR_RULE_GROUP_PREFIX=""

  if [[ "$common_dst" != "$python_dst" ]] && [[ "$common_dst" == */elelem-common-coding-style.mdc ]] && [[ "$python_dst" == */elelem-python-coding-style.mdc ]]; then
    echo "[PASS] $name"
    (( passed++ )) || true
  else
    echo "[FAIL] $name: groups collided or wrong prefix; common=$common_dst python=$python_dst"
    (( failed++ )) || true
  fi
}

test_cursor_rule_transform_substitutes_placeholders() {
  local name="cursor_rule_transform_substitutes_placeholders"

  local tmpdir src dst
  tmpdir="$(mktemp -d)"
  trap "rm -rf '$tmpdir'" RETURN

  src="$tmpdir/test.md"
  dst="$tmpdir/test.mdc"

  cat > "$src" <<'EOF'
---
description: test rule
---

Use the {{READ_FILE_TOOL}} tool and the {{EDIT_FILE_TOOL}} tool.
EOF

  local exit_code=0
  _cursor_rule_transform "$src" "$dst" || exit_code=$?

  if [[ $exit_code -ne 0 ]]; then
    echo "[FAIL] $name: transform returned non-zero ($exit_code)"
    (( failed++ )) || true
    return
  fi

  if [[ ! -f "$dst" ]]; then
    echo "[FAIL] $name: destination file not created"
    (( failed++ )) || true
    return
  fi

  local dst_content
  dst_content="$(cat "$dst")"

  if [[ "$dst_content" == *"alwaysApply: true"* ]] && \
     [[ "$dst_content" == *"Use the Read tool"* ]] && \
     [[ "$dst_content" == *"the StrReplace tool"* ]] && \
     [[ "$dst_content" != *"{{"* ]]; then
    echo "[PASS] $name"
    (( passed++ )) || true
  else
    echo "[FAIL] $name: content check failed"
    echo "  Content: $dst_content"
    (( failed++ )) || true
  fi
}

test_cursor_rule_transform_preserves_globs_language_pack() {
  local name="cursor_rule_transform_preserves_globs_language_pack"

  local tmpdir src dst
  tmpdir="$(mktemp -d)"
  trap "rm -rf '$tmpdir'" RETURN

  src="$tmpdir/test.md"
  dst="$tmpdir/test.mdc"

  cat > "$src" <<'EOF'
---
globs: **/*.py
description: python style
---

Some body text.
EOF

  local exit_code=0
  _cursor_rule_transform "$src" "$dst" || exit_code=$?

  if [[ $exit_code -ne 0 ]]; then
    echo "[FAIL] $name: transform returned non-zero ($exit_code)"
    (( failed++ )) || true
    return
  fi

  if [[ ! -f "$dst" ]]; then
    echo "[FAIL] $name: destination file not created"
    (( failed++ )) || true
    return
  fi

  local dst_content
  dst_content="$(cat "$dst")"

  if [[ "$dst_content" == *"globs: **/*.py"* ]] && \
     [[ "$dst_content" == *"alwaysApply: false"* ]]; then
    echo "[PASS] $name"
    (( passed++ )) || true
  else
    echo "[FAIL] $name: content check failed"
    echo "  Content: $dst_content"
    (( failed++ )) || true
  fi
}

test_cursor_rule_transform_returns_nonzero_on_empty_globs() {
  local name="cursor_rule_transform_returns_nonzero_on_empty_globs"

  local tmpdir src dst
  tmpdir="$(mktemp -d)"
  trap "rm -rf '$tmpdir'" RETURN

  src="$tmpdir/test.md"
  dst="$tmpdir/test.mdc"

  cat > "$src" <<'EOF'
---
globs:
---

Body text.
EOF

  local exit_code=0
  _cursor_rule_transform "$src" "$dst" || exit_code=$?

  if [[ $exit_code -ne 0 ]]; then
    echo "[PASS] $name"
    (( passed++ )) || true
  else
    echo "[FAIL] $name: expected non-zero exit code, got $exit_code"
    (( failed++ )) || true
  fi
}

test_cursor_skill_resolve_dst_preserves_subdirectory_structure() {
  local name="cursor_skill_resolve_dst_preserves_subdirectory_structure"

  SKILLS_SOURCE=/tmp/skills
  local result
  result="$(_cursor_skill_resolve_dst /tmp/skills/debugging/SKILL.md /out)"

  if [[ "$result" == "/out/debugging/SKILL.md" ]]; then
    echo "[PASS] $name"
    (( passed++ )) || true
  else
    echo "[FAIL] $name: expected /out/debugging/SKILL.md, got $result"
    (( failed++ )) || true
  fi
}

test_cursor_skill_resolve_dst_preserves_nested_files() {
  local name="cursor_skill_resolve_dst_preserves_nested_files"

  SKILLS_SOURCE=/tmp/skills
  local result
  result="$(_cursor_skill_resolve_dst /tmp/skills/brainstorming/modes/standard.md /out)"

  if [[ "$result" == "/out/brainstorming/modes/standard.md" ]]; then
    echo "[PASS] $name"
    (( passed++ )) || true
  else
    echo "[FAIL] $name: expected /out/brainstorming/modes/standard.md, got $result"
    (( failed++ )) || true
  fi
}

test_cursor_skill_transform_preserves_skill_md_frontmatter() {
  local name="cursor_skill_transform_preserves_skill_md_frontmatter"

  local tmpdir src dst
  tmpdir="$(mktemp -d)"
  trap "rm -rf '$tmpdir'" RETURN

  src="$tmpdir/SKILL.md"
  dst="$tmpdir/out.md"

  cat > "$src" <<'EOF'
---
name: test-skill
description: "A test skill with a {{READ_FILE_TOOL}} reference"
---

# Test Skill

Use the {{EDIT_FILE_TOOL}} tool for edits.
EOF

  local exit_code=0
  _cursor_skill_transform "$src" "$dst" || exit_code=$?

  if [[ $exit_code -ne 0 ]]; then
    echo "[FAIL] $name: transform returned non-zero ($exit_code)"
    (( failed++ )) || true
    return
  fi

  if [[ ! -f "$dst" ]]; then
    echo "[FAIL] $name: destination file not created"
    (( failed++ )) || true
    return
  fi

  local dst_content
  dst_content="$(cat "$dst")"

  local pass_test=1

  if [[ "$dst_content" != *"---"* ]]; then
    pass_test=0
  fi

  if [[ "$dst_content" != *"name: test-skill"* ]]; then
    pass_test=0
  fi

  if [[ "$dst_content" != *"description:"* ]]; then
    pass_test=0
  fi

  if [[ "$dst_content" == *"{{READ_FILE_TOOL}}"* ]]; then
    pass_test=0
  fi

  if [[ "$dst_content" != *"StrReplace"* ]]; then
    pass_test=0
  fi

  if [[ "$dst_content" == *"{{"* ]]; then
    pass_test=0
  fi

  if [[ $pass_test -eq 1 ]]; then
    echo "[PASS] $name"
    (( passed++ )) || true
  else
    echo "[FAIL] $name: content validation failed"
    echo "  Content: $dst_content"
    (( failed++ )) || true
  fi
}

test_cursor_skill_transform_does_not_call_rewrite_frontmatter() {
  local name="cursor_skill_transform_does_not_call_rewrite_frontmatter"

  local tmpdir src dst
  tmpdir="$(mktemp -d)"
  trap "rm -rf '$tmpdir'" RETURN

  src="$tmpdir/SKILL.md"
  dst="$tmpdir/out.md"

  cat > "$src" <<'EOF'
---
name: foo
---

# Skill

Body text.
EOF

  local exit_code=0
  _cursor_skill_transform "$src" "$dst" || exit_code=$?

  if [[ $exit_code -ne 0 ]]; then
    echo "[FAIL] $name: transform returned non-zero ($exit_code)"
    (( failed++ )) || true
    return
  fi

  if [[ ! -f "$dst" ]]; then
    echo "[FAIL] $name: destination file not created"
    (( failed++ )) || true
    return
  fi

  local dst_content
  dst_content="$(cat "$dst")"

  if [[ "$dst_content" =~ "name: foo" ]]; then
    echo "[PASS] $name"
    (( passed++ )) || true
  else
    echo "[FAIL] $name: expected literal 'name: foo' in output (rewrite_frontmatter must not have been called)"
    echo "  Content: $dst_content"
    (( failed++ )) || true
  fi
}

test_guard_home_with_regex_metacharacters_does_not_misclassify_scope() {
  local name="guard_home_with_regex_metacharacters_does_not_misclassify_scope"

  local fakehome
  fakehome="$(mktemp -d -t 'home.with.dots.XXXXXX')"
  trap "rm -rf '$fakehome'" RETURN

  local sibling_base="${fakehome}X.cursor"
  mkdir -p "$sibling_base"
  mkdir -p "${sibling_base}/.claude/rules"
  ln -s "${sibling_base}/.claude/rules" "$sibling_base/rules"

  local saved_home="$HOME"
  HOME="$fakehome"
  local exit_code=0
  cursor_assert_not_under_claude "$sibling_base" 2>/dev/null || exit_code=$?
  HOME="$saved_home"

  if [[ $exit_code -ne 0 ]]; then
    echo "[PASS] $name"
    (( passed++ )) || true
  else
    echo "[FAIL] $name: guard accepted a base whose project-scope rules dir resolves under .claude (HOME contained regex metachars)"
    (( failed++ )) || true
  fi
}

# Run all tests
test_install_cursor_exists
test_install_cursor_executable
test_guard_home_with_regex_metacharacters_does_not_misclassify_scope
test_guard_user_scope_no_claude
test_guard_user_scope_rules_symlink_collision
test_guard_user_scope_skills_symlink_collision
test_guard_project_scope_rules_collision
test_guard_benign_realpath
test_cursor_rule_resolve_dst_emits_flat_prefixed_basename
test_cursor_rule_resolve_dst_preserves_non_md_basename_structure
test_cursor_rule_resolve_dst_groups_do_not_collide
test_cursor_rule_transform_substitutes_placeholders
test_cursor_rule_transform_preserves_globs_language_pack
test_cursor_rule_transform_returns_nonzero_on_empty_globs
test_cursor_skill_resolve_dst_preserves_subdirectory_structure
test_cursor_skill_resolve_dst_preserves_nested_files
test_cursor_skill_transform_preserves_skill_md_frontmatter
test_cursor_skill_transform_does_not_call_rewrite_frontmatter

total=$(( passed + failed ))
echo ""
echo "${passed}/${total} tests passed"

if (( failed > 0 )); then
  exit 1
fi
