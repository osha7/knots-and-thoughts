#!/usr/bin/env bash
# PostToolUse hook: format and lint the single file Claude just edited.
#
# Runs on every Edit/Write of a TS/TSX/CSS/JSON/MD file. Fast by design —
# per-file, not whole-project. Whole-project typecheck belongs in /phase-review
# and CI, where the latency is acceptable.
#
# Exit 2 tells Claude Code the hook failed and feeds stderr back as feedback,
# so Claude sees the lint errors and can fix them in the same turn.
#
# See CODE-STANDARDS.md §1 — enforcement beats instruction.

set -uo pipefail

payload=$(cat)
file=$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty')

[[ -z "$file" || ! -f "$file" ]] && exit 0

# Only touch files we have opinions about.
case "$file" in
  *.ts|*.tsx|*.mts|*.cts|*.js|*.jsx|*.mjs|*.css|*.json|*.md) ;;
  *) exit 0 ;;
esac

# Never reformat generated output.
case "$file" in
  */node_modules/*|*/.next/*|*/coverage/*|*/prisma/migrations/*) exit 0 ;;
esac

cd "$CLAUDE_PROJECT_DIR" || exit 0
[[ -d node_modules ]] || exit 0   # pre-install: nothing to run yet

problems=""

# 1. Format. Prettier is not negotiable and never discussed in review.
if ! npx --no-install prettier --write "$file" >/dev/null 2>&1; then
  problems+="prettier could not parse ${file} — likely a syntax error.\n"
fi

# 2. Lint with autofix, then report whatever could not be fixed.
if [[ "$file" == *.ts || "$file" == *.tsx || "$file" == *.js || "$file" == *.jsx ]]; then
  if ! lint_out=$(npx --no-install eslint --fix --max-warnings=0 "$file" 2>&1); then
    problems+="ESLint (warnings are errors — see CODE-STANDARDS.md §3):\n${lint_out}\n"
  fi
fi

if [[ -n "$problems" ]]; then
  printf 'Fix these before continuing.\n\n%b' "$problems" >&2
  exit 2
fi

exit 0
