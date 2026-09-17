# unraid-claude: project context for Claude Code

This file is for working ON this repo. (The CLAUDE.md that ships inside the container,
with rules for Claude running on the Unraid server, is `rootfs/defaults/CLAUDE.md`.)

## Goal
A Docker container for Unraid that runs Claude Code with **Remote Control**, so the owner can
chat with Claude from the Claude phone app (Code tab) or claude.ai/code and have it diagnose and
manage the Docker containers on the server (e.g. set up Tdarr). Must:
- Use the owner's **Claude Pro/Max subscription login**, never an API key or API credits.
- Install like any other Unraid app, from a template in this GitHub repo.
- Be updatable by pushing to GitHub (Actions builds the image to GHCR).

## Current status
- All files are written but **not yet pushed** to GitHub, and the image has **never been built or run**.
  Scripts pass `bash -n`; XML/YAML/JSON pass syntax checks. Expect first-build fixes.
- The placeholder `spikked27` appears throughout. Replace it with the owner's GitHub
  username in **lowercase** (GHCR requires lowercase).
- The GitHub repo already exists (empty). Ask the owner for its URL if you don't have it.

## Next steps
1. Replace `spikked27` everywhere, commit, push to `main`.
2. Watch the GitHub Actions run (`.github/workflows/build.yml`) and fix any build errors.
3. Owner must manually make the GHCR package public: GitHub profile > Packages > unraid-claude >
   Package settings > Change visibility. (Can't be done with a repo-scoped token.)
4. Owner installs on Unraid: Docker > Add Container > **Template repositories** > add
   `https://github.com/<user>/unraid-claude` (fallback: raw URL of `templates/claude-code.xml`),
   then pick the **claude-code** template and Apply.
5. First run: container Console > `claude-setup` (login, trust workspace, accept Remote Control).
6. Test from phone: Claude app > Code > session "Unraid". Fix whatever breaks on real hardware.
7. Optional later: submit to Community Apps at https://ca.unraid.net/submit (Validate + Scan).
   Repo already has what CA requires: public repo, OSI license (MIT), `ca_profile.xml` with a
   non-empty `<Profile>`, template in `templates/`. A CA listing is public.

## Layout
- `Dockerfile`: debian:trixie-slim + git, jq, tmux, gosu, tini, sqlite3, python3, ripgrep, etc.,
  plus docker-ce-cli and compose plugin from Docker's apt repo. ENTRYPOINT tini -> entrypoint.sh.
  HOME=/config, PATH includes /config/.local/bin.
- `rootfs/usr/local/bin/entrypoint.sh`: runs as root, then:
  - unsets ANTHROPIC_API_KEY / ANTHROPIC_AUTH_TOKEN / ANTHROPIC_BASE_URL / CLAUDE_CODE_OAUTH_TOKEN
    and DISABLE_TELEMETRY / DO_NOT_TRACK / CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC / DISABLE_GROWTHBOOK
    (these break Remote Control or force API billing)
  - creates user `claude` with PUID/PGID (default 99:100, Unraid nobody:users)
  - reads the docker.sock GID and adds `claude` to that group
  - seeds defaults (workspace CLAUDE.md, .claude/settings.json, .bashrc) only if missing
  - one-time recursive chown of /config (marker file `.ownership-set`)
  - `git init` in /config/workspace (Remote Control shows diffs for git repos)
  - installs Claude Code with the native installer (`curl -fsSL https://claude.ai/install.sh | bash`)
    into /config on first run, otherwise runs `claude update`
  - starts tmux session `claude` running claude-supervisor.sh; loops to restart tmux if it dies;
    SIGTERM sends Ctrl-C to tmux then kills it
- `rootfs/usr/local/bin/claude-supervisor.sh`: loop running
  `claude remote-control --name "$RC_SESSION_NAME" --permission-mode "$PERMISSION_MODE" $RC_EXTRA_ARGS`
  in /config/workspace; 60s backoff if it exits within 60s (e.g. not logged in yet).
- `rootfs/usr/local/bin/claude-setup`: interactive: `claude auth login` -> run `claude` once to accept
  workspace trust -> pkill the remote-control process -> `tmux attach` so the user answers the
  one-time "Enable Remote Control? (y/n)" prompt. Re-execs via gosu if run as root.
- `claude-attach` (tmux attach), `claude-shell` (interactive claude in workspace).
- `rootfs/defaults/CLAUDE.md`: rules for Claude on the server (Unraid conventions, never mix
  /mnt/user with /mnt/diskX or /mnt/cache in one copy, create apps as templates in templates-user,
  back up before editing, ask before stop/remove, log changes to CHANGES.md).
- `rootfs/defaults/settings.json`: allowlist of read-only commands (docker ps/logs/inspect, df...),
  denylist for prune / volume rm.
- `templates/claude-code.xml`: Unraid template. Mappings (host path == container path):
  /config <- /mnt/user/appdata/claude-code (rw); /var/run/docker.sock (rw); /mnt/user (ro,slave);
  /mnt/user/appdata (rw,slave); /boot/config/plugins/dockerMan/templates-user (rw);
  /var/log (ro, advanced). Vars: RC_SESSION_NAME=Unraid, PERMISSION_MODE=default, PUID, PGID,
  RC_EXTRA_ARGS. ExtraParams: --hostname=unraid-claude --restart=unless-stopped.
- `ca_profile.xml`, `LICENSE` (MIT), `icon.png` (generic terminal/server icon, not a brand logo).
- `.github/workflows/build.yml`: build linux/amd64, push ghcr.io/<repo>:latest + semver + sha tags,
  on push to main (ignores md/templates/icon/license changes), v* tags, weekly cron, manual dispatch.

## Design decisions (keep unless the owner changes them)
- Remote Control **server mode** in tmux, not an interactive session, so it runs headless and
  survives disconnects. Server mode exits after ~10 min without network; the supervisor restarts it.
- Login must be `claude auth login` (full-scope). `claude setup-token` / CLAUDE_CODE_OAUTH_TOKEN
  tokens can't start Remote Control.
- Claude Code binary lives in persistent /config so it self-updates without image rebuilds.
- Identical host/container paths so paths Claude reports or writes into templates are real host paths.
- New apps get created as Unraid XML templates (`my-<name>.xml` in templates-user), not raw
  `docker run`, so they stay editable in the Unraid GUI.
- Default permission mode stays `default` (approve on phone). Docker socket = root-equivalent;
  mounting it read-only does NOT restrict the API.

## Unverified assumptions to check on first real run
- `Bash(cmd:*)` permission rule syntax still accepted by current Claude Code.
- Unraid's docker.sock group ownership (entrypoint handles any GID, including 0).
- Whether Unraid's Template repositories box accepts the repo URL or needs the raw XML URL.
- Whether `claude remote-control` behaves well long-term under tmux without an attached client.

Docs: https://code.claude.com/docs/en/remote-control
