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
backup_if_exists "$CLAUDE_DIR/hooks"
backup_if_exists "$CLAUDE_DIR/agent-memory"
backup_if_exists "$CLAUDE_DIR/settings.json"
backup_if_exists "$CLAUDE_DIR/statusline.sh"

# Create symlinks
ln -sfn "$REPO_DIR/agents" "$CLAUDE_DIR/agents"
ln -sfn "$REPO_DIR/skills" "$CLAUDE_DIR/skills"
ln -sfn "$REPO_DIR/commands" "$CLAUDE_DIR/commands"
ln -sfn "$REPO_DIR/hooks" "$CLAUDE_DIR/hooks"
ln -sfn "$REPO_DIR/agent-memory" "$CLAUDE_DIR/agent-memory"
ln -sfn "$REPO_DIR/settings.json" "$CLAUDE_DIR/settings.json"
ln -sfn "$REPO_DIR/statusline.sh" "$CLAUDE_DIR/statusline.sh"

# Ensure scripts are executable
chmod +x "$REPO_DIR/statusline.sh"
chmod +x "$REPO_DIR/hooks/"*.sh 2>/dev/null || true

echo "Done. Symlinks created:"
echo "  $CLAUDE_DIR/agents -> $REPO_DIR/agents"
echo "  $CLAUDE_DIR/skills -> $REPO_DIR/skills"
echo "  $CLAUDE_DIR/commands -> $REPO_DIR/commands"
echo "  $CLAUDE_DIR/hooks -> $REPO_DIR/hooks"
echo "  $CLAUDE_DIR/agent-memory -> $REPO_DIR/agent-memory"
echo "  $CLAUDE_DIR/settings.json -> $REPO_DIR/settings.json"
echo "  $CLAUDE_DIR/statusline.sh -> $REPO_DIR/statusline.sh"

# Install scheduled tasks
if [ -d "$REPO_DIR/scheduled" ]; then
  echo ""
  echo "Installing scheduled tasks..."
  if [ ! -d "$REPO_DIR/scheduled/node_modules" ]; then
    (cd "$REPO_DIR/scheduled" && npm install)
  fi
  bash "$REPO_DIR/scheduled/scripts/install.sh"
fi
