#!/bin/bash
# Symlinks Claude Code config from this repo into ~/.claude
# Run: ./install.sh

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

if [ ! -d "$CLAUDE_DIR" ]; then
  echo "Error: $CLAUDE_DIR does not exist. Is Claude Code installed?"
  exit 1
fi

# Back up existing dirs/files before replacing with symlinks
backup_if_exists() {
  local target="$1"
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    local backup="${target}.bak.$(date +%s)"
    echo "Backing up $target -> $backup"
    mv "$target" "$backup"
  fi
}

backup_if_exists "$CLAUDE_DIR/agents"
backup_if_exists "$CLAUDE_DIR/skills"
backup_if_exists "$CLAUDE_DIR/commands"
backup_if_exists "$CLAUDE_DIR/agent-memory"
backup_if_exists "$CLAUDE_DIR/settings.json"

# Create symlinks
ln -sfn "$REPO_DIR/agents" "$CLAUDE_DIR/agents"
ln -sfn "$REPO_DIR/skills" "$CLAUDE_DIR/skills"
ln -sfn "$REPO_DIR/commands" "$CLAUDE_DIR/commands"
ln -sfn "$REPO_DIR/agent-memory" "$CLAUDE_DIR/agent-memory"
ln -sfn "$REPO_DIR/settings.json" "$CLAUDE_DIR/settings.json"

echo "Done. Symlinks created:"
echo "  $CLAUDE_DIR/agents -> $REPO_DIR/agents"
echo "  $CLAUDE_DIR/skills -> $REPO_DIR/skills"
echo "  $CLAUDE_DIR/commands -> $REPO_DIR/commands"
echo "  $CLAUDE_DIR/agent-memory -> $REPO_DIR/agent-memory"
echo "  $CLAUDE_DIR/settings.json -> $REPO_DIR/settings.json"
