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

test_cursor_rule_resolve_dst_rewrites_md_to_mdc() {
  local name="cursor_rule_resolve_dst_rewrites_md_to_mdc"

  local result
  result="$(_cursor_rule_resolve_dst /foo/bar.md /out)"

  if [[ "$result" == "/out/bar.mdc" ]]; then
    echo "[PASS] $name"
    (( passed++ )) || true
  else
    echo "[FAIL] $name: expected /out/bar.mdc, got $result"
    (( failed++ )) || true
  fi
}

test_cursor_rule_resolve_dst_preserves_non_md_basename_structure() {
  local name="cursor_rule_resolve_dst_preserves_non_md_basename_structure"

  local result
  result="$(_cursor_rule_resolve_dst /foo/bar.baz.md /out)"

  if [[ "$result" == "/out/bar.baz.mdc" ]]; then
    echo "[PASS] $name"
    (( passed++ )) || true
  else
    echo "[FAIL] $name: expected /out/bar.baz.mdc, got $result"
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

# Run all tests
test_install_cursor_exists
test_install_cursor_executable
test_guard_user_scope_no_claude
test_guard_user_scope_rules_symlink_collision
test_guard_user_scope_skills_symlink_collision
test_guard_project_scope_rules_collision
test_guard_benign_realpath
test_cursor_rule_resolve_dst_rewrites_md_to_mdc
test_cursor_rule_resolve_dst_preserves_non_md_basename_structure
test_cursor_rule_transform_substitutes_placeholders
test_cursor_rule_transform_preserves_globs_language_pack
test_cursor_rule_transform_returns_nonzero_on_empty_globs

total=$(( passed + failed ))
echo ""
echo "${passed}/${total} tests passed"

if (( failed > 0 )); then
  exit 1
fi
