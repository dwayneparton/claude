#!/bin/bash
set -e
SCHEDULED_DIR="$(cd "$(dirname "$0")/.." && pwd)"
"$SCHEDULED_DIR/node_modules/.bin/tsx" "$SCHEDULED_DIR/scripts/scheduled.ts" install
