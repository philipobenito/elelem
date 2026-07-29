#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

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

# Resolves a reference string against the directory of the file that cites it.
_resolve_reference() {
  local citing_file="$1"
  local ref="$2"
  realpath -m "$(dirname "$citing_file")/$ref"
}

# Prints every dot-relative (./ or ../) markdown cross-reference written in FILE,
# one per line, exactly as it appears in the source.
_dot_relative_refs() {
  local file="$1"
  grep -oE '(\.\./|\./)[A-Za-z0-9_./-]+\.md' "$file" 2>/dev/null || true
}

# Prints "citing_file -> reference" for every dot-relative reference under
# ROOT/rules and ROOT/skills that does not resolve to an existing file.
find_broken_dot_relative_references() {
  local root="$1"
  local file ref resolved

  while IFS= read -r file; do
    while IFS= read -r ref; do
      [[ -z "$ref" ]] && continue
      resolved="$(_resolve_reference "$file" "$ref")"
      if [[ ! -f "$resolved" ]]; then
        printf '%s -> %s\n' "$file" "$ref"
      fi
    done < <(_dot_relative_refs "$file")
  done < <(find "$root/rules" "$root/skills" -type f -name '*.md' 2>/dev/null)
}

# Prints the path of every file in ROOT/skills/_shared that is not cited, via a
# dot-relative reference, by any file outside itself.
find_uncited_shared_files() {
  local root="$1"
  local shared_file shared_real citing_file ref resolved cited

  while IFS= read -r shared_file; do
    shared_real="$(realpath "$shared_file")"
    cited=0

    while IFS= read -r citing_file; do
      [[ "$citing_file" == "$shared_file" ]] && continue
      while IFS= read -r ref; do
        [[ -z "$ref" ]] && continue
        resolved="$(_resolve_reference "$citing_file" "$ref")"
        [[ -f "$resolved" ]] || continue
        if [[ "$(realpath "$resolved")" == "$shared_real" ]]; then
          cited=1
          break
        fi
      done < <(_dot_relative_refs "$citing_file")
      (( cited )) && break
    done < <(find "$root/rules" "$root/skills" -type f -name '*.md' 2>/dev/null)

    (( cited )) || printf '%s\n' "$shared_file"
  done < <(find "$root/skills/_shared" -maxdepth 1 -type f -name '*.md' 2>/dev/null)
}

test_resolve_reference_uses_citing_files_own_directory_not_cwd() {
  local name="resolve_reference_uses_citing_files_own_directory_not_cwd"
  local base resolved
  base="$(mktemp -d)"
  trap "rm -rf '$base'" RETURN

  mkdir -p "$base/skills/alpha" "$base/rules/common"
  touch "$base/rules/common/testing.md"

  resolved="$(_resolve_reference "$base/skills/alpha/SKILL.md" "../../rules/common/testing.md")"

  if [[ "$resolved" == "$base/rules/common/testing.md" ]]; then
    _pass "$name"
  else
    _fail "$name" "expected $base/rules/common/testing.md, got '$resolved'"
  fi
}

test_broken_dot_relative_reference_is_reported() {
  local name="broken_dot_relative_reference_is_reported"
  local root result
  root="$(mktemp -d)"
  trap "rm -rf '$root'" RETURN

  mkdir -p "$root/skills/example" "$root/rules"
  printf 'See `../nonexistent.md` for detail.\n' > "$root/skills/example/SKILL.md"

  result="$(find_broken_dot_relative_references "$root")"

  if [[ "$result" == *"../nonexistent.md"* ]]; then
    _pass "$name"
  else
    _fail "$name" "expected a broken reference to ../nonexistent.md, got: '$result'"
  fi
}

test_valid_dot_relative_reference_is_not_reported() {
  local name="valid_dot_relative_reference_is_not_reported"
  local root result
  root="$(mktemp -d)"
  trap "rm -rf '$root'" RETURN

  mkdir -p "$root/skills/example" "$root/rules/common"
  printf 'placeholder\n' > "$root/rules/common/workflow.md"
  printf 'See `../../rules/common/workflow.md` for detail.\n' > "$root/skills/example/SKILL.md"

  result="$(find_broken_dot_relative_references "$root")"

  if [[ -z "$result" ]]; then
    _pass "$name"
  else
    _fail "$name" "expected no broken references, got: '$result'"
  fi
}

test_uncited_shared_file_is_reported() {
  local name="uncited_shared_file_is_reported"
  local root result
  root="$(mktemp -d)"
  trap "rm -rf '$root'" RETURN

  mkdir -p "$root/skills/_shared" "$root/skills/example" "$root/rules"
  printf 'placeholder\n' > "$root/skills/_shared/orphan.md"
  printf 'no references here\n' > "$root/skills/example/SKILL.md"

  result="$(find_uncited_shared_files "$root")"

  if [[ "$result" == *"orphan.md"* ]]; then
    _pass "$name"
  else
    _fail "$name" "expected orphan.md to be reported as uncited, got: '$result'"
  fi
}

test_cited_shared_file_is_not_reported() {
  local name="cited_shared_file_is_not_reported"
  local root result
  root="$(mktemp -d)"
  trap "rm -rf '$root'" RETURN

  mkdir -p "$root/skills/_shared" "$root/skills/example" "$root/rules"
  printf 'placeholder\n' > "$root/skills/_shared/used.md"
  printf 'See `../_shared/used.md` for detail.\n' > "$root/skills/example/SKILL.md"

  result="$(find_uncited_shared_files "$root")"

  if [[ -z "$result" ]]; then
    _pass "$name"
  else
    _fail "$name" "expected used.md not to be reported, got: '$result'"
  fi
}

test_no_broken_dot_relative_references_in_repo() {
  local name="no_broken_dot_relative_references_in_repo"
  local result
  result="$(find_broken_dot_relative_references "$REPO_ROOT")"

  if [[ -z "$result" ]]; then
    _pass "$name"
  else
    _fail "$name" "broken references found:
$result"
  fi
}

test_every_shared_file_is_cited_in_repo() {
  local name="every_shared_file_is_cited_in_repo"
  local result
  result="$(find_uncited_shared_files "$REPO_ROOT")"

  if [[ -z "$result" ]]; then
    _pass "$name"
  else
    _fail "$name" "uncited files in skills/_shared:
$result"
  fi
}

test_resolve_reference_uses_citing_files_own_directory_not_cwd
test_broken_dot_relative_reference_is_reported
test_valid_dot_relative_reference_is_not_reported
test_uncited_shared_file_is_reported
test_cited_shared_file_is_not_reported
test_no_broken_dot_relative_references_in_repo
test_every_shared_file_is_cited_in_repo

total=$(( passed + failed ))
echo
echo "${passed}/${total} tests passed"
(( failed == 0 )) || exit 1
