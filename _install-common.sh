#!/usr/bin/env bash
#
# Shared helpers for elelem installers.
# Source this file from an installer script; do not execute it directly.
#
[[ "${BASH_SOURCE[0]}" != "${0}" ]] || { echo "_install-common.sh is a library; source it." >&2; exit 1; }

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

# Prompts the user to select an install scope and resolves the base install path.
# Usage: resolve_install_base RESULT_VAR USER_BASE PROJECT_SUFFIX
#   RESULT_VAR      - name of a global variable to populate with the resolved base path
#   USER_BASE       - user-scope base path (e.g. $HOME/.claude or $HOME/.config/opencode)
#   PROJECT_SUFFIX  - project-scope directory name (e.g. .claude or .opencode)
resolve_install_base() {
  local result_var="$1"
  local user_base="$2"
  local project_suffix="$3"

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

# Substitutes tool-name placeholders in every .md file under the given directory.
# Usage: substitute_tool_names dir placeholders_ref substitutions_ref
#   dir               - directory to operate on (recursively, all *.md files)
#   placeholders_ref  - name of an array variable containing placeholder tokens (without braces)
#   substitutions_ref - name of an array variable containing replacement strings (parallel to placeholders)
#
substitute_tool_names() {
  local dir="$1" placeholders_ref="$2" substitutions_ref="$3"
  [[ -d "$dir" ]] || return 0
  [[ "$placeholders_ref"  =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { echo "substitute_tool_names: invalid placeholders variable name: $placeholders_ref"  >&2; return 1; }
  [[ "$substitutions_ref" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { echo "substitute_tool_names: invalid substitutions variable name: $substitutions_ref" >&2; return 1; }
  local _stn_placeholders _stn_substitutions i
  eval "_stn_placeholders=(\"\${${placeholders_ref}[@]+\${${placeholders_ref}[@]}}\")"
  eval "_stn_substitutions=(\"\${${substitutions_ref}[@]+\${${substitutions_ref}[@]}}\")"
  [[ ${#_stn_placeholders[@]} == ${#_stn_substitutions[@]} ]] || { say_err 'tool placeholder and substitution counts differ.'; return 1; }
  for (( i=0; i<${#_stn_placeholders[@]}; i++ )); do
    ELELEM_PLACEHOLDER="{{${_stn_placeholders[$i]}}}" ELELEM_SUBSTITUTION="${_stn_substitutions[$i]}" \
      find "$dir" -type f -name '*.md' -exec perl -i -pe 's/\Q$ENV{ELELEM_PLACEHOLDER}\E/$ENV{ELELEM_SUBSTITUTION}/g' {} + || return 1
  done
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
  local preserve_prefix="${4:-}"

  assert_manifest_base_matches "$manifest_file" "$base" || return 1
  [[ -f "$manifest_file" ]] || return 0
  [[ "$new_entries_ref" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { echo "prune_stale_manifest_entries: invalid new_entries variable name: $new_entries_ref" >&2; return 1; }

  local new_entries
  eval "new_entries=(\"\${${new_entries_ref}[@]+\${${new_entries_ref}[@]}}\")"

  local removed=0
  local first_line=1
  while IFS= read -r line; do
    if (( first_line )); then
      first_line=0
      continue
    fi
    [[ -z "$line" ]] && continue
    [[ "$line" == opencode.json ]] && continue
    if [[ -n "$preserve_prefix" ]] && {
      [[ "$line" == "$preserve_prefix.LICENSE" ]] ||
        [[ "${line#"$preserve_prefix/"}" != "$line" ]]
    }; then
      local preserved=0
      local existing_entry
      for existing_entry in "${new_entries[@]+"${new_entries[@]}"}"; do
        if [[ "$existing_entry" == "$line" ]]; then
          preserved=1
          break
        fi
      done
      if (( preserved == 0 )); then
        new_entries+=("$line")
      fi
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
      rm "$base/$line" || return 1
      echo "  removed stale: $line"
      (( removed++ )) || true
    fi
  done < "$manifest_file"

  if [[ -n "$preserve_prefix" ]]; then
    eval "${new_entries_ref}=(\"\${new_entries[@]+\${new_entries[@]}}\")"
  fi

  if (( removed > 0 )); then
    local rules_dir="$base/rules"
    local skills_dir="$base/skills"
    find "$rules_dir" "$skills_dir" -type d -empty -delete 2>/dev/null || true
  fi
}

assert_manifest_base_matches() {
  local manifest_file="$1"
  local base="$2"

  [[ -f "$manifest_file" ]] || return 0

  local manifest_base=""
  IFS= read -r manifest_base < "$manifest_file" || true
  if [[ "$manifest_base" != "$base" ]]; then
    say_err "manifest '$manifest_file' records base '$manifest_base', not '$base'; refusing to change install scope."
    return 1
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
  assert_manifest_base_matches "$manifest_file" "$base" || return 1

  local entries
  eval "entries=(\"\${${entries_ref}[@]+\${${entries_ref}[@]}}\")"

  local staged_manifest staged_entries
  staged_manifest="$(mktemp "${manifest_file}.tmp.XXXXXX")" || return 1
  staged_entries="$(mktemp "${manifest_file}.entries.XXXXXX")" || { rm -f "$staged_manifest"; return 1; }

  if ! printf '%s\n' "${entries[@]+"${entries[@]}"}" > "$staged_entries" ||
    ! printf '%s\n' "$base" > "$staged_manifest" ||
    ! sort "$staged_entries" >> "$staged_manifest"; then
    rm -f "$staged_manifest" "$staged_entries"
    return 1
  fi

  rm -f "$staged_entries" || { rm -f "$staged_manifest"; return 1; }
  mv -f "$staged_manifest" "$manifest_file" || { local status=$?; rm -f "$staged_manifest"; return "$status"; }
}

# Default destination resolver used by install_files_from_dir.
# Usage: _default_resolve_dst src output_root
#   src         - absolute path to the source file
#   output_root - absolute path to the destination root directory
# Prints output_root/basename(src) to stdout.
_default_resolve_dst() {
  local src="$1"
  local output_root="$2"
  printf '%s/%s\n' "$output_root" "$(basename "$src")"
}

# Default file transform used by install_files_from_dir.
# Usage: _default_transform src dst
#   src - absolute path to the source file
#   dst - absolute path to the destination file
# Copies src to dst. Returns 0 on success, non-zero on failure.
# MUST NOT call exit; the install_files_from_dir loop owns the abort path.
_default_transform() {
  local src="$1"
  local dst="$2"
  cp "$src" "$dst"
}

# Checks that no two destination paths are identical, preventing silent overwrites
# when multiple source files resolve to the same full output path.
# Usage: check_no_collisions srcs_ref dsts_ref
#   srcs_ref - name of an array variable containing absolute source paths
#   dsts_ref - name of an array variable containing corresponding destination paths
# Returns 0 if no collisions are found. Writes to stderr and returns 1 on collision.
check_no_collisions() {
  local srcs_ref="$1"
  local dsts_ref="$2"

  [[ "$srcs_ref" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { echo "check_no_collisions: invalid srcs variable name: $srcs_ref" >&2; return 1; }
  [[ "$dsts_ref" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { echo "check_no_collisions: invalid dsts variable name: $dsts_ref" >&2; return 1; }

  local _cnc_srcs _cnc_dsts
  eval "_cnc_srcs=(\"\${${srcs_ref}[@]+\${${srcs_ref}[@]}}\")"
  eval "_cnc_dsts=(\"\${${dsts_ref}[@]+\${${dsts_ref}[@]}}\")"

  local count="${#_cnc_dsts[@]}"
  local i j
  for (( i=0; i<count; i++ )); do
    for (( j=i+1; j<count; j++ )); do
      if [[ "${_cnc_dsts[$i]}" == "${_cnc_dsts[$j]}" ]]; then
        say_err "check_no_collisions: '${_cnc_srcs[$i]}' and '${_cnc_srcs[$j]}' both resolve to '${_cnc_dsts[$i]}'."
        return 1
      fi
    done
  done
}

# Copies a list of source files into an output directory, optionally transforming
# them, and appends manifest entries for each installed file.
# Usage: install_files_from_dir source_dir output_dir manifest_prefix manifest_ref files_ref [resolve_dst_fn] [transform_fn]
#   source_dir      - absolute path to the source directory
#   output_dir      - absolute path to the destination directory
#   manifest_prefix - relative prefix prepended to each manifest entry (no trailing slash)
#   manifest_ref    - name of a caller array variable; new entries are appended
#   files_ref       - name of an array variable of source paths relative to source_dir
#   resolve_dst_fn  - (optional) function(src, output_dir) -> dst path; default: _default_resolve_dst
#   transform_fn    - (optional) function(src, dst) -> 0|non-zero; default: _default_transform
#                     MUST NOT call exit; this function owns the abort path on transform failure.
install_files_from_dir() {
  local source_dir="$1"
  local output_dir="$2"
  local manifest_prefix="$3"
  local manifest_ref="$4"
  local files_ref="$5"
  local resolve_dst_fn="${6:-_default_resolve_dst}"
  local transform_fn="${7:-_default_transform}"

  [[ "$manifest_ref"  =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { echo "install_files_from_dir: invalid manifest_ref variable name: $manifest_ref"  >&2; exit 1; }
  [[ "$files_ref"     =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { echo "install_files_from_dir: invalid files_ref variable name: $files_ref"         >&2; exit 1; }
  [[ "$resolve_dst_fn" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { echo "install_files_from_dir: invalid resolve_dst_fn name: $resolve_dst_fn"        >&2; exit 1; }
  [[ "$transform_fn"  =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { echo "install_files_from_dir: invalid transform_fn name: $transform_fn"             >&2; exit 1; }

  declare -f "$resolve_dst_fn" >/dev/null 2>&1 || { say_err "install_files_from_dir: '$resolve_dst_fn' is not a defined function"; exit 1; }
  declare -f "$transform_fn"   >/dev/null 2>&1 || { say_err "install_files_from_dir: '$transform_fn' is not a defined function";   exit 1; }

  local _ifd_files
  eval "_ifd_files=(\"\${${files_ref}[@]+\${${files_ref}[@]}}\")"

  local _ifd_planned_srcs=()
  local _ifd_planned_dsts=()
  local rel src dst
  for rel in "${_ifd_files[@]+"${_ifd_files[@]}"}"; do
    src="$source_dir/$rel"
    dst="$("$resolve_dst_fn" "$src" "$output_dir")"
    if [[ "${dst#$output_dir/}" == "$dst" ]]; then
      say_err "install_files_from_dir: resolve_dst returned '$dst' which is not under output_dir '$output_dir'."
      exit 1
    fi
    _ifd_planned_srcs+=("$src")
    _ifd_planned_dsts+=("$dst")
  done

  check_no_collisions _ifd_planned_srcs _ifd_planned_dsts || exit 1

  local i entry dst_rel
  for (( i=0; i<${#_ifd_planned_srcs[@]}; i++ )); do
    mkdir -p "$(dirname "${_ifd_planned_dsts[$i]}")"
    "$transform_fn" "${_ifd_planned_srcs[$i]}" "${_ifd_planned_dsts[$i]}" || { say_err "install_files_from_dir: transform failed for: ${_ifd_planned_srcs[$i]}"; exit 1; }
    dst_rel="${_ifd_planned_dsts[$i]#$output_dir/}"
    entry="${manifest_prefix}/${dst_rel}"
    eval "${manifest_ref}+=(\"\$entry\")"
  done
}

report_agent_bundle_changes() {
  local changed_paths_ref="$1"
  local reported_paths path
  eval "reported_paths=(\"\${${changed_paths_ref}[@]+\${${changed_paths_ref}[@]}}\")"
  printf 'Changed paths:\n'
  for path in "${reported_paths[@]+"${reported_paths[@]}"}"; do
    printf '  %s\n' "$path"
  done
}

copy_and_record_agent_bundle_file() {
  local source_file="$1"
  local destination="$2"
  local manifest_entry="$3"
  local manifest_ref="$4"
  local changed_paths_ref="$5"

  if ! cp "$source_file" "$destination"; then
    say_err "failed to copy agent to '$destination'; it may be partially written."
    report_agent_bundle_changes "$changed_paths_ref"
    return 1
  fi
  eval "${manifest_ref}+=(\"\$manifest_entry\")"
  eval "${changed_paths_ref}+=(\"\$destination\")"
}

install_agent_bundle_files() {
  local source_dir="$1"
  local output_dir="$2"
  local manifest_prefix="$3"
  local manifest_ref="$4"
  local files_ref="$5"
  local changed_paths_ref="$6"

  [[ "$manifest_ref" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { echo "install_agent_bundle_files: invalid manifest_ref variable name: $manifest_ref" >&2; return 1; }
  [[ "$files_ref" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { echo "install_agent_bundle_files: invalid files_ref variable name: $files_ref" >&2; return 1; }
  [[ "$changed_paths_ref" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { echo "install_agent_bundle_files: invalid changed_paths_ref variable name: $changed_paths_ref" >&2; return 1; }

  local files
  eval "files=(\"\${${files_ref}[@]+\${${files_ref}[@]}}\")"

  if ! mkdir -p "$output_dir"; then
    say_err "failed to create agent output directory '$output_dir'."
    report_agent_bundle_changes "$changed_paths_ref"
    return 1
  fi

  local file destination entry response
  for file in "${files[@]+"${files[@]}"}"; do
    destination="$output_dir/$file"
    if [[ -d "$destination" ]]; then
      say_err "cannot install agent at '$destination'; move or remove the directory, then rerun the installer."
      report_agent_bundle_changes "$changed_paths_ref"
      return 1
    fi
    if [[ -e "$destination" || -L "$destination" ]]; then
      printf "Replace existing agent '${destination##*/}'? [y/n] " >&2
      if ! IFS= read -r response; then
        response=""
      fi
      if [[ "$response" != "y" && "$response" != "Y" ]]; then
        continue
      fi
      if [[ -L "$destination" ]] && ! rm -f "$destination"; then
        say_err "failed to remove existing agent symlink '$destination'."
        report_agent_bundle_changes "$changed_paths_ref"
        return 1
      fi
    fi
    entry="$manifest_prefix/$file"
    copy_and_record_agent_bundle_file "$source_dir/$file" "$destination" "$entry" "$manifest_ref" "$changed_paths_ref" || return 1
  done
}

install_agent_bundle_notice() {
  local source_file="$1"
  local destination_file="$2"
  local manifest_entry="$3"
  local manifest_ref="$4"
  local changed_paths_ref="$5"

  [[ "$manifest_ref" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { echo "install_agent_bundle_notice: invalid manifest_ref variable name: $manifest_ref" >&2; return 1; }
  [[ "$changed_paths_ref" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { echo "install_agent_bundle_notice: invalid changed_paths_ref variable name: $changed_paths_ref" >&2; return 1; }

  if [[ -d "$destination_file" ]]; then
    say_err "cannot install notice at '$destination_file'; move or remove the directory, then rerun the installer."
    report_agent_bundle_changes "$changed_paths_ref"
    return 1
  fi

  if [[ -e "$destination_file" || -L "$destination_file" ]]; then
    local response
    if ! IFS= read -r -p "Replace existing notice '${destination_file##*/}'? [y/n] " response; then
      response=""
    fi
    if [[ "$response" != "y" && "$response" != "Y" ]]; then
      if [[ "$response" != "Y" ]] && cmp -s "$source_file" "$destination_file"; then
        return 0
      fi
      say_err "cannot replace '$destination_file'; move or remove it, then rerun the installer."
      return 1
    fi
  fi

  mkdir -p "$(dirname "$destination_file")" || return 1

  local staged_file
  staged_file="$(mktemp "${destination_file}.tmp.XXXXXX")" || return 1
  if ! cp "$source_file" "$staged_file"; then
    rm -f "$staged_file"
    say_err "failed to stage notice at '$staged_file' for destination '$destination_file'."
    return 1
  fi

  if ! cmp -s "$source_file" "$staged_file"; then
    rm -f "$staged_file"
    say_err "verification comparison failed for 'agents.LICENSE' at staged path '$staged_file'."
    return 1
  fi

  if ! mv -f "$staged_file" "$destination_file"; then
    rm -f "$staged_file"
    say_err "failed to rename/move staged notice '$staged_file' to agents.LICENSE destination '$destination_file'."
    return 1
  fi

  eval "${manifest_ref}+=(\"\$manifest_entry\")"
  eval "${changed_paths_ref}+=(\"\$destination_file\")"
}

# Scans AGENTS.md files and skill files under root_dir for unsubstituted placeholders
# (literal '{{') and TODO markers. Exits 1 with a diagnostic message if any are found.
# Returns 0 if root_dir does not exist or contains no matching files.
# Usage: scan_no_unsubstituted_placeholders root_dir
scan_no_unsubstituted_placeholders() {
  local root_dir="$1"

  [[ -d "$root_dir" ]] || return 0

  local file found_any=0 hits
  while IFS= read -r -d '' file; do
    hits="$(grep -n -F -e '{{' -e 'TODO:' "$file" 2>/dev/null)" || true
    if [[ -n "$hits" ]]; then
      say_err "scan_no_unsubstituted_placeholders: '$file' contains unsubstituted placeholder or TODO marker:"
      while IFS= read -r hit_line; do
        echo "  $hit_line" >&2
      done <<< "$hits"
      found_any=1
    fi
  done < <(find "$root_dir" \( -name 'AGENTS.md' -o -name 'SKILL.md' \) -type f -print0)

  if (( found_any )); then
    exit 1
  fi
}

# Validates that one or more glob patterns each match at least one file.
# Aborts with a clear error message on stderr if any pattern matches nothing.
# Usage: validate_globs_resolve pattern [pattern ...]
validate_globs_resolve() {
  local pattern
  for pattern in "$@"; do
    if ! compgen -G "$pattern" > /dev/null 2>&1; then
      say_err "glob pattern '$pattern' matched no files."
      exit 1
    fi
  done
}

# Sets the "instructions" array in opencode.json to the given globs, preserving
# every other key in an existing file. Writes through the target path so that a
# symlinked config keeps its symlink. Creates a minimal document when the target
# does not yet exist. Requires jq.
# Usage: write_opencode_instructions target [glob ...]
write_opencode_instructions() {
  local target="$1"
  shift
  local globs=("$@")
  local schema="https://opencode.ai/config.json"

  local tmp
  tmp="$(mktemp)"
  trap 'rm -f "$tmp"' RETURN
  if [[ -f "$target" ]]; then
    if ! jq --args '.instructions = $ARGS.positional' \
      < "$target" -- "${globs[@]+"${globs[@]}"}" > "$tmp"; then
      say_err "could not parse '$target' as JSON; leaving it unchanged."
      return 1
    fi
  else
    jq -n --arg schema "$schema" --args \
      '{"$schema": $schema, "instructions": $ARGS.positional}' \
      -- "${globs[@]+"${globs[@]}"}" > "$tmp"
  fi
  cat "$tmp" > "$target"
}

render_language_pack_policy() {
  cat <<'EOF'
# On-demand language packs

Before substantive reading, creating, editing or reviewing current-task files, invoke each applicable `elelem-language-<language>` skill with `{{INVOKE_SKILL_TOOL}}`. Reassess as scope grows; mixed-language tasks may need multiple packs. Load only applicable coding, test and tooling references as instructed by the skill. Source filename globs are matching guidance, not automatic activation.

Use actual task files and context, not a repository language inventory or incidental Markdown mentions. Shared JavaScript/TypeScript tooling needs task context; ask when materially ambiguous. A missing required skill or reference must visibly block affected work. Include applicable skill requirements in delegated task briefs without bulk preloading language bodies.
EOF
}

_language_pack_safe_parents() {
  local path="$1"
  while [[ -n "$path" && "$path" != / && "$path" != . ]]; do
    if [[ -L "$path" || ( -e "$path" && ! -d "$path" ) ]]; then
      say_err "language pack destination '$path' is not a regular directory; move or remove it, then rerun."
      return 1
    fi
    [[ "$path" == */* ]] || break
    path="${path%/*}"
  done
}

_language_pack_owned_path() {
  [[ -f "$1" ]] && tail -n +2 "$1" | grep -Fxq -- "$2"
}

_language_pack_check_existing() {
  local destination="$1" relative="$2" previous="$3" path entry
  [[ -e "$destination" || -L "$destination" ]] || return 0
  if [[ -L "$destination" || ! -d "$destination" ]] || ! _language_pack_owned_path "$previous" "$relative/SKILL.md"; then
    say_err "unmanaged language pack collision at '$destination'; move or remove it, then rerun."
    return 1
  fi
  while IFS= read -r -d '' path; do
    entry="$relative/${path#"$destination/"}"
    if [[ ! -L "$path" && -d "$path" && "$path" == "$destination/references" ]]; then continue; fi
    if [[ -L "$path" || ! -f "$path" ]] || ! _language_pack_owned_path "$previous" "$entry"; then
      say_err "unmanaged language pack collision at '$path'; move or remove it, then rerun."
      return 1
    fi
  done < <(find "$destination" -mindepth 1 -print0)
}

_language_pack_preflight() {
  local source="$1" target="$2" prefix="$3" previous="$4" directory language
  _language_pack_safe_parents "$target" || return 1
  if [[ -f "$previous" ]]; then
    [[ "$target" == */"$prefix" ]] || { say_err 'language pack manifest prefix does not match destination.'; return 1; }
    assert_manifest_base_matches "$previous" "${target%/"$prefix"}" || return 1
  fi
  for directory in "$source"/*; do
    [[ -d "$directory" && "${directory##*/}" != common ]] || continue
    language="${directory##*/}"
    [[ "$language" =~ ^[a-z0-9][a-z0-9_-]*$ ]] || { say_err "invalid language pack name '$language'."; return 1; }
    _language_pack_check_existing "$target/elelem-language-$language" "$prefix/elelem-language-$language" "$previous" || return 1
  done
}

_render_language_pack_reference() {
  local topic="${1%.md}" triggers="$2"
  case "$topic" in
    coding-style) printf 'Use `{{READ_FILE_TOOL}}` to read `references/%s.md` relative to this skill base for substantive work on applicable language files.\n' "$topic" ;;
    testing) printf 'Use `{{READ_FILE_TOOL}}` to read `references/%s.md` relative to this skill base only when actual task work involves tests or test configuration. Filename guidance: %s.\n' "$topic" "$triggers" ;;
    tooling) printf 'Use `{{READ_FILE_TOOL}}` to read `references/%s.md` relative to this skill base only when actual task work involves applicable tooling, manifests, dependencies or build configuration. Filename guidance: %s.\n' "$topic" "$triggers" ;;
    *) printf 'Use `{{READ_FILE_TOOL}}` to read `references/%s.md` relative to this skill base when this topic applies to actual task work. Filename guidance: %s.\n' "$topic" "$triggers" ;;
  esac
}

_render_language_pack_wrapper() {
  local directory="$1" language="${1##*/}" file triggers
  triggers="$(sed -n 's/^globs: *//p' "$directory"/*.md | tr '\n' ' ')"
  printf '%s\n' '---' "name: elelem-language-$language"
  printf 'description: "Apply %s rules before substantive reading, creating, editing or reviewing current-task %s files. Filename guidance: %s"\n' "$language" "$language" "$triggers"
  printf '%s\n\n' '---'
  printf '# %s language pack\n\n' "$language"
  printf '%s\n\n' 'Read only references applicable to actual task files, not a repository language inventory or incidental Markdown mentions. These globs are guidance, not automatic activation. Reassess as scope grows. For shared JavaScript/TypeScript tooling, use task context and ask when materially ambiguous. A missing required reference blocks affected work.'
  for file in "$directory"/*.md; do
    [[ -f "$file" ]] || continue
    triggers="$(sed -n 's/^globs: *//p' "$file")"
    _render_language_pack_reference "${file##*/}" "${triggers:-task context}"
  done
}

_stage_language_packs() {
  local source="$1" stage="$2" directory file destination
  for directory in "$source"/*; do
    [[ -d "$directory" && "${directory##*/}" != common ]] || continue
    destination="$stage/elelem-language-${directory##*/}"
    mkdir -p "$destination/references" || return 1
    _render_language_pack_wrapper "$directory" > "$destination/SKILL.md" || return 1
    for file in "$directory"/*.md; do
      [[ -f "$file" ]] || continue
      cp "$file" "$destination/references/${file##*/}" || return 1
    done
  done
}

_validate_language_pack_markdown() {
  local directory="$1" file
  while IFS= read -r -d '' file; do
    if grep -Fq '{{' "$file"; then
      say_err "unexpanded placeholder in language pack '$file'; correct the tool substitutions, then rerun."
      return 1
    fi
  done < <(find "$directory" -type f -name '*.md' -print0)
}

_publish_language_packs() {
  local stage="$1" target="$2" prefix="$3" manifest_ref="$4" file relative _lp_entry
  while IFS= read -r -d '' file; do
    relative="${file#"$stage/"}"
    mkdir -p "$(dirname "$target/$relative")" || return 1
    cp "$file" "$target/$relative" || return 1
    _lp_entry="$prefix/$relative"
    eval "${manifest_ref}+=(\"\$_lp_entry\")"
  done < <(find "$stage" -type f -name '*.md' -print0)
}

install_language_packs() {
  local source="$1" target="$2" prefix="$3" previous="$4" manifest_ref="$5" placeholders_ref="$6" substitutions_ref="$7" stage status=0
  [[ "$manifest_ref" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { say_err 'invalid language pack manifest array name.'; return 1; }
  [[ -d "$source" && -n "$prefix" && "$prefix" != /* && "$prefix" != *..* ]] || { say_err 'invalid language pack source or manifest prefix.'; return 1; }
  _language_pack_preflight "$source" "$target" "$prefix" "$previous" || return 1
  stage="$(mktemp -d "${TMPDIR:-/tmp}/elelem-language-packs.XXXXXX")" || return 1
  if _stage_language_packs "$source" "$stage" &&
    substitute_tool_names "$stage" "$placeholders_ref" "$substitutions_ref" &&
    _validate_language_pack_markdown "$stage"; then
    _publish_language_packs "$stage" "$target" "$prefix" "$manifest_ref" || status=$?
  else
    status=1
  fi
  rm -rf "$stage"
  return "$status"
}

_opencode_validate_json() {
  local file="$1" require_instructions="$2"
  jq -es --arg required "$require_instructions" '
    length == 1 and (.[0] | type == "object" and
      (if has("instructions") then
        (.instructions | type == "array" and all(.[]; type == "string"))
      else $required != "yes" end))
  ' "$file" > /dev/null 2>&1 || {
    say_err "invalid JSON object or instruction ownership in '$file'; leaving config and retry metadata unchanged."
    return 1
  }
}

_opencode_legacy_owned_entries() {
  local previous="$1" ownership="$2" line legacy_config=0 entries=()
  if [[ -f "$previous" ]]; then
    while IFS= read -r line; do
      [[ "$line" != "${ownership##*/}" ]] || { say_err "missing ownership file '$ownership'; restore it before retrying."; return 1; }
      [[ "$line" != opencode.json ]] || legacy_config=1
      if [[ "$line" =~ ^rules/([a-zA-Z0-9_-]+)/[^/]+\.md$ ]]; then
        entries+=("rules/${BASH_REMATCH[1]}/*.md")
      elif [[ "$line" =~ ^rules/[a-zA-Z0-9_-]+\.md$ ]]; then
        entries+=("$line")
      fi
    done < <(tail -n +2 "$previous")
  fi
  if (( legacy_config && ${#entries[@]} == 0 )); then
    say_err 'legacy opencode.json has no identifiable rule ownership; retain the manifest and resolve ownership before retrying.'
    return 1
  fi
  jq -cn --args '$ARGS.positional | unique' -- "${entries[@]+"${entries[@]}"}"
}

_opencode_owned_entries() {
  local previous="$1" ownership="$2" manifest_base=""
  if [[ -e "$ownership" || -L "$ownership" ]]; then
    if [[ ! -f "$previous" ]] || ! IFS= read -r manifest_base < "$previous" ||
      [[ "${ownership%/*}" != "$manifest_base" ]] ||
      ! tail -n +2 "$previous" | grep -Fx -- "${ownership##*/}" > /dev/null; then
      say_err "unmanaged ownership file '$ownership'; restore its prior manifest ownership before retrying. Config and metadata are unchanged."
      return 1
    fi
    [[ -f "$ownership" && ! -L "$ownership" ]] || { say_err "ownership collision at '$ownership'; restore the regular ownership file before retrying."; return 1; }
    _opencode_validate_json "$ownership" yes || return 1
    jq -c '.instructions' "$ownership"
  else
    _opencode_legacy_owned_entries "$previous" "$ownership"
  fi
}

_opencode_config_document() {
  local target="$1"
  if [[ -e "$target" || -L "$target" ]]; then
    [[ -f "$target" ]] || { say_err "config '$target' is not a regular file; resolve it before retrying."; return 1; }
    _opencode_validate_json "$target" no || return 1
    cat "$target"
  else
    printf '%s\n' '{"$schema":"https://opencode.ai/config.json"}'
  fi
}

_opencode_warn_unowned_instructions() {
  local document="$1" owned="$2" entry
  while IFS= read -r entry; do
    [[ -n "$entry" ]] || continue
    say_warn "unowned instruction '$entry' may eagerly include language rules; preserving it. Review it manually if deferred loading is required."
  done < <(printf '%s\n' "$document" | jq -r --argjson owned "$owned" '
    (.instructions // [])[] |
    select(. as $entry | $owned | index($entry) | not) |
    select(test("(^|/)rules/|\\*.*\\.md"))
  ')
}

_opencode_render_owned_update() {
  local document="$1" owned="$2" requested="$3"
  printf '%s\n' "$document" | jq --argjson owned "$owned" --argjson requested "$requested" '
    ((.instructions // []) | map(. as $entry | select($owned | index($entry) | not))) as $kept |
    if any($requested[]; . as $entry | $kept | index($entry)) then
      error("unmanaged instruction collision; remove the requested entry manually or restore its ownership metadata")
    else .instructions = ($kept + $requested) end
  '
}

_opencode_destination_writable() {
  local destination="$1"
  if [[ -e "$destination" ]]; then
    [[ -f "$destination" && -w "$destination" ]] || { say_err "cannot write '$destination'; check its type and permissions before retrying."; return 1; }
  else
    [[ -d "$(dirname "$destination")" && -w "$(dirname "$destination")" ]] || { say_err "cannot create '$destination'; create a writable parent directory before retrying."; return 1; }
  fi
}

_opencode_apply_owned_update() {
  local target="$1" ownership="$2" mode="$3" document="$4" owned="$5" requested="$6" stage status=0
  _opencode_destination_writable "$target" || return 1
  [[ "$mode" != update ]] || _opencode_destination_writable "$ownership" || return 1
  stage="$(mktemp -d "${TMPDIR:-/tmp}/elelem-opencode-instructions.XXXXXX")" || return 1
  if _opencode_render_owned_update "$document" "$owned" "$requested" > "$stage/config.json" &&
    jq -n --argjson entries "$requested" '{instructions: $entries}' > "$stage/ownership.json"; then
    cat "$stage/config.json" > "$target" || status=1
    if [[ "$mode" == update && "$status" == 0 ]]; then
      cat "$stage/ownership.json" > "$ownership" || status=1
    fi
  else
    status=1
  fi
  rm -rf "$stage"
  (( status == 0 )) || say_err 'instruction update failed; retain the manifest and ownership metadata for retry.'
  return "$status"
}

_edit_opencode_owned_instructions() {
  local target="$1" previous="$2" ownership="$3" mode="$4" owned document requested
  shift 4
  command -v jq > /dev/null 2>&1 || { say_err 'jq is required for safe instruction ownership updates; install jq and retry without deleting ownership metadata.'; return 1; }
  [[ "$target" != "$ownership" ]] || { say_err 'config and ownership paths must differ.'; return 1; }
  assert_manifest_base_matches "$previous" "$(dirname "$target")" || return 1
  owned="$(_opencode_owned_entries "$previous" "$ownership")" || return 1
  document="$(_opencode_config_document "$target")" || return 1
  requested="$(jq -cn --args '$ARGS.positional' -- "$@")" || return 1
  _opencode_warn_unowned_instructions "$document" "$owned"
  [[ "$mode" != remove || -e "$target" ]] || return 0
  _opencode_apply_owned_update "$target" "$ownership" "$mode" "$document" "$owned" "$requested"
}

update_opencode_instructions() {
  local target="$1" previous="$2" ownership="$3"
  shift 3
  _edit_opencode_owned_instructions "$target" "$previous" "$ownership" update "$@"
}

remove_opencode_instructions() {
  _edit_opencode_owned_instructions "$1" "$2" "$3" remove
}
