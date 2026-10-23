#!/usr/bin/env bash
#
# Installs rules and skills from this repo for Claude Code or OpenCode.
#
# Claude Code
#   Rules (./rules/) install to ~/.claude/rules/ (user scope) or
#   <project>/.claude/rules/ (project scope). Common rules (rules/common/*.md)
#   are always-on and have no frontmatter. Language packs (rules/<lang>/*.md)
#   use YAML `globs:` frontmatter and are auto-loaded when Claude reads matching files.
#   Skills install to ~/.claude/skills/ or <project>/.claude/skills/.
#
# OpenCode
#   Rules install to ~/.config/opencode/rules/ (user scope) or
#   <project>/.opencode/rules/ (project scope), and are listed in the
#   `instructions` array of opencode.json (merged, never replaced wholesale).
#   OpenCode has no path-based activation, so selected language packs load in
#   every session. Skills install to <base>/skills/. Claude Code tool names in
#   the copied markdown are rewritten to their OpenCode equivalents.
#
# Which skills install is a per-skill choice for both harnesses.
#
# A manifest file per harness (.elelem-manifest-claude, .elelem-manifest-opencode)
# in this repo tracks which files were installed and where. On re-install to the
# same target, files present in the old manifest but absent from the new one are
# removed. Files not in the manifest (user-created) are left untouched.
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
# path: user scope (USER_BASE) or project scope (<project>/PROJECT_SUFFIX).
# Usage: resolve_install_base RESULT_VAR USER_BASE PROJECT_SUFFIX
#   RESULT_VAR     - name of a global variable to populate with the resolved base path
#   USER_BASE      - absolute user-scope base, e.g. $HOME/.claude
#   PROJECT_SUFFIX - project-scope directory name, e.g. .claude
resolve_install_base() {
  local result_var="$1"
  local user_base="$2"
  local project_suffix="$3"

  [[ "$result_var" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { echo "resolve_install_base: invalid result variable name: $result_var" >&2; return 1; }
  [[ -n "$user_base" && -n "$project_suffix" ]] || { echo "resolve_install_base: user base and project suffix are required" >&2; return 1; }

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

# Returns 0 when manifest_file records the given entry for the given base.
# Usage: manifest_lists_entry manifest_file base entry
manifest_lists_entry() {
  local manifest_file="$1"
  local base="$2"
  local entry="$3"

  [[ -f "$manifest_file" ]] || return 1
  [[ "$(head -n1 "$manifest_file")" == "$base" ]] || return 1
  tail -n +2 "$manifest_file" | grep -qxF -- "$entry"
}

# Copies a list of source files into an output directory, preserving each
# file's path relative to the source directory, and appends a manifest entry
# for every installed file.
# Usage: install_files_from_dir source_dir output_dir manifest_prefix manifest_ref files_ref [transform_fn]
#   source_dir      - absolute path to the source directory
#   output_dir      - absolute path to the destination directory
#   manifest_prefix - relative prefix prepended to each manifest entry (no trailing slash)
#   manifest_ref    - name of a caller array variable; new entries are appended
#   files_ref       - name of an array variable of source paths relative to source_dir
#   transform_fn    - optional name of a function called with each copied file's
#                     destination path (used to rewrite content after the copy)
install_files_from_dir() {
  local source_dir="$1"
  local output_dir="$2"
  local manifest_prefix="$3"
  local manifest_ref="$4"
  local files_ref="$5"
  local transform_fn="${6:-}"

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
    if [[ -n "$transform_fn" ]]; then
      "$transform_fn" "$dst" || { say_err "install_files_from_dir: $transform_fn failed for: $dst"; exit 1; }
    fi
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

# Returns the name of every skill folder directly under skills/. This is the
# sole source of truth for which skills can be chosen; the interactive body
# and the test suite both read it through this function.
# Usage: skill_basenames RESULT_VAR
#   RESULT_VAR - name of a caller array variable to populate with skill names
skill_basenames() {
  local result_var="$1"

  [[ "$result_var" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { say_err "skill_basenames: invalid result variable name: $result_var"; exit 1; }

  local _sb_names=()
  local _d
  for _d in "$SKILLS_SOURCE"/*/; do
    [[ -d "$_d" ]] || continue
    _sb_names+=("$(basename "$_d")")
  done

  eval "${result_var}=(\"\${_sb_names[@]+\${_sb_names[@]}}\")"
}

# Copies the selected common rules, language packs and skills into the target
# directories and appends a manifest entry for each file. Shared by both
# harness installs; contains no prompting and does not touch the manifest file.
# Usage: _install_content rules_target skills_target manifest_ref common_selected_ref lang_selected_ref skills_selected_ref [transform_fn]
#   transform_fn - optional; see install_files_from_dir
_install_content() {
  local rules_target="$1"
  local skills_target="$2"
  local manifest_ref="$3"
  local common_selected_ref="$4"
  local lang_selected_ref="$5"
  local skills_selected_ref="$6"
  local transform_fn="${7:-}"

  [[ "$manifest_ref"        =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { say_err "_install_content: invalid manifest_ref variable name: $manifest_ref"               ; exit 1; }
  [[ "$common_selected_ref" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { say_err "_install_content: invalid common_selected_ref variable name: $common_selected_ref" ; exit 1; }
  [[ "$lang_selected_ref"   =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { say_err "_install_content: invalid lang_selected_ref variable name: $lang_selected_ref"     ; exit 1; }
  [[ "$skills_selected_ref" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { say_err "_install_content: invalid skills_selected_ref variable name: $skills_selected_ref" ; exit 1; }

  local _ic_common_selected _ic_lang_selected _ic_skills_selected
  eval "_ic_common_selected=(\"\${${common_selected_ref}[@]+\${${common_selected_ref}[@]}}\")"
  eval "_ic_lang_selected=(\"\${${lang_selected_ref}[@]+\${${lang_selected_ref}[@]}}\")"
  eval "_ic_skills_selected=(\"\${${skills_selected_ref}[@]+\${${skills_selected_ref}[@]}}\")"

  mkdir -p "$rules_target"

  if (( ${#_ic_common_selected[@]} > 0 )); then
    local common_files=()
    local _item
    for _item in "${_ic_common_selected[@]}"; do
      common_files+=("${_item}.md")
    done
    mkdir -p "$rules_target/common"
    install_files_from_dir "$RULES_SOURCE/common" "$rules_target/common" "rules/common" "$manifest_ref" common_files "$transform_fn"
    say_ok "installed: ${_ic_common_selected[*]}"
  fi

  if (( ${#_ic_lang_selected[@]} > 0 )); then
    local pick
    for pick in "${_ic_lang_selected[@]}"; do
      local lang_files=()
      local _f
      for _f in "$RULES_SOURCE/$pick/"*.md; do
        [[ -f "$_f" ]] || continue
        lang_files+=("$(basename "$_f")")
      done
      mkdir -p "$rules_target/$pick"
      install_files_from_dir "$RULES_SOURCE/$pick" "$rules_target/$pick" "rules/$pick" "$manifest_ref" lang_files "$transform_fn"
      say_ok "installed: $pick"
    done
  fi

  if (( ${#_ic_skills_selected[@]} > 0 )); then
    say_info "Installing skills -> $skills_target/"
    mkdir -p "$skills_target"
    local skills_files=()
    local _skill _sf
    for _skill in "${_ic_skills_selected[@]}"; do
      [[ "$_skill" =~ ^[a-zA-Z0-9_-]+$ && -d "$SKILLS_SOURCE/$_skill" ]] || { say_err "unknown skill: $_skill"; exit 1; }
      while IFS= read -r -d '' _sf; do
        skills_files+=("${_sf#"$SKILLS_SOURCE"/}")
      done < <(find "$SKILLS_SOURCE/$_skill" -type f -print0)
    done
    install_files_from_dir "$SKILLS_SOURCE" "$skills_target" "skills" "$manifest_ref" skills_files "$transform_fn"
    say_ok "installed ${#_ic_skills_selected[@]} skill(s): ${_ic_skills_selected[*]}"
  fi
}

# Runs the deterministic Claude Code install sequence for already-resolved
# selections: installs the selected common rules, language packs, and skills,
# then prunes stale manifest entries and writes the new manifest. Contains no
# prompting; callers (the interactive main body, or a test) resolve selections
# first and pass them in.
#
# Usage: run_claude_install base rules_target skills_target manifest_file manifest_ref common_selected_ref lang_selected_ref skills_selected_ref
#   base                 - the resolved install base path
#   rules_target         - $base/rules
#   skills_target        - $base/skills
#   manifest_file        - path to the manifest file to prune/write
#   manifest_ref         - name of a caller array variable; new entries are appended
#   common_selected_ref  - name of an array variable of selected common rule basenames (no .md)
#   lang_selected_ref    - name of an array variable of selected language pack directory names
#   skills_selected_ref  - name of an array variable of selected skill folder names
#
# Does NOT use local -n; compatible with bash 3.2+.
run_claude_install() {
  local base="$1"
  local rules_target="$2"
  local skills_target="$3"
  local manifest_file="$4"
  local manifest_ref="$5"

  _install_content "$rules_target" "$skills_target" "$manifest_ref" "$6" "$7" "$8"

  prune_stale_manifest_entries "$manifest_file" "$base" "$manifest_ref"
  write_manifest "$manifest_file" "$base" "$manifest_ref"
}

# ---------------------------------------------------------------------------
# OpenCode
# ---------------------------------------------------------------------------

# Claude Code tool names in the copied markdown, and what they become on
# OpenCode. The two arrays are parallel and applied in order, so a specific
# phrase must come before any shorter pattern it contains. Matching is literal;
# a "^" prefix anchors the pattern at the start of a line. Text containing a
# tab or newline cannot be used.
#
# `Workflow` is deliberately absent: OpenCode has no equivalent yet, and the
# skills that call it already fall back to sequential dispatch when it is
# unavailable.
OPENCODE_SUBST_FROM=(
  '`EnterPlanMode` and `ExitPlanMode` are deferred tools in some sessions, so load them with `ToolSearch` (`select:EnterPlanMode,ExitPlanMode`) first'
  'load `EnterPlanMode` and `ExitPlanMode` via `ToolSearch` first where they are deferred'
  'release plan mode via `ExitPlanMode` carrying the approved summary'
  'so the call releases the session rather than asking again'
  'then `ExitPlanMode` carrying the summary.'
  'Plan mode was released via `ExitPlanMode`'
  'reading the values the `Agent` tool'"'"'s `model` parameter accepts'
  '^Agent (general-purpose):'
  '^Agent:'
  'subagent_type: "Plan"'
  '`AskUserQuestion`'
  '`Agent`'
)
OPENCODE_SUBST_TO=(
  'OpenCode has no plan-mode tools, so ask the user to switch to the Plan agent (Tab) first'
  'OpenCode has no plan-mode tools, so ask the user to switch to the Plan agent (Tab) first'
  'release plan mode by asking the user to switch back to the Build agent (Tab), restating the approved summary'
  'so the switch hands the session over rather than asking for approval again'
  'then ask the user to switch back to the Build agent (Tab), restating the summary.'
  'Plan mode was released by the user switching back to the Build agent'
  'running `opencode models` with the `shell` tool, which lists every available model, one per line'
  'task (general):'
  'task:'
  'subagent_type: "explore"'
  '`question`'
  '`task`'
)

# Rewrites Claude Code tool names in one installed markdown file to their
# OpenCode equivalents, per OPENCODE_SUBST_FROM / OPENCODE_SUBST_TO. Files that
# are not markdown are left alone.
# Usage: opencode_transform_file file
opencode_transform_file() {
  local file="$1"

  [[ "$file" == *.md ]] || return 0

  local pairs="" i
  for (( i=0; i<${#OPENCODE_SUBST_FROM[@]}; i++ )); do
    pairs+="${OPENCODE_SUBST_FROM[$i]}"$'\t'"${OPENCODE_SUBST_TO[$i]}"$'\n'
  done

  ELELEM_SUBST="$pairs" perl -i -pe '
    BEGIN {
      for my $line (split /\n/, $ENV{ELELEM_SUBST}) {
        my ($from, $to) = split /\t/, $line, 2;
        my $anchored = ($from =~ s/^\^//);
        my $re = $anchored ? "^\Q$from\E" : "\Q$from\E";
        push @rules, [qr/$re/, $to];
      }
    }
    for my $rule (@rules) { s/$rule->[0]/$rule->[1]/g }
  ' "$file"
}

# Reports Claude Code tool names still present in installed markdown after the
# transform ran, which means a substitution above has drifted from the source
# text. Warns for each hit; returns 1 if any were found.
# Usage: opencode_report_residue base entries_ref
#   entries_ref - name of an array variable of manifest-relative paths
opencode_report_residue() {
  local base="$1"
  local entries_ref="$2"

  [[ "$entries_ref" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { echo "opencode_report_residue: invalid entries variable name: $entries_ref" >&2; return 1; }

  local _orr_entries
  eval "_orr_entries=(\"\${${entries_ref}[@]+\${${entries_ref}[@]}}\")"

  local found=0 entry hits line
  for entry in "${_orr_entries[@]+"${_orr_entries[@]}"}"; do
    [[ "$entry" == *.md && -f "$base/$entry" ]] || continue
    hits="$(grep -nE 'AskUserQuestion|EnterPlanMode|ExitPlanMode|ToolSearch|`Agent`|^Agent[ :]' "$base/$entry" 2>/dev/null)" || true
    [[ -n "$hits" ]] || continue
    found=1
    say_warn "$entry still names a Claude Code tool after substitution:"
    while IFS= read -r line; do
      echo "  $line" | cut -c1-160 >&2
    done <<< "$hits"
  done

  (( found == 0 ))
}

# Verifies the external tools the OpenCode install depends on.
require_opencode_tools() {
  command -v jq > /dev/null 2>&1 || { say_err "jq is required to update opencode.json without discarding existing settings. Install jq and re-run."; return 1; }
  command -v perl > /dev/null 2>&1 || { say_err "perl is required to rewrite tool names for OpenCode. Install perl and re-run."; return 1; }
}

# Returns the leading path OpenCode should use in opencode.json "instructions"
# globs for rules installed under base. OpenCode resolves a relative glob by
# searching up from the working directory to the project root, never against
# the config directory, so project scope needs a project-relative path and user
# scope needs one that does not depend on the working directory.
# Usage: opencode_instruction_prefix base   (prints the prefix, with trailing slash)
opencode_instruction_prefix() {
  local base="$1"

  if [[ "$(basename "$base")" == ".opencode" ]]; then
    printf '.opencode/\n'
  elif [[ "$base" == "$HOME"/* ]]; then
    printf '~/%s/\n' "${base#"$HOME"/}"
  else
    printf '%s/\n' "$base"
  fi
}

# Sets the elelem-owned entries of the "instructions" array in opencode.json.
# Entries that start with <owned_prefix>rules/ are replaced by the given globs;
# every other entry and every other key is preserved. Writes through the target
# path so a symlinked config keeps its symlink, and creates a minimal document
# when the target does not yet exist. Requires jq.
# Usage: write_opencode_instructions target owned_prefix [glob ...]
write_opencode_instructions() {
  local target="$1"
  local owned_prefix="$2"
  shift 2
  local globs=("$@")
  local schema="https://opencode.ai/config.json"
  local filter='.instructions = (((.instructions // []) | map(select((type == "string" and startswith($prefix + "rules/")) | not))) + $ARGS.positional)'

  local tmp
  tmp="$(mktemp)"
  if [[ -f "$target" ]]; then
    if ! jq --arg prefix "$owned_prefix" --args "$filter" \
      < "$target" -- "${globs[@]+"${globs[@]}"}" > "$tmp"; then
      rm -f "$tmp"
      say_err "could not parse '$target' as JSON; leaving it unchanged."
      return 1
    fi
  else
    jq -n --arg schema "$schema" --arg prefix "$owned_prefix" --args \
      "{\"\$schema\": \$schema} | $filter" \
      -- "${globs[@]+"${globs[@]}"}" > "$tmp"
  fi
  cat "$tmp" > "$target"
  rm -f "$tmp"
}

# Removes the elelem-owned entries from opencode.json's "instructions" array,
# and deletes the file when that leaves nothing but the minimal document this
# installer would have created. A missing file is not an error.
# Usage: remove_opencode_instructions target owned_prefix
remove_opencode_instructions() {
  local target="$1"
  local owned_prefix="$2"

  [[ -f "$target" ]] || return 0
  write_opencode_instructions "$target" "$owned_prefix" || return 1
  if jq -e '. == {"$schema": "https://opencode.ai/config.json", "instructions": []}' < "$target" > /dev/null 2>&1; then
    rm -f "$target"
  fi
}

# Writes an AGENTS.md index of the installed rule files, grouped by directory.
# Usage: write_agents_md target entries_ref
write_agents_md() {
  local target="$1"
  local entries_ref="$2"

  [[ "$entries_ref" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { echo "write_agents_md: invalid entries variable name: $entries_ref" >&2; return 1; }

  local _wam_entries
  eval "_wam_entries=(\"\${${entries_ref}[@]+\${${entries_ref}[@]}}\")"

  local rule_entries=()
  local entry
  for entry in "${_wam_entries[@]+"${_wam_entries[@]}"}"; do
    [[ "$entry" == rules/*/*.md ]] && rule_entries+=("$entry")
  done

  {
    printf '# Project rules\n\n'
    printf 'The following rule files apply to this project. Each entry links to the installed file relative to this AGENTS.md.\n\n'

    if (( ${#rule_entries[@]} == 0 )); then
      printf 'No rules are currently installed.\n'
      return 0
    fi

    local sorted
    sorted=$(printf '%s\n' "${rule_entries[@]}" | LC_ALL=C sort)

    local current_group=""
    local line group heading_initial heading_rest
    while IFS= read -r line; do
      group="${line#rules/}"
      group="${group%%/*}"
      if [[ "$group" != "$current_group" ]]; then
        current_group="$group"
        heading_initial="$(printf '%s' "${group:0:1}" | tr '[:lower:]' '[:upper:]')"
        heading_rest="${group:1}"
        printf '\n## %s%s\n\n' "$heading_initial" "$heading_rest"
      fi
      printf -- '- [%s](%s)\n' "$line" "$line"
    done <<< "$sorted"
  } > "$target"
}

# Runs the deterministic OpenCode install sequence for already-resolved
# selections. Same contract as run_claude_install, plus: tool names in the
# copied markdown are rewritten for OpenCode, the selected rule globs are
# merged into $base/opencode.json, and an AGENTS.md index is written unless an
# AGENTS.md that elelem did not create is already there.
#
# opencode.json is deliberately not recorded in the manifest: it holds user
# settings, so uninstall edits out only the entries this installer added
# rather than deleting the file.
#
# Usage: run_opencode_install base rules_target skills_target manifest_file manifest_ref common_selected_ref lang_selected_ref skills_selected_ref
run_opencode_install() {
  local base="$1"
  local rules_target="$2"
  local skills_target="$3"
  local manifest_file="$4"
  local manifest_ref="$5"
  local common_selected_ref="$6"
  local lang_selected_ref="$7"

  require_opencode_tools || exit 1

  _install_content "$rules_target" "$skills_target" "$manifest_ref" "$common_selected_ref" "$lang_selected_ref" "$8" opencode_transform_file

  local _roi_common _roi_lang
  eval "_roi_common=(\"\${${common_selected_ref}[@]+\${${common_selected_ref}[@]}}\")"
  eval "_roi_lang=(\"\${${lang_selected_ref}[@]+\${${lang_selected_ref}[@]}}\")"

  local prefix globs=() pick
  prefix="$(opencode_instruction_prefix "$base")"
  if (( ${#_roi_common[@]} > 0 )); then
    globs+=("${prefix}rules/common/*.md")
  fi
  for pick in "${_roi_lang[@]+"${_roi_lang[@]}"}"; do
    globs+=("${prefix}rules/$pick/*.md")
  done

  if write_opencode_instructions "$base/opencode.json" "$prefix" "${globs[@]+"${globs[@]}"}"; then
    say_ok "updated: $base/opencode.json"
  else
    say_warn "opencode.json was not updated; add these to its \"instructions\" yourself: ${globs[*]+"${globs[*]}"}"
  fi

  if [[ ! -e "$base/AGENTS.md" ]] || manifest_lists_entry "$manifest_file" "$base" "AGENTS.md"; then
    write_agents_md "$base/AGENTS.md" "$manifest_ref"
    eval "${manifest_ref}+=(\"AGENTS.md\")"
    say_ok "wrote: $base/AGENTS.md"
  else
    say_warn "$base/AGENTS.md already exists and was not written by elelem; leaving it alone."
  fi

  opencode_report_residue "$base" "$manifest_ref" || say_warn "some installed files still name Claude Code tools; the substitution table in install.sh needs updating."

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

  say_step "elelem installer"
  echo
  echo "Which harness do you want to install for?"
  harness_items=("Claude Code" "OpenCode")
  singleselect harness_choice harness_items 0

  case "$harness_choice" in
    "Claude Code")
      harness_user_base="$HOME/.claude"
      harness_project_suffix=".claude"
      manifest_file="$SCRIPT_DIR/.elelem-manifest-claude"
      ;;
    "OpenCode")
      require_opencode_tools || exit 1
      harness_user_base="$HOME/.config/opencode"
      harness_project_suffix=".opencode"
      manifest_file="$SCRIPT_DIR/.elelem-manifest-opencode"
      ;;
    *)
      say_err "unrecognised harness selection: $harness_choice"
      exit 1
      ;;
  esac

  echo
  resolve_install_base base "$harness_user_base" "$harness_project_suffix"

  rules_target="$base/rules"
  skills_target="$base/skills"
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
    if [[ "$harness_choice" == "OpenCode" ]]; then
      say_info "OpenCode loads selected language packs in every session (no path-based activation)."
    fi
    say_step "Language packs to install (none selected by default):"
    multiselect lang_selected lang_dirs lang_defaults
  else
    echo
    say_info "No language packs found in $RULES_SOURCE (common-only install)."
  fi

  skills_selected=()
  skill_basenames skill_names
  if (( ${#skill_names[@]} > 0 )); then
    skill_defaults=()
    for _ in "${skill_names[@]}"; do
      skill_defaults+=(1)
    done
    echo
    say_step "Skills to install (all selected by default):"
    multiselect skills_selected skill_names skill_defaults
  else
    echo
    say_info "No skills found in $SKILLS_SOURCE (skipping skills install)."
  fi

  if [[ "$harness_choice" == "OpenCode" ]]; then
    run_opencode_install "$base" "$rules_target" "$skills_target" "$manifest_file" manifest_entries common_selected lang_selected skills_selected
  else
    run_claude_install "$base" "$rules_target" "$skills_target" "$manifest_file" manifest_entries common_selected lang_selected skills_selected
  fi

  echo
  say_ok "Done."
  echo "Rules:  $rules_target"
  echo "Skills: $skills_target"
  if [[ "$harness_choice" == "OpenCode" ]]; then
    echo "Config: $base/opencode.json"
    echo
    say_warn "OpenCode also reads ~/.claude/ as a fallback. If you have installed elelem for Claude Code too, set OPENCODE_DISABLE_CLAUDE_CODE=1 in your shell so OpenCode does not load the Claude-named copies alongside these."
  else
    echo "Verify rules inside Claude Code with: /memory"
  fi
fi
