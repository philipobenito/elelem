#!/usr/bin/env bash
# Captures the static corpus metrics defined in evals/baseline/BASELINE.md.
# Prints to stdout; redirect into a dated file under evals/baseline/ to
# record a capture, e.g.:
#
#   evals/baseline/measure.sh > evals/baseline/2026-08-03-static.txt
#
# Every section is sorted so that two runs against the same tree produce
# byte-identical output.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$REPO_ROOT"

_heading() {
  echo
  echo "== $1 =="
}

echo "elelem corpus baseline: static metrics"
echo "commit: $(git rev-parse HEAD 2>/dev/null || echo 'not a git checkout')"

_heading "volume by file class (words)"
printf '%-28s %s\n' "rules/common (always on):" "$(find rules/common -name '*.md' -print0 | xargs -0 cat | wc -w)"
printf '%-28s %s\n' "rules/<lang> (glob-loaded):" "$(find rules -name '*.md' -not -path 'rules/common/*' -print0 | xargs -0 cat | wc -w)"
printf '%-28s %s\n' "skills/_shared:" "$(find skills/_shared -name '*.md' -print0 | xargs -0 cat | wc -w)"
printf '%-28s %s\n' "skills (excluding _shared):" "$(find skills -name '*.md' -not -path 'skills/_shared/*' -print0 | xargs -0 cat | wc -w)"
printf '%-28s %s\n' "skills total:" "$(find skills -name '*.md' -print0 | xargs -0 cat | wc -w)"

_heading "words per skill"
for dir in skills/*/; do
  name="$(basename "$dir")"
  [ "$name" = "_shared" ] && continue
  words="$(find "$dir" -name '*.md' -print0 | xargs -0 cat | wc -w)"
  printf '%6s %s\n' "$words" "$name"
done | sort -rn -k1,1

_heading "words per always-on rule file"
for file in rules/common/*.md; do
  printf '%6s %s\n' "$(wc -w < "$file")" "$file"
done | sort -rn -k1,1

_heading "markdown file count"
printf '%-28s %s\n' "rules:" "$(find rules -name '*.md' | wc -l)"
printf '%-28s %s\n' "skills:" "$(find skills -name '*.md' | wc -l)"

_heading "RFC 2119 directive density (MUST tokens per file, non-zero)"
grep -rc 'MUST' rules skills --include='*.md' | awk -F: '$2 > 0' | sort -t: -k2,2 -rn -k1,1
printf 'total MUST tokens: %s\n' "$(grep -ro 'MUST' rules skills --include='*.md' | wc -l)"

_heading "files carrying rationalisation-prevention material"
grep -rli 'rationalisation' rules skills --include='*.md' | sort

_heading "trigger eval coverage"
for dir in skills/*/; do
  name="$(basename "$dir")"
  [ "$name" = "_shared" ] && continue
  if [ -f "evals/${name}-trigger.json" ]; then
    echo "[COVERED] $name"
  else
    echo "[NO SET] $name"
  fi
done | sort

_heading "harness feature references (occurrences in rules/ and skills/)"
# The 2026 audit in issue #11 checked which harness primitives the corpus
# names at all. Zero counts here are the finding, so absent features are
# printed rather than skipped.
for feature in Workflow EnterWorktree Monitor CronCreate LSP AskUserQuestion \
  ExitPlanMode SendMessage TaskCreate structured-output; do
  count="$(grep -ro "$feature" rules skills --include='*.md' | wc -l)"
  printf '%-20s %s\n' "$feature:" "$count"
done
