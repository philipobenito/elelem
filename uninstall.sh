#!/usr/bin/env bash
#
# Removes one or more elelem installs by reading the manifest files written
# by install-claude.sh, install-opencode.sh, or install-codex.sh.
#
# For each selected manifest the script builds a removal plan (files to
# delete, empty directories to prune, and for Codex the managed block
# to strip from AGENTS.md), shows it to the user, and executes it after a
# final confirmation.
#
# No CLI flags. No dry-run mode. Run from anywhere; the script is
# self-contained via SCRIPT_DIR resolution.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=_install-common.sh
source "$SCRIPT_DIR/_install-common.sh"

# Managed-block markers for Codex. Duplicate of install-codex.sh:59-60.
CODEX_MANAGED_START='<!-- elelem:codex:start -->'
CODEX_MANAGED_END='<!-- elelem:codex:end -->'

# ---------------------------------------------------------------------------
# Pure helper functions (no TTY required; exercisable from tests by sourcing)
# ---------------------------------------------------------------------------

# Resolves the AGENTS.md path for a Codex manifest given the install base.
# Prints the resolved path to stdout.
# Usage: resolve_codex_agents_md base
resolve_codex_agents_md() {
  local base="$1"
  if [[ "$base" == "$HOME" ]]; then
    printf '%s/.codex/AGENTS.md\n' "$HOME"
  else
    printf '%s/AGENTS.md\n' "$base"
  fi
}

