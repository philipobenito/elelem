#!/usr/bin/env bash
#
# Installs Claude Code rules and skills from this repo.
#
# Rules (./rules/) install to ~/.claude/rules/ (user scope) or
# <project>/.claude/rules/ (project scope). Common rules (rules/common/*.md)
# are always-on and have no frontmatter. Language packs (rules/<lang>/*.md)
# use YAML `globs:` frontmatter and are auto-loaded when Claude reads matching files.
#
# Skills (./skills/) install to ~/.claude/skills/ or <project>/.claude/skills/.
#
# A manifest file (.elelem-manifest-claude) in this repo tracks which files were
# installed and where. On re-install to the same target, files present in the
# old manifest but absent from the new one are removed. Files not in the
# manifest (user-created) are left untouched.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RULES_SOURCE="$SCRIPT_DIR/rules"
SKILLS_SOURCE="$SCRIPT_DIR/skills"

source "$SCRIPT_DIR/_install-common.sh"

# Resolves a source skill file to its destination by stripping $SKILLS_SOURCE
# from the path, preserving the subdirectory structure under $out. Reads
# $SKILLS_SOURCE from the installer's global scope; do not call before
# SKILLS_SOURCE is set.
_skill_resolve_dst() {
  local src="$1"
  local out="$2"
  printf '%s/%s\n' "$out" "${src#$SKILLS_SOURCE/}"
}

