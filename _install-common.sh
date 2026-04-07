#!/usr/bin/env bash
#
# Shared helpers for elelem installers.
# Source this file from an installer script; do not execute it directly.
#
[[ "${BASH_SOURCE[0]}" != "${0}" ]] || { echo "_install-common.sh is a library; source it." >&2; exit 1; }

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
    echo "Select items (↑↓ to move, space to toggle, enter to confirm):"
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

# Prompts the user to select an install scope and resolves the base install path.
# Usage: resolve_install_base RESULT_VAR
#   RESULT_VAR - name of a global variable to populate with the resolved base path
resolve_install_base() {
  local result_var="$1"

  [[ "$result_var" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { echo "resolve_install_base: invalid result variable name: $result_var" >&2; return 1; }

  local scope_items scope_defaults scope_selected
  scope_items=("project  ->  <project>/.claude/" "user  ->  ~/.claude/")
  scope_defaults=(0 0)
  echo "Install scope:"
  multiselect scope_selected scope_items scope_defaults

  if (( ${#scope_selected[@]} == 0 )); then
    echo "No scope selected." >&2
    return 1
  fi
  if (( ${#scope_selected[@]} > 1 )); then
    echo "Please select only one scope." >&2
    return 1
  fi

  local scope=""
  if [[ "${scope_selected[0]}" == project* ]]; then
    scope=p
  elif [[ "${scope_selected[0]}" == user* ]]; then
    scope=u
  fi

  local resolved_base=""
  case "$scope" in
    p|P)
      local project_path
      read -rp "Project path [$(pwd)]: " project_path
      project_path="${project_path:-$(pwd)}"
      if [[ ! -d "$project_path" ]]; then
        echo "Error: $project_path does not exist" >&2
        return 1
      fi
      resolved_base="$project_path/.claude"
      ;;
    u|U)
      resolved_base="$HOME/.claude"
      echo "Installing to $HOME/.claude/"
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
# Builds a perl -i -pe expression dynamically from the arrays. Compatible with bash 3.2+.
#
# NOTE: substitution strings are interpolated directly into a perl s/.../.../g
# expression. Callers MUST NOT pass substitutions containing '/', '\', '$', or
# '@'. Escape or switch to a different delimiter strategy before passing such
# values. The current Claude Code placeholder map (defined in install.sh) is
# verified safe; a future opencode map must be verified before use.
substitute_tool_names() {
  local dir="$1"
  local placeholders_ref="$2"
  local substitutions_ref="$3"

  [[ -d "$dir" ]] || return 0
  [[ "$placeholders_ref"  =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { echo "substitute_tool_names: invalid placeholders variable name: $placeholders_ref"  >&2; return 1; }
  [[ "$substitutions_ref" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { echo "substitute_tool_names: invalid substitutions variable name: $substitutions_ref" >&2; return 1; }

  local placeholders substitutions
  eval "placeholders=(\"\${${placeholders_ref}[@]}\")"
  eval "substitutions=(\"\${${substitutions_ref}[@]}\")"

  local count="${#placeholders[@]}"
  if (( count == 0 )); then
    return 0
  fi

  local perl_expr=""
  local i
  for (( i=0; i<count; i++ )); do
    local placeholder="${placeholders[$i]}"
    local substitution="${substitutions[$i]}"
    perl_expr="${perl_expr}s/\\{\\{${placeholder}\\}\\}/${substitution}/g; "
  done

  find "$dir" -type f -name '*.md' -exec perl -i -pe "$perl_expr" {} +
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

# Validates that one or more glob patterns each match at least one file.
# Aborts with a clear error message on stderr if any pattern matches nothing.
# Usage: validate_globs_resolve pattern [pattern ...]
validate_globs_resolve() {
  local pattern
  for pattern in "$@"; do
    if ! compgen -G "$pattern" > /dev/null 2>&1; then
      echo "Error: glob pattern '$pattern' matched no files." >&2
      exit 1
    fi
  done
}
