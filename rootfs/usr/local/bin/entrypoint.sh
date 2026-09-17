#!/usr/bin/env bash
set -uo pipefail

log() { echo "[entrypoint] $*"; }

PUID="${PUID:-99}"
PGID="${PGID:-100}"
USER_NAME=claude
export HOME=/config

# --- Things that silently break Remote Control or burn API credits ---------
for v in ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN ANTHROPIC_BASE_URL CLAUDE_CODE_OAUTH_TOKEN \
         DISABLE_TELEMETRY DO_NOT_TRACK CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC DISABLE_GROWTHBOOK; do
    if [ -n "${!v:-}" ]; then
        log "WARNING: $v is set - unsetting it (it breaks Remote Control / subscription login)."
        unset "$v"
    fi
done

# --- User / group matching Unraid's nobody:users (99:100) ------------------
if ! getent group "$PGID" >/dev/null; then
    groupadd -g "$PGID" claude
fi
GROUP_NAME="$(getent group "$PGID" | cut -d: -f1)"

if id -u "$USER_NAME" >/dev/null 2>&1; then
    usermod -o -u "$PUID" -g "$PGID" "$USER_NAME" >/dev/null 2>&1 || true
else
    useradd -o -u "$PUID" -g "$PGID" -d /config -s /bin/bash -M "$USER_NAME"
fi

# --- Docker socket access ---------------------------------------------------
if [ -S /var/run/docker.sock ]; then
    DGID="$(stat -c %g /var/run/docker.sock)"
    if ! getent group "$DGID" >/dev/null; then
        groupadd -g "$DGID" dockerhost
    fi
    DGROUP="$(getent group "$DGID" | cut -d: -f1)"
    usermod -aG "$DGROUP" "$USER_NAME"
    log "Docker socket found (gid $DGID) - access granted."
else
    log "WARNING: /var/run/docker.sock not mounted - Claude won't be able to see your containers."
fi

# --- Persistent dirs and first-run defaults --------------------------------
mkdir -p /config/workspace /config/.claude /config/.local/bin
[ -f /config/workspace/CLAUDE.md ] || cp /defaults/CLAUDE.md /config/workspace/CLAUDE.md
[ -f /config/.claude/settings.json ] || cp /defaults/settings.json /config/.claude/settings.json
[ -f /config/.bashrc ] || cp /defaults/bashrc /config/.bashrc

if [ ! -f /config/.ownership-set ]; then
    chown -R "$PUID:$PGID" /config
    touch /config/.ownership-set
else
    chown "$PUID:$PGID" /config /config/workspace /config/.claude /config/.local
fi

as_user() { gosu "$USER_NAME" env HOME=/config PATH="$PATH" "$@"; }

if [ ! -d /config/workspace/.git ]; then
    as_user git -C /config/workspace init -q && \
    as_user git -C /config/workspace config user.email "claude@unraid.local" && \
    as_user git -C /config/workspace config user.name "Claude"
fi

# --- Install / update Claude Code (native installer, into /config) ---------
if [ ! -x /config/.local/bin/claude ]; then
    log "Installing Claude Code (first run)..."
    as_user bash -c 'curl -fsSL https://claude.ai/install.sh | bash' || log "Install failed - check network."
else
    log "Checking for Claude Code updates..."
    as_user claude update >/dev/null 2>&1 || true
fi
as_user claude --version 2>/dev/null || true

# --- Start Remote Control inside tmux --------------------------------------
start_tmux() {
    as_user tmux new-session -d -s claude -c /config/workspace /usr/local/bin/claude-supervisor.sh
}

shutdown() {
    log "Stopping..."
    as_user tmux send-keys -t claude C-c 2>/dev/null || true
    sleep 3
    as_user tmux kill-server 2>/dev/null || true
    exit 0
}
trap shutdown SIGTERM SIGINT

start_tmux
log "Ready. First time? Open this container's Console in Unraid and run: claude-setup"

while true; do
    if ! as_user tmux has-session -t claude 2>/dev/null; then
        log "tmux session ended - restarting it."
        start_tmux
    fi
    sleep 10 &
    wait $!
done
