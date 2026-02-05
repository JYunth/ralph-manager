#!/bin/bash
# Start Ralph Dashboard in tmux
# Usage: start-dashboard.sh /path/to/ralph.json
#   or:  RALPH_JSON=/path/to/ralph.json start-dashboard.sh

SESSION_NAME="ralph-dashboard"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Resolve ralph.json path: argument > env var
RJSON="${1:-$RALPH_JSON}"

if [ -z "$RJSON" ]; then
    echo "error: Pass ralph.json path as argument or set RALPH_JSON env var"
    echo "Usage: $0 /path/to/ralph.json"
    exit 1
fi

# Make absolute
RJSON="$(cd "$(dirname "$RJSON")" && pwd)/$(basename "$RJSON")"

# Check if already running
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "Dashboard already running in tmux session: $SESSION_NAME"
    echo "Attach: tmux attach -t $SESSION_NAME"
    echo "View: http://localhost:5000"
    exit 0
fi

# Create new session
tmux new-session -d -s "$SESSION_NAME" -c "$SCRIPT_DIR"

# Run dashboard with RALPH_JSON set
tmux send-keys -t "$SESSION_NAME" "RALPH_JSON=$RJSON python3 dashboard.py" Enter

echo "Ralph Dashboard started"
echo "  Polling: $RJSON"
echo "  URL: http://localhost:5000"
echo "  Session: tmux attach -t $SESSION_NAME"
echo "  Stop: tmux kill-session -t $SESSION_NAME"
