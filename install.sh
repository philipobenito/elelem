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
# uninstall.sh and the test suite source this file for its functions; the
# interactive install body at the bottom is guarded so sourcing runs nothing.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RULES_SOURCE="$SCRIPT_DIR/rules"
SKILLS_SOURCE="$SCRIPT_DIR/skills"

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------

# ANSI colour palette and tiny logging helpers.
#
# Colours are emitted only when stdout is a real terminal, NO_COLOR is unset
# (https://no-color.org), and TERM is not "dumb". When any of those checks fail,
# every colour variable expands to the empty string, so the helpers degrade to
# plain ASCII automatically — safe for `./install.sh > log.txt` and CI logs.
#
# The visual prefixes ("Error:", "Warning:") are kept literal so existing
# `grep -E '^(Error|Warning):'` scans of saved logs still work; the colour is
# only a visual layer on top.
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]] && [[ "${TERM:-}" != "dumb" ]]; then
  ELELEM_C_RESET=$'\033[0m'
  ELELEM_C_BOLD=$'\033[1m'
  ELELEM_C_DIM=$'\033[2m'
  ELELEM_C_RED=$'\033[31m'
  ELELEM_C_GREEN=$'\033[32m'
  ELELEM_C_YELLOW=$'\033[33m'
  ELELEM_C_BLUE=$'\033[34m'
  ELELEM_C_CYAN=$'\033[36m'
else
  ELELEM_C_RESET=""
  ELELEM_C_BOLD=""
  ELELEM_C_DIM=""
  ELELEM_C_RED=""
  ELELEM_C_GREEN=""
  ELELEM_C_YELLOW=""
  ELELEM_C_BLUE=""
  ELELEM_C_CYAN=""
fi

# say_step "msg"   - bold blue ==> for major install phases
# say_info "msg"   - cyan bullet for neutral status
# say_ok   "msg"   - green for completion / success
# say_warn "msg"   - yellow "Warning:" to stderr
# say_err  "msg"   - red "Error:" to stderr
say_step() { printf '%s==>%s %s%s%s\n' "$ELELEM_C_BLUE"   "$ELELEM_C_RESET" "$ELELEM_C_BOLD" "$*" "$ELELEM_C_RESET"; }
say_info() { printf '%s -%s %s\n'      "$ELELEM_C_CYAN"   "$ELELEM_C_RESET" "$*"; }
say_ok()   { printf '%s  ok%s %s\n'    "$ELELEM_C_GREEN"  "$ELELEM_C_RESET" "$*"; }
say_warn() { printf '%sWarning:%s %s\n' "$ELELEM_C_YELLOW" "$ELELEM_C_RESET" "$*" >&2; }
say_err()  { printf '%sError:%s %s\n'   "$ELELEM_C_RED"    "$ELELEM_C_RESET" "$*" >&2; }

# ---------------------------------------------------------------------------
# Interactive selectors
# ---------------------------------------------------------------------------

