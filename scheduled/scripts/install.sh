#!/bin/bash
set -e
SCHEDULED_DIR="$(cd "$(dirname "$0")/.." && pwd)"
echo "Installing scheduled tasks..."
npx --prefix "$SCHEDULED_DIR" tsx "$SCHEDULED_DIR/scripts/scheduled.ts" install
