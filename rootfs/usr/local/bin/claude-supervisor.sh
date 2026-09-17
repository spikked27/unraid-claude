#!/usr/bin/env bash
# Keeps `claude remote-control` running. Lives inside the "claude" tmux session.
cd /config/workspace || exit 1
export HOME=/config
export PATH=/config/.local/bin:$PATH

NAME="${RC_SESSION_NAME:-Unraid}"
MODE="${PERMISSION_MODE:-default}"

while true; do
    clear
    echo "=== Claude Remote Control: '$NAME'  (permission mode: $MODE) ==="
    echo "Detach from this screen with: Ctrl-b then d"
    echo
    start=$(date +%s)
    # shellcheck disable=SC2086
    claude remote-control --name "$NAME" --permission-mode "$MODE" ${RC_EXTRA_ARGS:-}
    code=$?
    runtime=$(( $(date +%s) - start ))
    echo
    if [ "$runtime" -lt 60 ]; then
        echo "Remote Control exited after ${runtime}s (exit code $code)."
        echo "If you haven't finished setup, open the container console and run: claude-setup"
        echo "Retrying in 60s..."
        sleep 60
    else
        echo "Remote Control stopped (exit code $code). Restarting in 5s..."
        sleep 5
    fi
done