# Runs the deterministic install sequence for already-resolved selections:
# creates the target directories, installs the selected common rules,
# language packs, and skills, then prunes stale manifest entries and writes
# the new manifest. Contains no prompting; callers (the interactive main
# body, or a test) resolve selections first and pass them in.
#
# Usage: run_claude_install base rules_target skills_target manifest_file manifest_ref common_selected_ref lang_selected_ref skills_selected_ref
#   base                 - the resolved install base path
#   rules_target         - $base/rules
#   skills_target        - $base/skills
#   manifest_file        - path to the manifest file to prune/write
#   manifest_ref         - name of a caller array variable; new entries are appended
#   common_selected_ref  - name of an array variable of selected common rule basenames (no .md)
#   lang_selected_ref    - name of an array variable of selected language pack directory names
#   skills_selected_ref  - name of an array variable; non-empty means install skills
#
# Does NOT use local -n; compatible with bash 3.2+.
run_claude_install() {
  local base="$1"
  local rules_target="$2"
  local skills_target="$3"
  local manifest_file="$4"
  local manifest_ref="$5"
  local common_selected_ref="$6"
  local lang_selected_ref="$7"
  local skills_selected_ref="$8"

  [[ "$manifest_ref"        =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { say_err "run_claude_install: invalid manifest_ref variable name: $manifest_ref"               ; exit 1; }
  [[ "$common_selected_ref" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { say_err "run_claude_install: invalid common_selected_ref variable name: $common_selected_ref" ; exit 1; }
  [[ "$lang_selected_ref"   =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { say_err "run_claude_install: invalid lang_selected_ref variable name: $lang_selected_ref"     ; exit 1; }
  [[ "$skills_selected_ref" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { say_err "run_claude_install: invalid skills_selected_ref variable name: $skills_selected_ref" ; exit 1; }

  local _rci_common_selected _rci_lang_selected _rci_skills_selected
  eval "_rci_common_selected=(\"\${${common_selected_ref}[@]+\${${common_selected_ref}[@]}}\")"
  eval "_rci_lang_selected=(\"\${${lang_selected_ref}[@]+\${${lang_selected_ref}[@]}}\")"
  eval "_rci_skills_selected=(\"\${${skills_selected_ref}[@]+\${${skills_selected_ref}[@]}}\")"

  mkdir -p "$rules_target"

  if (( ${#_rci_common_selected[@]} > 0 )); then
    local common_files=()
    local _item
    for _item in "${_rci_common_selected[@]}"; do
      common_files+=("${_item}.md")
    done
    mkdir -p "$rules_target/common"
    install_files_from_dir "$RULES_SOURCE/common" "$rules_target/common" "rules/common" "$manifest_ref" common_files
    say_ok "installed: ${_rci_common_selected[*]}"
  fi

  if (( ${#_rci_lang_selected[@]} > 0 )); then
    local pick
    for pick in "${_rci_lang_selected[@]}"; do
      local lang_files=()
      local _f
      for _f in "$RULES_SOURCE/$pick/"*.md; do
        [[ -f "$_f" ]] || continue
        lang_files+=("$(basename "$_f")")
      done
      mkdir -p "$rules_target/$pick"
      install_files_from_dir "$RULES_SOURCE/$pick" "$rules_target/$pick" "rules/$pick" "$manifest_ref" lang_files
      say_ok "installed: $pick"
    done
  fi

  if (( ${#_rci_skills_selected[@]} > 0 )); then
    say_info "Installing skills -> $skills_target/"
    mkdir -p "$skills_target"
    local skills_files=()
    local _f
    while IFS= read -r -d '' _f; do
      skills_files+=("${_f#"$SKILLS_SOURCE"/}")
    done < <(find "$SKILLS_SOURCE" -type f -print0)
    install_files_from_dir "$SKILLS_SOURCE" "$skills_target" "skills" "$manifest_ref" skills_files _skill_resolve_dst

    local installed_skills=()
    local skill_dir
    for skill_dir in "$skills_target"/*/; do
      [[ -d "$skill_dir" ]] || continue
      installed_skills+=("$(basename "$skill_dir")")
    done
    say_ok "installed ${#installed_skills[@]} skill(s): ${installed_skills[*]}"
  fi

  prune_stale_manifest_entries "$manifest_file" "$base" "$manifest_ref"
  write_manifest "$manifest_file" "$base" "$manifest_ref"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then

  if ! { : >/dev/tty; } 2>/dev/null; then
    say_err "this script requires an interactive terminal (/dev/tty is not accessible)."
    exit 1
  fi

  if [[ ! -d "$RULES_SOURCE/common" ]]; then
    say_err "$RULES_SOURCE/common does not exist"
    exit 1
  fi

  resolve_install_base base "$HOME/.claude" ".claude"

  rules_target="$base/rules"
  skills_target="$base/skills"
  manifest_file="$SCRIPT_DIR/.elelem-manifest-claude"
  manifest_entries=()

  echo
  say_step "Common instruction files to install:"
  common_items=()
  common_defaults=()
  for _f in "$RULES_SOURCE/common/"*.md; do
    [[ -f "$_f" ]] || continue
    _base="$(basename "$_f" .md)"
    common_items+=("$_base")
    common_defaults+=(1)
  done

  multiselect common_selected common_items common_defaults

  if (( ${#common_selected[@]} == 0 )); then
    say_warn "no common rules selected."
    confirm_common_items=("Continue with no common rules")
    confirm_common_defaults=(0)
    multiselect confirm_common_selected confirm_common_items confirm_common_defaults
    (( ${#confirm_common_selected[@]} > 0 )) || { say_info "Aborted."; exit 0; }
  fi

  lang_dirs=()
  for dir in "$RULES_SOURCE"/*/; do
    name="$(basename "$dir")"
    [[ "$name" == "common" ]] && continue
    if compgen -G "$dir*.md" > /dev/null; then
      lang_dirs+=("$name")
    fi
  done

  lang_selected=()
  if (( ${#lang_dirs[@]} > 0 )); then
    lang_defaults=()
    for _ in "${lang_dirs[@]}"; do
      lang_defaults+=(0)
    done
    echo
    say_step "Language packs to install (none selected by default):"
    multiselect lang_selected lang_dirs lang_defaults
  else
    echo
    say_info "No language packs found in $RULES_SOURCE (common-only install)."
  fi

  skills_selected=()
  if [[ -d "$SKILLS_SOURCE" ]] && compgen -G "$SKILLS_SOURCE/*/" > /dev/null; then
    echo
    say_step "Skills (target: $skills_target):"
    skills_items=("Install skills")
    skills_defaults=(1)
    multiselect skills_selected skills_items skills_defaults

    if (( ${#skills_selected[@]} == 0 )); then
      say_info "Skipped skills install."
    fi
  else
    echo
    say_info "No skills found in $SKILLS_SOURCE (skipping skills install)."
  fi

  run_claude_install "$base" "$rules_target" "$skills_target" "$manifest_file" manifest_entries common_selected lang_selected skills_selected

  echo
  say_ok "Done."
  echo "Rules:  $rules_target"
  echo "Skills: $skills_target"
  echo "Verify rules inside Claude Code with: /memory"
fi
