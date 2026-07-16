#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../_install-common.sh
source "$REPO_ROOT/_install-common.sh"

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

test_write_opencode_instructions_preserves_existing_permission_key() {
  local name="write_opencode_instructions_preserves_existing_permission_key"
  local dir
  dir="$(mktemp -d)"
  trap "rm -rf '$dir'" RETURN

  cat > "$dir/opencode.json" <<'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": [
    "rules/common/*.md"
  ],
  "permission": {
    "external_directory": {
      "~/.config/opencode/skills/**": "allow"
    }
  }
}
EOF

  write_opencode_instructions "$dir/opencode.json" "rules/common/*.md" "rules/python/*.md"

  if ! grep -q '"permission"' "$dir/opencode.json"; then
    _fail "$name" "the pre-existing permission key was discarded"
    return
  fi

  if ! grep -q 'rules/python' "$dir/opencode.json"; then
    _fail "$name" "instructions were not updated with the new globs"
    return
  fi

  _pass "$name"
}

test_write_opencode_instructions_preserves_a_symlinked_target() {
  local name="write_opencode_instructions_preserves_a_symlinked_target"
  local dir
  dir="$(mktemp -d)"
  trap "rm -rf '$dir'" RETURN

  cat > "$dir/real.json" <<'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": [],
  "permission": {
    "external_directory": {
      "~/.config/opencode/skills/**": "allow"
    }
  }
}
EOF
  ln -s "$dir/real.json" "$dir/opencode.json"

  write_opencode_instructions "$dir/opencode.json" "rules/common/*.md"

  if [[ ! -L "$dir/opencode.json" ]]; then
    _fail "$name" "the symlink was replaced by a regular file"
    return
  fi

  if ! grep -q '"permission"' "$dir/real.json"; then
    _fail "$name" "writing through the symlink discarded the permission key in the target"
    return
  fi

  _pass "$name"
}

test_write_opencode_instructions_leaves_a_malformed_target_unchanged() {
  local name="write_opencode_instructions_leaves_a_malformed_target_unchanged"
  local dir
  dir="$(mktemp -d)"
  trap "rm -rf '$dir'" RETURN

  printf '{ not valid json' > "$dir/opencode.json"

  if write_opencode_instructions "$dir/opencode.json" "rules/common/*.md" 2>/dev/null; then
    _fail "$name" "expected a non-zero return when the existing file is not valid JSON"
    return
  fi

  if [[ "$(cat "$dir/opencode.json")" != '{ not valid json' ]]; then
    _fail "$name" "the malformed target was modified instead of being left untouched"
    return
  fi

  _pass "$name"
}

test_write_opencode_instructions_preserves_existing_permission_key
test_write_opencode_instructions_preserves_a_symlinked_target
test_write_opencode_instructions_leaves_a_malformed_target_unchanged

total=$(( passed + failed ))
echo
echo "$passed/$total tests passed"
(( failed == 0 ))
