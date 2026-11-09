#!/usr/bin/env bash
#
# Installs elelem rules and skills for Codex.
#
# Rules are assembled into a managed elelem block inside:
#   - ~/.codex/AGENTS.md (user scope), or
#   - <project>/AGENTS.md (project scope)
#
# Skills install to:
#   - ~/.agents/skills/ (user scope), or
#   - <project>/.agents/skills/ (project scope)
#
# A manifest file (.elelem-manifest-codex) in this repo tracks installed skill
# files for prune-on-reinstall. The AGENTS.md file is updated in place via a
# managed block so user-authored content outside the block is preserved.
#
# Tool-name placeholders of the form {{TOOL_NAME}} in rules and skills are
# substituted with Codex-oriented commands or capability labels during install.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RULES_SOURCE="$SCRIPT_DIR/rules"
SKILLS_SOURCE="$SCRIPT_DIR/skills"

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_install-common.sh"

CODEX_PLACEHOLDERS=(
  'ASK_USER_QUESTION_TOOL'
  'ENTER_PLAN_TOOL'
  'EXIT_PLAN_TOOL'
  'TASK_TRACKER_TOOL'
  'DISPATCH_AGENT_TOOL'
  'INVOKE_SKILL_TOOL'
  'READ_FILE_TOOL'
  'WRITE_FILE_TOOL'
  'EDIT_FILE_TOOL'
  'GREP_TOOL'
  'GLOB_TOOL'
  'SHELL_EXEC_TOOL'
  'MODEL_ENUMERATION'
)

CODEX_SUBSTITUTIONS=(
  'request_user_input'
  'STOP and ask the user to switch to Plan mode, do not continue until in Plan mode'
  'ask the user to approve the plan and then leave plan mode'
  'update_plan task list'
  'spawn_agent'
  '/skills or $skill-name'
  'read the file'
  'write or create the file'
  'apply_patch'
  'exec_command with rg'
  'exec_command with rg --files or find'
  'exec_command'
  'running `codex debug models` with exec_command, which prints the raw model catalogue'
)

CODEX_MANAGED_START='<!-- elelem:codex:start -->'
CODEX_MANAGED_END='<!-- elelem:codex:end -->'

_codex_substitute_placeholders() {
  local dst="$1"

  local placeholders substitutions
  eval "placeholders=(\"\${CODEX_PLACEHOLDERS[@]}\")"
  eval "substitutions=(\"\${CODEX_SUBSTITUTIONS[@]}\")"

  local count="${#placeholders[@]}"
  if (( count == 0 )); then
    return 0
  fi

  local perl_expr=""
  local i
  for (( i=0; i<count; i++ )); do
    local placeholder="${placeholders[$i]}"
    local substitution="${substitutions[$i]}"
    local escaped_substitution
    escaped_substitution="$(printf '%s\n' "$substitution" | sed 's:[\\&|$]:\\&:g')"
    perl_expr="${perl_expr}s|\\{\\{${placeholder}\\}\\}|${escaped_substitution}|g; "
  done

  perl -i -pe "$perl_expr" "$dst"
  return 0
}

_codex_skill_resolve_dst() {
  local src="$1"
  local out="$2"
  printf '%s/%s\n' "$out" "${src#$SKILLS_SOURCE/}"
}

_codex_substitute_placeholders_tree() {
  local root="$1"

  [[ -d "$root" ]] || return 0

  local file
  while IFS= read -r -d '' file; do
    _codex_substitute_placeholders "$file"
  done < <(find "$root" -type f -name '*.md' -print0)
}

_codex_strip_frontmatter() {
  local src="$1"
  perl -0pe 's/\A---\n.*?\n---\n//s' "$src"
}

_codex_append_rule_section() {
  local src="$1"
  local label="$2"
  local out="$3"

  {
    printf '## %s\n\n' "$label"
    _codex_strip_frontmatter "$src"
    printf '\n'
  } >> "$out"
}

