# unraid-claude

Claude Code in a Docker container for Unraid, running **Remote Control** so you can talk to it
from the Claude phone app (Code tab) or claude.ai/code. It can read logs, inspect containers,
fix app configs and write Unraid templates for new apps (Tdarr, the *arrs, etc.).

It signs in with your **Claude Pro/Max subscription**, so usage comes out of your plan limits,
not API credits. Remote Control doesn't work with API keys anyway.

> **Security:** the Docker socket gives this container effective root on your server, and anyone
> who can get into your Claude account can drive it. Turn on 2FA for your Claude account, leave
> `PERMISSION_MODE=default` (Claude asks on your phone before changing things), and keep
> appdata backups. Mounting the socket read-only does *not* limit what can be done through it;
> if you don't want Claude managing containers, remove that mapping.

---

## 1. Put this on GitHub (one time)

1. Create a new **public** GitHub repo named `unraid-claude`.
2. Replace the placeholder with your GitHub username (**lowercase**, GHCR requires it):
   ```bash
   grep -rl spikked27 . | xargs sed -i 's/spikked27/yourname/g'
   ```
   (macOS: `sed -i ''`)
3. Push:
   ```bash
   git init && git add . && git commit -m "Initial commit"
   git branch -M main
   git remote add origin https://github.com/yourname/unraid-claude.git
   git push -u origin main
   ```
4. Watch **Actions**: the workflow builds and pushes `ghcr.io/yourname/unraid-claude:latest`.
5. Make the image public: GitHub profile → **Packages** → `unraid-claude` → **Package settings** →
   **Change visibility** → Public. (Otherwise Unraid can't pull it without logging in.)

The image rebuilds on every push to `main` and weekly for security updates.

## 2. Install on Unraid

**Option A: Template repository (works right away, just like any other app template)**

1. **Docker** tab → **Add Container**.
2. Click **Template repositories** at the top, paste this on its own line, and **Save**:
   ```
   https://github.com/spikked27/unraid-claude
   ```
   If nothing shows up in the next step, use the direct template URL instead:
   `https://raw.githubusercontent.com/spikked27/unraid-claude/main/templates/claude-code.xml`
3. Back in **Add Container**, open the **Template** dropdown and choose **claude-code**.
4. Review the paths and click **Apply**.

**Option B: Community Apps (search "claude-code" in the Apps tab)**

This repo already contains everything CA requires (public repo, `LICENSE`, `ca_profile.xml`,
template in `templates/`). Submit it at https://ca.unraid.net/submit, sign in, paste the repo URL,
run **Validate** and **Scan**, and submit. Note that a CA listing is public: anyone can install it
and will file issues here.

Default mappings:

| Container path | Host path | Mode | Why |
|---|---|---|---|
| `/config` | `/mnt/user/appdata/claude-code` | rw | login, settings, workspace |
| `/var/run/docker.sock` | same | rw | manage containers |
| `/mnt/user` | same | **ro** | see shares/paths safely |
| `/mnt/user/appdata` | same | rw | fix app configs |
| `/boot/config/plugins/dockerMan/templates-user` | same | rw | write Unraid templates |
| `/var/log` | same | ro | syslog (advanced) |

Paths are identical inside and outside the container on purpose, so anything Claude tells
you (or puts in a template) is a real host path.

## 3. First-time setup

Docker tab → click the container icon → **Console**, then run:

```bash
claude-setup
```

It walks you through three steps:

1. **Sign in**: pick the Claude subscription option, open the URL on any device, paste the code back.
2. **Trust the workspace**: accept the prompt, then `/exit`.
3. **Remote Control**: answer `y` if asked, press **Space** for a QR code, then detach with `Ctrl-b` then `d`.

On your phone: Claude app → **Code** → the session named **Unraid** (green dot = online).

Optional but handy: in `claude-shell`, run `/config` and turn on the push-notification options
so your phone pings you when Claude finishes or needs approval.

## Everyday use

Just ask from your phone, for example:

- "Why does Sonarr keep restarting? Check its logs."
- "Set up Tdarr with a node using my Intel GPU, media in /mnt/user/media, transcode cache on the cache pool."
- "Which containers are using the most RAM?"

New containers are created as Unraid templates in `templates-user`, then you add them via
**Docker → Add Container** so they stay editable in the GUI. The rules Claude follows are in
`/mnt/user/appdata/claude-code/workspace/CLAUDE.md`; edit that file to change its behavior,
and Claude will add notes about your server there over time.

Helper commands (in the container console):

| Command | What it does |
|---|---|
| `claude-setup` | re-run login / setup |
| `claude-attach` | view the Remote Control screen (detach: `Ctrl-b`, `d`) |
| `claude-shell` | a normal interactive Claude session in the console |

## Updating

- **Claude Code** updates itself; restarting the container applies the latest version.
- **The image** (tools, Debian, Docker CLI): push changes to this repo, wait for the Action,
  then **Docker → Check for Updates** in Unraid.
- **The template**: edit `templates/claude-code.xml` and push. New installs get the updated template.
  Your installed container keeps its own saved settings (`my-claude-code.xml`), so new template
  fields only appear if you add the container again from the template.

Your login and settings live in `/config`, so updating or recreating the container keeps them.

## Settings

| Variable | Default | Notes |
|---|---|---|
| `RC_SESSION_NAME` | `Unraid` | name in the app's session list |
| `PERMISSION_MODE` | `default` | `acceptEdits` auto-approves file edits |
| `RC_EXTRA_ARGS` | *(empty)* | extra `claude remote-control` flags, e.g. `--verbose` |
| `PUID` / `PGID` | `99` / `100` | Unraid's nobody:users |

Read-only commands (`docker ps`, `docker logs`, `docker inspect`, `df`...) are pre-approved in
`/config/.claude/settings.json` so you aren't tapping "approve" constantly; everything else asks.
Destructive prune/volume-removal commands are denied. Treat those rules as convenience, not a
security boundary.

## Troubleshooting

- **Session not showing in the app**: run `claude-attach` and read the error. Re-run `claude-setup` if it mentions login.
- **"requires claude.ai subscription auth"**: an API key is set somewhere. The entrypoint strips the usual env vars; check `/config/.claude/settings.json` for an `env` block or `apiKeyHelper`.
- **"requires a full-scope login token"**: don't use `claude setup-token`; use `claude-setup` (it runs `claude auth login`).
- **Can't see containers**: make sure the Docker socket path is mapped; check `docker ps` in the console.
- **More detail**: set `RC_EXTRA_ARGS=--verbose`, or run `claude doctor` in the console.

Docs: https://code.claude.com/docs/en/remote-control