# Interactive checkbox selector.
# Usage: multiselect RESULT_VAR items defaults
#   RESULT_VAR  - name of a global array variable to populate with selected items
#   items       - name of an array variable (in caller scope) with the item labels
#   defaults    - name of an array variable (in caller scope) where each element is
#                 1 (initially selected) or 0 (initially unselected)
#
# Does NOT use local -n; compatible with bash 3.2+.
# All tput calls are wrapped in || true so a dumb terminal does not abort the script.
multiselect() {
  local result_var="$1"
  local items_ref="$2"
  local defaults_ref="$3"

  [[ "$result_var"   =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { echo "multiselect: invalid result variable name: $result_var"   >&2; return 1; }
  [[ "$items_ref"    =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { echo "multiselect: invalid items variable name: $items_ref"    >&2; return 1; }
  [[ "$defaults_ref" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { echo "multiselect: invalid defaults variable name: $defaults_ref" >&2; return 1; }

  local items_list defaults_list
  eval "items_list=(\"\${${items_ref}[@]+\${${items_ref}[@]}}\")"
  eval "defaults_list=(\"\${${defaults_ref}[@]+\${${defaults_ref}[@]}}\")"

  local count="${#items_list[@]}"
  local -a selected
  local i
  for (( i=0; i<count; i++ )); do
    selected[$i]="${defaults_list[$i]:-0}"
  done

  local cursor=0

  tput civis || true
  local _ms_old_exit _ms_old_int _ms_old_term
  _ms_old_exit="$(trap -p EXIT)"
  _ms_old_int="$(trap -p INT)"
  _ms_old_term="$(trap -p TERM)"
  # shellcheck disable=SC2064
  trap "tput cnorm || true; eval \"${_ms_old_exit:-trap - EXIT}\"; eval \"${_ms_old_int:-trap - INT}\"; eval \"${_ms_old_term:-trap - TERM}\"" EXIT INT TERM

  _multiselect_draw() {
    printf '%sSelect items (↑↓ to move, space to toggle, enter to confirm):%s\n' "$ELELEM_C_DIM" "$ELELEM_C_RESET"
    for (( i=0; i<count; i++ )); do
      local mark="[ ]"
      [[ "${selected[$i]}" == "1" ]] && mark="[x]"
      if (( i == cursor )); then
        echo "> $mark ${items_list[$i]}"
      else
        echo "  $mark ${items_list[$i]}"
      fi
    done
  }

  local lines=$(( count + 1 ))

  _multiselect_draw

  while true; do
    local key
    IFS= read -rsn1 key </dev/tty
    if [[ "$key" == $'\x1b' ]]; then
      local rest
      IFS= read -rsn2 rest </dev/tty || true
      key="${key}${rest}"
    fi

    case "$key" in
      $'\x1b[A')
        (( cursor > 0 )) && (( cursor-- )) || true
        ;;
      $'\x1b[B')
        (( cursor < count - 1 )) && (( cursor++ )) || true
        ;;
      ' ')
        if [[ "${selected[$cursor]}" == "1" ]]; then
          selected[$cursor]=0
        else
          selected[$cursor]=1
        fi
        ;;
      ''|$'\n'|$'\r')
        break
        ;;
    esac

    tput cuu "$lines" || true
    _multiselect_draw
  done

  tput cnorm || true
  eval "${_ms_old_exit:-trap - EXIT}"
  eval "${_ms_old_int:-trap - INT}"
  eval "${_ms_old_term:-trap - TERM}"

  local result_items=()
  for (( i=0; i<count; i++ )); do
    [[ "${selected[$i]}" == "1" ]] && result_items+=("${items_list[$i]}")
  done
  eval "${result_var}=(\"\${result_items[@]+\${result_items[@]}}\")"
  unset -f _multiselect_draw
}

# Interactive single-choice (radio) selector.
# Usage: singleselect RESULT_VAR items [default_index]
#   RESULT_VAR    - name of a global variable to populate with the chosen item label
#   items         - name of an array variable (in caller scope) with the item labels
#   default_index - (optional) initial cursor position; defaults to 0
#
# The cursor position IS the selection: arrows move, enter confirms. There is no
# toggle and no way to pick zero or more than one item, so callers do not need
# the count-checking dance that multiselect requires.
#
# Does NOT use local -n; compatible with bash 3.2+.
singleselect() {
  local result_var="$1"
  local items_ref="$2"
  local cursor="${3:-0}"

  [[ "$result_var" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { echo "singleselect: invalid result variable name: $result_var" >&2; return 1; }
  [[ "$items_ref"  =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { echo "singleselect: invalid items variable name: $items_ref"  >&2; return 1; }

  local items_list
  eval "items_list=(\"\${${items_ref}[@]+\${${items_ref}[@]}}\")"

  local count="${#items_list[@]}"
  if (( count == 0 )); then
    echo "singleselect: no items to choose from" >&2
    return 1
  fi
  if (( cursor < 0 || cursor >= count )); then
    cursor=0
  fi

  tput civis || true
  local _ss_old_exit _ss_old_int _ss_old_term
  _ss_old_exit="$(trap -p EXIT)"
  _ss_old_int="$(trap -p INT)"
  _ss_old_term="$(trap -p TERM)"
  # shellcheck disable=SC2064
  trap "tput cnorm || true; eval \"${_ss_old_exit:-trap - EXIT}\"; eval \"${_ss_old_int:-trap - INT}\"; eval \"${_ss_old_term:-trap - TERM}\"" EXIT INT TERM

  _singleselect_draw() {
    printf '%sUse ↑↓ to choose, enter to confirm:%s\n' "$ELELEM_C_DIM" "$ELELEM_C_RESET"
    local i
    for (( i=0; i<count; i++ )); do
      if (( i == cursor )); then
        echo "> (o) ${items_list[$i]}"
      else
        echo "  ( ) ${items_list[$i]}"
      fi
    done
  }

  local lines=$(( count + 1 ))

  _singleselect_draw

  while true; do
    local key
    IFS= read -rsn1 key </dev/tty
    if [[ "$key" == $'\x1b' ]]; then
      local rest
      IFS= read -rsn2 rest </dev/tty || true
      key="${key}${rest}"
    fi

    case "$key" in
      $'\x1b[A')
        (( cursor > 0 )) && (( cursor-- )) || true
        ;;
      $'\x1b[B')
        (( cursor < count - 1 )) && (( cursor++ )) || true
        ;;
      ''|$'\n'|$'\r')
        break
        ;;
    esac

    tput cuu "$lines" || true
    _singleselect_draw
  done

  tput cnorm || true
  eval "${_ss_old_exit:-trap - EXIT}"
  eval "${_ss_old_int:-trap - INT}"
  eval "${_ss_old_term:-trap - TERM}"

  eval "${result_var}=\"\${items_list[$cursor]}\""
  unset -f _singleselect_draw
}

# ---------------------------------------------------------------------------
# Install helpers
# ---------------------------------------------------------------------------

# Prompts the user to select an install scope and resolves the base install
# path: user scope ($HOME/.claude) or project scope (<project>/.claude).
# Usage: resolve_install_base RESULT_VAR
#   RESULT_VAR - name of a global variable to populate with the resolved base path
resolve_install_base() {
  local result_var="$1"
  local user_base="$HOME/.claude"
  local project_suffix=".claude"

  [[ "$result_var" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { echo "resolve_install_base: invalid result variable name: $result_var" >&2; return 1; }

  local scope_items scope_choice
  scope_items=("project  ->  <project>/$project_suffix/" "user  ->  $user_base/")
  echo "Install scope:"
  singleselect scope_choice scope_items 1

  local scope=""
  if [[ "$scope_choice" == project* ]]; then
    scope=p
  elif [[ "$scope_choice" == user* ]]; then
    scope=u
  fi

  local resolved_base=""
  case "$scope" in
    p|P)
      local project_path
      read -rp "Project path [$(pwd)]: " project_path
      project_path="${project_path:-$(pwd)}"
      if [[ ! -d "$project_path" ]]; then
        say_err "$project_path does not exist"
        return 1
      fi
      resolved_base="$project_path/$project_suffix"
      ;;
    u|U)
      resolved_base="$user_base"
      echo "Installing to $user_base/"
      ;;
    *)
      echo "Invalid choice." >&2
      return 1
      ;;
  esac

  eval "${result_var}=\"\$resolved_base\""
}

# Prunes stale entries from the manifest: files present in the old manifest but
# absent from the new install set are removed from disk.
# Usage: prune_stale_manifest_entries manifest_file base new_entries_ref
#   manifest_file   - path to the manifest file to read
#   base            - the current install base path
#   new_entries_ref - name of an array variable containing the newly installed relative paths
prune_stale_manifest_entries() {
  local manifest_file="$1"
  local base="$2"
  local new_entries_ref="$3"

  [[ -f "$manifest_file" ]] || return 0
  [[ "$new_entries_ref" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { echo "prune_stale_manifest_entries: invalid new_entries variable name: $new_entries_ref" >&2; return 1; }

  local new_entries
  eval "new_entries=(\"\${${new_entries_ref}[@]+\${${new_entries_ref}[@]}}\")"

  local old_base=""
  local removed=0
  local first_line=1
  while IFS= read -r line; do
    if (( first_line )); then
      old_base="$line"
      first_line=0
      continue
    fi
    [[ -z "$line" ]] && continue
    if [[ "$old_base" != "$base" ]]; then
      continue
    fi
    local found=0
    local new_entry
    for new_entry in "${new_entries[@]+"${new_entries[@]}"}"; do
      if [[ "$new_entry" == "$line" ]]; then
        found=1
        break
      fi
    done
    if (( found == 0 )) && [[ -f "$base/$line" ]]; then
      rm "$base/$line"
      echo "  removed stale: $line"
      (( removed++ )) || true
    fi
  done < "$manifest_file"

  if (( removed > 0 )); then
    local rules_dir="$base/rules"
    local skills_dir="$base/skills"
    find "$rules_dir" "$skills_dir" -type d -empty -delete 2>/dev/null || true
  fi
}

# Writes a manifest file: first line is the base path, subsequent lines are the
# relative entries sorted alphabetically.
# Usage: write_manifest manifest_file base entries_ref
#   manifest_file - path to write
#   base          - install base path (first line of manifest)
#   entries_ref   - name of an array variable containing relative paths to record
write_manifest() {
  local manifest_file="$1"
  local base="$2"
  local entries_ref="$3"

  [[ "$entries_ref" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { echo "write_manifest: invalid entries variable name: $entries_ref" >&2; return 1; }

  local entries
  eval "entries=(\"\${${entries_ref}[@]+\${${entries_ref}[@]}}\")"

  { echo "$base"; printf '%s\n' "${entries[@]+"${entries[@]}"}" | sort; } > "$manifest_file"
}

# Copies a list of source files into an output directory, preserving each
# file's path relative to the source directory, and appends a manifest entry
# for every installed file.
# Usage: install_files_from_dir source_dir output_dir manifest_prefix manifest_ref files_ref
#   source_dir      - absolute path to the source directory
#   output_dir      - absolute path to the destination directory
#   manifest_prefix - relative prefix prepended to each manifest entry (no trailing slash)
#   manifest_ref    - name of a caller array variable; new entries are appended
#   files_ref       - name of an array variable of source paths relative to source_dir
install_files_from_dir() {
  local source_dir="$1"
  local output_dir="$2"
  local manifest_prefix="$3"
  local manifest_ref="$4"
  local files_ref="$5"

  [[ "$manifest_ref" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { echo "install_files_from_dir: invalid manifest_ref variable name: $manifest_ref" >&2; exit 1; }
  [[ "$files_ref"    =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { echo "install_files_from_dir: invalid files_ref variable name: $files_ref"       >&2; exit 1; }

  local _ifd_files
  eval "_ifd_files=(\"\${${files_ref}[@]+\${${files_ref}[@]}}\")"

  local rel src dst entry
  for rel in "${_ifd_files[@]+"${_ifd_files[@]}"}"; do
    src="$source_dir/$rel"
    dst="$output_dir/$rel"
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst" || { say_err "install_files_from_dir: copy failed for: $src"; exit 1; }
    entry="${manifest_prefix}/${rel}"
    eval "${manifest_ref}+=(\"\$entry\")"
  done
}

# Returns every .md basename (without extension) found directly in
# rules/common/. Common rules always install in full, so this is the sole
# source of truth for what "all common rules" means; the interactive body
# and the test suite both read it through this function rather than
# re-globbing $RULES_SOURCE/common themselves.
# Usage: common_rule_basenames RESULT_VAR
#   RESULT_VAR - name of a caller array variable to populate with basenames
common_rule_basenames() {
  local result_var="$1"

  [[ "$result_var" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { say_err "common_rule_basenames: invalid result variable name: $result_var"; exit 1; }

  local _crb_names=()
  local _f
  for _f in "$RULES_SOURCE/common/"*.md; do
    [[ -f "$_f" ]] || continue
    _crb_names+=("$(basename "$_f" .md)")
  done

  eval "${result_var}=(\"\${_crb_names[@]+\${_crb_names[@]}}\")"
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
    install_files_from_dir "$SKILLS_SOURCE" "$skills_target" "skills" "$manifest_ref" skills_files

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

# ---------------------------------------------------------------------------
# Interactive main body - guarded so this file is sourceable
# ---------------------------------------------------------------------------

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then

  if ! { : >/dev/tty; } 2>/dev/null; then
    say_err "this script requires an interactive terminal (/dev/tty is not accessible)."
    exit 1
  fi

  if [[ ! -d "$RULES_SOURCE/common" ]]; then
    say_err "$RULES_SOURCE/common does not exist"
    exit 1
  fi

  resolve_install_base base

  rules_target="$base/rules"
  skills_target="$base/skills"
  manifest_file="$SCRIPT_DIR/.elelem-manifest-claude"
  manifest_entries=()

  common_rule_basenames common_selected

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
    skills_selected=("Install skills")
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
