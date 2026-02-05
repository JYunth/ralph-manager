#!/bin/bash
# Ralph Manager — First-time setup
# Run this once after dropping the skill into your workflow.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

echo "Ralph Manager — Setup"
echo ""

# ── Check system dependencies ──
MISSING=()

command -v python3 >/dev/null 2>&1 || MISSING+=("python3")
command -v tmux >/dev/null 2>&1    || MISSING+=("tmux")
command -v git >/dev/null 2>&1     || MISSING+=("git")

if [ ${#MISSING[@]} -gt 0 ]; then
    echo "Missing system dependencies: ${MISSING[*]}"
    echo "Install them with your package manager before continuing."
    exit 1
fi

# ── Install Python deps ──
echo "[1/3] Checking Python dependencies..."
DEPS_OK=true
python3 -c "import flask" 2>/dev/null || DEPS_OK=false
python3 -c "import flask_cors" 2>/dev/null || DEPS_OK=false

if [ "$DEPS_OK" = false ]; then
    echo "  Installing flask, flask-cors..."
    pip3 install --quiet --user -r "$SCRIPT_DIR/requirements.txt" 2>/dev/null \
        || pip install --quiet --user -r "$SCRIPT_DIR/requirements.txt" 2>/dev/null \
        || pip3 install --quiet --break-system-packages -r "$SCRIPT_DIR/requirements.txt" 2>/dev/null \
        || { echo "  Failed. Run manually: pip install flask flask-cors"; exit 1; }
fi
echo "  flask, flask-cors — ok"

# ── Make CLI executable + symlink ──
echo "[2/3] Setting up ralph CLI..."
chmod +x "$SCRIPT_DIR/ralph-cli"

RALPH_BIN="$HOME/.local/bin/ralph"
mkdir -p "$HOME/.local/bin"
ln -sf "$SCRIPT_DIR/ralph-cli" "$RALPH_BIN"

# Check if ~/.local/bin is in PATH
if ! echo "$PATH" | tr ':' '\n' | grep -q "$HOME/.local/bin"; then
    echo "  Warning: ~/.local/bin is not in PATH"
    echo "  Add to your shell profile: export PATH=\"\$HOME/.local/bin:\$PATH\""
fi
echo "  ralph → $RALPH_BIN"

# ── Make start script executable ──
echo "[3/3] Marking scripts executable..."
chmod +x "$SCRIPT_DIR/start-dashboard.sh"
echo "  start-dashboard.sh — ready"

echo ""
echo "Setup complete."
echo ""
echo "Usage:"
echo "  export RALPH_JSON=/path/to/your/project/ralph.json"
echo "  ralph show"
echo "  $SCRIPT_DIR/start-dashboard.sh /path/to/your/project/ralph.json"