# Validates a manifest base line. Returns 0 if valid, 1 otherwise.
# Usage: validate_manifest_base base manifest_name
validate_manifest_base() {
  local base="$1"
  local manifest_name="$2"

  if [[ -z "$base" ]]; then
    say_err "$manifest_name: base path is empty; skipping."
    return 1
  fi
  if [[ "$base" != /* ]]; then
    say_err "$manifest_name: base path '$base' is not absolute; skipping."
    return 1
  fi
  if [[ "$base" == *..* ]]; then
    say_err "$manifest_name: base path '$base' contains traversal segment; skipping."
    return 1
  fi
  return 0
}

# Validates a single manifest entry. Returns 0 if valid, 1 otherwise.
# Usage: validate_manifest_entry entry manifest_name
validate_manifest_entry() {
  local entry="$1"
  local manifest_name="$2"

  if [[ -z "$entry" ]]; then
    say_err "$manifest_name: empty entry; skipping manifest."
    return 1
  fi
  if [[ "$entry" == /* ]]; then
    say_err "$manifest_name: entry '$entry' is absolute; skipping manifest."
    return 1
  fi
  if [[ "$entry" == *..* ]]; then
    say_err "$manifest_name: entry '$entry' contains traversal segment; skipping manifest."
    return 1
  fi
  return 0
}

# Parses a manifest file and populates output arrays.
# On any validation failure, prints an error and returns 1.
# Usage: parse_manifest manifest_file out_base out_files out_gone
#   out_base  - name of a variable to set to the base path
#   out_files - name of an array variable to populate with existing files (absolute)
#   out_gone  - name of an array variable to populate with already-gone relative entries
parse_manifest() {
  local manifest_file="$1"
  local out_base="$2"
  local out_files="$3"
  local out_gone="$4"

  local manifest_name
  manifest_name="$(basename "$manifest_file")"

  local base=""
  local first_line=1
  local entries=()
  local invalid=0

  while IFS= read -r line; do
    if (( first_line )); then
      base="$line"
      first_line=0
      continue
    fi
    [[ -z "$line" ]] && continue
    entries+=("$line")
  done < "$manifest_file"

  validate_manifest_base "$base" "$manifest_name" || return 1

  local entry
  for entry in "${entries[@]+"${entries[@]}"}"; do
    validate_manifest_entry "$entry" "$manifest_name" || { invalid=1; break; }
  done
  (( invalid == 0 )) || return 1

  eval "${out_base}=\"\$base\""

  local _pf_files=()
  local _pf_gone=()
  for entry in "${entries[@]+"${entries[@]}"}"; do
    if [[ -f "$base/$entry" ]]; then
      _pf_files+=("$base/$entry")
    else
      _pf_gone+=("$entry")
    fi
  done

  eval "${out_files}=(\"\${_pf_files[@]+\${_pf_files[@]}}\")"
  eval "${out_gone}=(\"\${_pf_gone[@]+\${_pf_gone[@]}}\")"
  return 0
}

# Collects directory paths from the dirname of each entry, walking up to
# (but not including) base. Appends unique paths to the named array.
# Usage: collect_dirs_to_prune base entries_ref out_dirs_ref
collect_dirs_to_prune() {
  local base="$1"
  local entries_ref="$2"
  local out_dirs_ref="$3"

  local _cdp_entries=()
  eval "_cdp_entries=(\"\${${entries_ref}[@]+\${${entries_ref}[@]}}\")"

  local entry dir candidate
  local -a new_dirs=()

  for entry in "${_cdp_entries[@]+"${_cdp_entries[@]}"}"; do
    local stripped="${entry#"$base/"}"
    dir="$(dirname "$stripped")"
    while [[ -n "$dir" && "$dir" != "." && "$dir" != "/" ]]; do
      candidate="$base/$dir"
      [[ "$candidate" == "$base" ]] && break
      local already=0
      local existing_dir
      local _cdp_current=()
      eval "_cdp_current=(\"\${${out_dirs_ref}[@]+\${${out_dirs_ref}[@]}}\")"
      for existing_dir in "${_cdp_current[@]+"${_cdp_current[@]}"}"; do
        [[ "$existing_dir" == "$candidate" ]] && { already=1; break; }
      done
      for existing_dir in "${new_dirs[@]+"${new_dirs[@]}"}"; do
        [[ "$existing_dir" == "$candidate" ]] && { already=1; break; }
      done
      (( already )) || new_dirs+=("$candidate")
      dir="$(dirname "$dir")"
    done
  done

  for candidate in "${new_dirs[@]+"${new_dirs[@]}"}"; do
    eval "${out_dirs_ref}+=(\"\$candidate\")"
  done
}

prune_empty_dirs() {
  local dirs_ref="$1"
  local _ped_dirs=()
  eval "_ped_dirs=(\"\${${dirs_ref}[@]+\${${dirs_ref}[@]}}\")"

  local changed=1
  local dir
  while (( changed )); do
    changed=0
    for dir in "${_ped_dirs[@]+"${_ped_dirs[@]}"}"; do
      if [[ -d "$dir" ]] && rmdir "$dir" 2>/dev/null; then
        changed=1
      fi
    done
  done
}

# Strips the elelem managed block from a file using awk, writing to a
# tempfile then moving into place. If the result is whitespace-only,
# the file is deleted.
# Usage: strip_codex_managed_block target
strip_codex_managed_block() {
  local target="$1"

  [[ -f "$target" ]] || return 0

  local tmp_file
  tmp_file="$(mktemp)"

  awk \
    -v start="$CODEX_MANAGED_START" \
    -v end="$CODEX_MANAGED_END" \
    'BEGIN { in_block = 0 }
     $0 == start { in_block = 1; next }
     in_block && $0 == end { in_block = 0; next }
     !in_block { print }' \
    "$target" > "$tmp_file"

  mv "$tmp_file" "$target"

  if ! grep -q '[^[:space:]]' "$target"; then
    rm -f "$target"
  fi
}

# ---------------------------------------------------------------------------
# Main body - guarded so this file is sourceable for testing
# ---------------------------------------------------------------------------

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then

  if ! { : >/dev/tty; } 2>/dev/null; then
    say_err "this script requires an interactive terminal (/dev/tty is not accessible)."
    exit 1
  fi

  manifest_glob="$SCRIPT_DIR/.elelem-manifest-*"
  if ! compgen -G "$manifest_glob" > /dev/null 2>&1; then
    say_info "Nothing to uninstall."
    exit 0
  fi

  manifest_paths=()
  while IFS= read -r -d '' _mp; do
    manifest_paths+=("$_mp")
  done < <(compgen -G "$manifest_glob" | sort | tr '\n' '\0')

  manifest_labels=()
  manifest_defaults=()
  for _mp in "${manifest_paths[@]}"; do
    manifest_labels+=("$(basename "$_mp")")
    manifest_defaults+=(0)
  done

  echo
  say_step "Select manifests to uninstall:"
  multiselect selected_labels manifest_labels manifest_defaults

  if (( ${#selected_labels[@]} == 0 )); then
    say_info "Aborted."
    exit 0
  fi

  selected_manifests=()
  for _label in "${selected_labels[@]}"; do
    selected_manifests+=("$SCRIPT_DIR/$_label")
  done

  say_step "Planned removals:"

  declare -a all_files=()
  declare -a all_gone=()
  declare -a all_dirs=()
  declare -a all_agents_md=()
  declare -a all_manifest_files=()

  for manifest_file in "${selected_manifests[@]}"; do
    manifest_name="$(basename "$manifest_file")"
    manifest_base=""
    manifest_files=()
    manifest_gone=()

    if ! parse_manifest "$manifest_file" manifest_base manifest_files manifest_gone; then
      continue
    fi

    echo
    say_info "Manifest: $manifest_name"
    say_info "  Base: $manifest_base"

    if [[ ! -d "$manifest_base" ]]; then
      say_warn "  $manifest_base does not exist (already removed)."
    fi

    for _f in "${manifest_files[@]+"${manifest_files[@]}"}"; do
      say_info "  delete: ${_f#"$manifest_base/"}"
      all_files+=("$_f")
    done

    for _g in "${manifest_gone[@]+"${manifest_gone[@]}"}"; do
      say_info "  (already gone): $_g"
      all_gone+=("$manifest_base/$_g")
    done

    combined_entries=()
    for _f in "${manifest_files[@]+"${manifest_files[@]}"}"; do
      combined_entries+=("$_f")
    done
    for _g in "${manifest_gone[@]+"${manifest_gone[@]}"}"; do
      combined_entries+=("$manifest_base/$_g")
    done

    collect_dirs_to_prune "$manifest_base" combined_entries all_dirs

    if [[ "$manifest_name" == ".elelem-manifest-codex" ]]; then
      agents_md="$(resolve_codex_agents_md "$manifest_base")"
      if [[ -f "$agents_md" ]] && grep -Fq "$CODEX_MANAGED_START" "$agents_md"; then
        say_info "  strip elelem managed block from: $agents_md"
        all_agents_md+=("$agents_md")
      fi
    fi

    all_manifest_files+=("$manifest_file")
  done

  if (( ${#all_dirs[@]} > 0 )); then
    echo
    say_info "Directories to prune (if empty after file removal):"
    for _d in "${all_dirs[@]}"; do
      say_info "  $_d"
    done
  fi

  echo

  confirm_items=("Proceed with removal")
  confirm_defaults=(0)
  multiselect confirm_selected confirm_items confirm_defaults

  if (( ${#confirm_selected[@]} == 0 )); then
    say_info "Aborted. No changes made."
    exit 0
  fi

  for _f in "${all_files[@]+"${all_files[@]}"}"; do
    rm -f "$_f"
  done

  prune_empty_dirs all_dirs

  for _am in "${all_agents_md[@]+"${all_agents_md[@]}"}"; do
    strip_codex_managed_block "$_am"
  done

  for manifest_file in "${all_manifest_files[@]+"${all_manifest_files[@]}"}"; do
    rm -f "$manifest_file"
    say_ok "removed $(basename "$manifest_file")"
  done

  echo
  say_ok "Done."
fi
