#!/bin/bash
set -e
SCHEDULED_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TASK_NAME="$1"

if [ -z "$TASK_NAME" ]; then
    echo "Usage: run-task.sh <task-name>"
    exit 1
fi

# Ensure PATH includes common locations for claude CLI
export PATH="/usr/local/bin:/opt/homebrew/bin:$HOME/.npm-global/bin:$PATH"

# Load .env if present
REPO_ROOT="$(cd "$SCHEDULED_DIR/.." && pwd)"
if [ -f "$REPO_ROOT/.env" ]; then
    set -a
    source "$REPO_ROOT/.env"
    set +a
fi

"$SCHEDULED_DIR/node_modules/.bin/tsx" "$SCHEDULED_DIR/scripts/scheduled.ts" run "$TASK_NAME"
