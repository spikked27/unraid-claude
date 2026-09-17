FROM debian:trixie-slim

ARG DEBIAN_FRONTEND=noninteractive

# Base tools Claude finds useful for diagnosing a home server
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl wget gnupg git jq tmux gosu tini procps psmisc \
        iproute2 iputils-ping dnsutils netcat-openbsd nano less ripgrep \
        sqlite3 python3 unzip xz-utils htop lsof tree file bash-completion \
    && install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
        > /etc/apt/sources.list.d/docker.list \
    && apt-get update && apt-get install -y --no-install-recommends docker-ce-cli docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# Claude Code itself is installed at first start into /config (persistent),
# so it can auto-update without needing a new image.
ENV HOME=/config \
    PATH=/config/.local/bin:$PATH \
    TERM=xterm-256color \
    LANG=C.UTF-8 \
    PUID=99 \
    PGID=100 \
    RC_SESSION_NAME=Unraid \
    PERMISSION_MODE=default

COPY rootfs/ /
RUN chmod +x /usr/local/bin/*

VOLUME /config
WORKDIR /config/workspace

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
