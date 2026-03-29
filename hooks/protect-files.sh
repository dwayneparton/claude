#!/bin/bash
# Blocks edits to sensitive files: .env, lock files, .git/
# Used as a PreToolUse hook for Edit|Write events.
# Exit 0 = allow, Exit 2 = block (reason sent to Claude as feedback).

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

PROTECTED_PATTERNS=(
  ".env"
  ".git/"
  "package-lock.json"
  "yarn.lock"
  "pnpm-lock.yaml"
  "Podfile.lock"
  "Gemfile.lock"
  "Cargo.lock"
)

for pattern in "${PROTECTED_PATTERNS[@]}"; do
  if [[ "$FILE_PATH" == *"$pattern"* ]]; then
    echo "Blocked: '$FILE_PATH' matches protected pattern '$pattern'. Do not edit protected files." >&2
    exit 2
  fi
done

exit 0