_codex_render_agents_payload() {
  local out="$1"
  local common_ref="$2"
  local lang_ref="$3"

  [[ "$common_ref" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { echo "_codex_render_agents_payload: invalid common_ref: $common_ref" >&2; return 1; }
  [[ "$lang_ref" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { echo "_codex_render_agents_payload: invalid lang_ref: $lang_ref" >&2; return 1; }

  local _codex_common_files _codex_lang_dirs
  eval "_codex_common_files=(\"\${${common_ref}[@]+\${${common_ref}[@]}}\")"
  eval "_codex_lang_dirs=(\"\${${lang_ref}[@]+\${${lang_ref}[@]}}\")"

  {
    printf '# elelem for Codex\n\n'
    printf 'This section is managed by the elelem Codex installer. Re-run the installer after changing selections or updating source rules.\n\n'
  } > "$out"

  if (( ${#_codex_common_files[@]} == 0 && ${#_codex_lang_dirs[@]} == 0 )); then
    printf 'No elelem rules are currently installed for this scope.\n' >> "$out"
    return 0
  fi

  printf 'The common rules below always apply.\n\n' >> "$out"

  local file dir src
  for file in "${_codex_common_files[@]+"${_codex_common_files[@]}"}"; do
    src="$RULES_SOURCE/common/$file"
    _codex_append_rule_section "$src" "rules/common/$file" "$out"
  done

  if (( ${#_codex_lang_dirs[@]} > 0 )); then
    {
      printf '## Language-pack behaviour\n\n'
      printf 'Codex loads AGENTS.md instructions for the current scope rather than path-scoped rule files. Selected language packs therefore apply in every Codex session for this scope.\n\n'
    } >> "$out"

    for dir in "${_codex_lang_dirs[@]+"${_codex_lang_dirs[@]}"}"; do
      for src in "$RULES_SOURCE/$dir/"*.md; do
        [[ -f "$src" ]] || continue
        _codex_append_rule_section "$src" "rules/$dir/$(basename "$src")" "$out"
      done
    done
  fi

  _codex_substitute_placeholders "$out"
}

_codex_upsert_managed_block() {
  local target="$1"
  local payload="$2"

  local block_file tmp_file
  block_file="$(mktemp)"
  tmp_file="$(mktemp)"

  {
    printf '%s\n' "$CODEX_MANAGED_START"
    cat "$payload"
    printf '%s\n' "$CODEX_MANAGED_END"
  } > "$block_file"

  mkdir -p "$(dirname "$target")"

  if [[ -f "$target" ]] && grep -Fq "$CODEX_MANAGED_START" "$target"; then
    if ! grep -Fq "$CODEX_MANAGED_END" "$target"; then
      say_err "$target contains '$CODEX_MANAGED_START' without a matching '$CODEX_MANAGED_END'."
      return 1
    fi

    awk -v start="$CODEX_MANAGED_START" -v end="$CODEX_MANAGED_END" -v block="$block_file" '
      BEGIN {
        while ((getline line < block) > 0) {
          replacement = replacement line ORS
        }
        close(block)
      }
      $0 == start {
        printf "%s", replacement
        in_block = 1
        replaced = 1
        next
      }
      in_block && $0 == end {
        in_block = 0
        next
      }
      !in_block {
        print
      }
      END {
        if (!replaced) {
          printf "%s", replacement
        }
      }
    ' "$target" > "$tmp_file"
  else
    if [[ -f "$target" ]] && [[ -s "$target" ]]; then
      cat "$target" > "$tmp_file"
      printf '\n\n' >> "$tmp_file"
      cat "$block_file" >> "$tmp_file"
    else
      cat "$block_file" > "$tmp_file"
    fi
  fi

  mv "$tmp_file" "$target"
  rm -f "$block_file"
}

_codex_scan_file_for_placeholders() {
  local target="$1"

  [[ -f "$target" ]] || return 0

  local hits
  hits="$(grep -n -F -e '{{' -e 'TODO:' "$target" 2>/dev/null)" || true
  if [[ -n "$hits" ]]; then
    say_err "_codex_scan_file_for_placeholders: '$target' contains unsubstituted placeholder or TODO marker:"
    while IFS= read -r hit_line; do
      echo "  $hit_line" >&2
    done <<< "$hits"
    return 1
  fi
}

codex_resolve_targets() {
  local base_ref="$1"
  local agents_ref="$2"
  local skills_ref="$3"

  [[ "$base_ref" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { echo "codex_resolve_targets: invalid base_ref: $base_ref" >&2; return 1; }
  [[ "$agents_ref" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { echo "codex_resolve_targets: invalid agents_ref: $agents_ref" >&2; return 1; }
  [[ "$skills_ref" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { echo "codex_resolve_targets: invalid skills_ref: $skills_ref" >&2; return 1; }

  local scope_items scope_choice
  scope_items=(
    "project  ->  <project>/AGENTS.md + <project>/.agents/skills/"
    "user  ->  ~/.codex/AGENTS.md + ~/.agents/skills/"
  )

  echo "Install scope:"
  singleselect scope_choice scope_items 1

  local _codex_base=""
  local _codex_agents_target=""
  local _codex_skills_target=""

  if [[ "$scope_choice" == project* ]]; then
    local project_path
    read -rp "Project path [$(pwd)]: " project_path
    project_path="${project_path:-$(pwd)}"
    if [[ ! -d "$project_path" ]]; then
      say_err "$project_path does not exist"
      return 1
    fi
    if [[ "$(cd "$project_path" && pwd -P)" == "$(cd "$HOME" && pwd -P)" ]]; then
      say_err "project path resolves to HOME; refusing to install at this scope."
      return 1
    fi
    _codex_base="$project_path"
    _codex_agents_target="$project_path/AGENTS.md"
    _codex_skills_target="$project_path/.agents/skills"
  elif [[ "$scope_choice" == user* ]]; then
    _codex_base="$HOME"
    _codex_agents_target="$HOME/.codex/AGENTS.md"
    _codex_skills_target="$HOME/.agents/skills"
    echo "Installing rules to $_codex_agents_target"
    echo "Installing skills to $_codex_skills_target"
  else
    say_err "unrecognised Codex install scope: $scope_choice"
    return 1
  fi

  eval "${base_ref}=\"\$_codex_base\""
  eval "${agents_ref}=\"\$_codex_agents_target\""
  eval "${skills_ref}=\"\$_codex_skills_target\""
}

_codex_preflight_bundle() {
  perl - "$base" "$HOME" "$PWD" "${agent_bundle_files[@]}" <<'PERL'
use strict;
use warnings;
use Cwd qw(abs_path);
use Encode qw(decode FB_CROAK);
use Errno qw(ENOENT);

my ($target, $home, $current, @bundle_files) = @ARGV;
my %bundled = map { (s/\.toml\z//r) => 1 } @bundle_files;
my $target_root = abs_path($target);
my @roots;
my %seen;
for my $root ($home, $current, $target) {
  my $resolved = abs_path($root);
  defined $resolved or inspection_error($root);
  push @roots, $resolved unless $seen{$resolved}++;
}

sub inspection_error {
  my ($path) = @_;
  print STDERR "Error: inspection error for '$path'; review or remove the unsupported or inaccessible input, then rerun the installer.\n";
  exit 1;
}

sub conflict_error {
  my ($path, $identity) = @_;
  print STDERR "Error: identity conflict in '$path': '$identity'; move or remove the conflicting declaration, then rerun the installer.\n";
  exit 1;
}

sub exists_or_error {
  my ($path) = @_;
  local $! = 0;
  my @metadata = lstat($path);
  return 1 if @metadata;
  return 0 if $! == ENOENT;
  inspection_error($path);
}

sub file_content {
  my ($path) = @_;
  !-l $path && -f $path && -r $path or inspection_error($path);
  open my $handle, '<:raw', $path or inspection_error($path);
  my $bytes = '';
  while (1) {
    my $length = sysread($handle, my $part, 65536);
    defined $length or inspection_error($path);
    last if $length == 0;
    $bytes .= $part;
  }
  close $handle or inspection_error($path);
  my $text = eval { decode('UTF-8', $bytes, FB_CROAK) };
  defined $text or inspection_error($path);
  $text =~ s/\r\n/\n/g;
  $text !~ /[\x00-\x08\x0b-\x1f\x7f]/ or inspection_error($path);
  return $text;
}

sub key_parts {
  my ($remainder) = @_;
  my @parts;
  while (1) {
    $remainder =~ s/\A[ \t]*//;
    if ($remainder =~ s/\A"([^"\\]*)"// || $remainder =~ s/\A'([^'\\]*)'// || $remainder =~ s/\A([A-Za-z0-9_-]+)//) {
      push @parts, $1;
    } else {
      die "unsupported key\n";
    }
    $remainder =~ s/\A[ \t]*//;
    last unless $remainder =~ s/\A\.//;
  }
  return (\@parts, $remainder);
}

sub register_table {
  my ($parts, $tables, $namespaces, $keys) = @_;
  my $path = join "\0", @$parts;
  !$tables->{$path}++ or die "duplicate table\n";
  my @prefix;
  for my $part (@$parts) {
    push @prefix, $part;
    my $key = join "\0", @prefix;
    !$keys->{$key} or die "table collides with key\n";
    $namespaces->{$key} = 1;
  }
}

sub consume_multiline {
  my ($fragment, $delimiter) = @_;
  my $end = index($fragment, $delimiter);
  my $content = $end < 0 ? $fragment : substr($fragment, 0, $end);
  $content !~ /\\/ or die "escaped value\n";
  return 0 if $end < 0;
  my $suffix = substr($fragment, $end + 3);
  $suffix =~ /\A[ \t]*(?:\#.*)?\z/ or die "invalid multiline suffix\n";
  return 1;
}

sub inspect_table {
  my ($state, $remainder) = @_;
  my ($parts, $rest) = key_parts($remainder);
  $rest =~ /\A\][ \t]*(?:\#.*)?\z/ or die "invalid table\n";
  @{$state->{table}} = @$parts;
  register_table($parts, $state->{tables}, $state->{namespaces}, $state->{keys});
  my $table = $state->{table};
  if ($state->{kind} eq 'config' && @$table >= 2 && $table->[0] eq 'agents' && $bundled{$table->[1]}) {
    @$table == 2 or die "unsupported nested agent table\n";
    push @{$state->{conflicts}}, $table->[1];
  }
}

sub inspect_assignment_value {
  my ($state, $rest, $is_name) = @_;
  if ($rest =~ s/\A("""|''')//) {
    !$is_name or die "multiline name\n";
    my $delimiter = $1;
    $state->{multiline} = $delimiter unless consume_multiline($rest, $delimiter);
  } elsif ($rest =~ /\A"([^"\\]*)"[ \t]*(?:\#.*)?\z/ || $rest =~ /\A'([^'\\]*)'[ \t]*(?:\#.*)?\z/) {
    $state->{name} = $1 if $is_name;
  } elsif (!$is_name && $rest =~ /\A(?:true|false|[+-]?(?:0|[1-9](?:_?[0-9])*)(?:\.[0-9](?:_?[0-9])*)?(?:[eE][+-]?[0-9](?:_?[0-9])*)?)[ \t]*(?:\#.*)?\z/) {
    return;
  } else {
    die "unsupported value\n";
  }
}

sub inspect_assignment {
  my ($state, $line) = @_;
  my ($parts, $rest) = key_parts($line);
  @$parts == 1 && $rest =~ s/\A=[ \t]*// or die "unsupported assignment\n";
  my $table = $state->{table};
  my $key = join "\0", @$table, $parts->[0];
  !$state->{keys}{$key}++ && !$state->{namespaces}{$key} or die "duplicate key\n";
  if ($state->{kind} eq 'config' && ((!@$table && $parts->[0] eq 'agents') || (@$table == 1 && $table->[0] eq 'agents' && $bundled{$parts->[0]}))) {
    die "unsupported agent assignment\n";
  }
  my $is_name = $state->{kind} eq 'agent' && !@$table && $parts->[0] eq 'name';
  $state->{name_count}++ if $is_name;
  inspect_assignment_value($state, $rest, $is_name);
}

sub inspect_document {
  my ($text, $kind) = @_;
  my $state = { kind => $kind, tables => {}, namespaces => {}, keys => {}, table => [], conflicts => [], name => '', name_count => 0, multiline => '' };
  for my $line (split /\n/, $text, -1) {
    if (length $state->{multiline}) {
      $state->{multiline} = '' if consume_multiline($line, $state->{multiline});
      next;
    }
    next if $line =~ /\A[ \t]*(?:\#.*)?\z/;
    if ($line =~ /\A[ \t]*\[(.*)\z/) {
      inspect_table($state, $1);
      next;
    }
    inspect_assignment($state, $line);
  }
  !length($state->{multiline}) or die "unterminated multiline string\n";
  $kind ne 'agent' || $state->{name_count} == 1 or die "missing or duplicate name\n";
  return $kind eq 'agent' ? $state->{name} : $state->{conflicts}[0];
}

sub inspect_file {
  my ($path, $kind) = @_;
  my $content = file_content($path);
  my $identity;
  eval { $identity = inspect_document($content, $kind); 1 } or inspection_error($path);
  return unless defined $identity && $bundled{$identity};
  return if $kind eq 'agent' && $path eq "$target_root/.codex/agents/$identity.toml";
  conflict_error($path, $identity);
}

sub inspect_config {
  my ($root) = @_;
  my $directory = "$root/.codex";
  return unless exists_or_error($directory);
  -d $directory && -x $directory or inspection_error($directory);
  my $path = "$directory/config.toml";
  inspect_file($path, 'config') if exists_or_error($path);
}

sub inspect_agents {
  my ($root) = @_;
  my $directory = "$root/.codex/agents";
  return unless exists_or_error("$root/.codex");
  return unless exists_or_error($directory);
  -d $directory or inspection_error($directory);
  opendir my $handle, $directory or inspection_error($directory);
  local $! = 0;
  my @entries = readdir $handle;
  $! == 0 or inspection_error($directory);
  closedir $handle or inspection_error($directory);
  for my $entry (sort @entries) {
    next unless $entry =~ /\.toml\z/;
    inspect_file("$directory/$entry", 'agent');
  }
}

inspect_config($_) for @roots;
inspect_agents($_) for @roots;
PERL
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

  codex_resolve_targets base agents_target skills_target || exit 1

  manifest_file="$SCRIPT_DIR/.elelem-manifest-codex"
  assert_manifest_base_matches "$manifest_file" "$base" || exit 1
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
    say_info "Codex applies selected language packs globally through AGENTS.md (not path-based activation)."
    say_step "Language packs to install (none selected by default):"
    multiselect lang_selected lang_dirs lang_defaults
  else
    echo
    say_info "No language packs found in $RULES_SOURCE (common-only install)."
  fi

  common_files=()
  for _item in "${common_selected[@]+"${common_selected[@]}"}"; do
    common_files+=("${_item}.md")
  done

  if (( ${#common_files[@]} == 0 && ${#lang_selected[@]} == 0 )); then
    say_warn "no rules selected."
    confirm_rule_items=("Continue with no rules")
    confirm_rule_defaults=(0)
    multiselect confirm_rule_selected confirm_rule_items confirm_rule_defaults
    (( ${#confirm_rule_selected[@]} > 0 )) || { say_info "Aborted."; exit 0; }
  fi

  echo
  say_step "Writing Codex instructions:"
  say_info "Rules -> $agents_target"

  payload_file="$(mktemp)"
  trap 'rm -f "$payload_file"' EXIT
  _codex_render_agents_payload "$payload_file" common_files lang_selected
  _codex_upsert_managed_block "$agents_target" "$payload_file" || exit 1
  _codex_scan_file_for_placeholders "$agents_target" || exit 1
  say_ok "updated managed elelem block in $(basename "$agents_target")"

  if [[ -d "$SKILLS_SOURCE" ]] && compgen -G "$SKILLS_SOURCE/*/" > /dev/null; then
    echo
    say_step "Skills (target: $skills_target):"
    skills_items=("Install skills")
    skills_defaults=(1)
    multiselect skills_selected skills_items skills_defaults

    if (( ${#skills_selected[@]} > 0 )); then
      say_info "Installing skills -> $skills_target/"
      mkdir -p "$skills_target"
      skills_files=()
      while IFS= read -r -d '' _f; do
        skills_files+=("${_f#"$SKILLS_SOURCE"/}")
      done < <(find "$SKILLS_SOURCE" -type f -print0)
      install_files_from_dir "$SKILLS_SOURCE" "$skills_target" ".agents/skills" manifest_entries skills_files _codex_skill_resolve_dst
      _codex_substitute_placeholders_tree "$skills_target"
      scan_no_unsubstituted_placeholders "$skills_target" || exit 1
      say_ok "installed ${#skills_files[@]} skill file(s)"
    else
      say_info "Skipped skills install."
    fi
  else
    echo
    say_info "No skills found in $SKILLS_SOURCE (skipping skills install)."
  fi

  agent_bundle_items=("Elelem agent bundle (11 agents)")
  agent_bundle_defaults=(0)
  multiselect agent_bundle_selected agent_bundle_items agent_bundle_defaults

  changed_paths=()
  if (( ${#agent_bundle_selected[@]} > 0 )); then
    agent_bundle_files=()
    for _f in "$SCRIPT_DIR/agents/codex/"*.toml; do
      [[ -f "$_f" ]] || continue
      agent_bundle_files+=("${_f##*/}")
    done
    _codex_preflight_bundle || exit 1
    install_agent_bundle_notice "$SCRIPT_DIR/agents/LICENSE" "$base/.codex/agents.LICENSE" .codex/agents.LICENSE manifest_entries changed_paths || exit 1
    install_agent_bundle_files "$SCRIPT_DIR/agents/codex" "$base/.codex/agents" .codex/agents manifest_entries agent_bundle_files changed_paths || exit 1
  fi

  if ! prune_stale_manifest_entries "$manifest_file" "$base" manifest_entries .codex/agents; then
    report_agent_bundle_changes changed_paths
    exit 1
  fi
  if ! write_manifest "$manifest_file" "$base" manifest_entries; then
    report_agent_bundle_changes changed_paths
    exit 1
  fi

  echo
  say_ok "Done."
  echo "Rules:    $agents_target"
  echo "Skills:   $skills_target"
  echo "Manifest: $manifest_file"
  echo "Verify rules in Codex by asking about an elelem rule, or run /plan and /review to exercise the installed workflow."
fi
