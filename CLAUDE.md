# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A Railway deployment template for [AlphaClaw](https://github.com/iamsteveng/alphaclaw) — a wrapper that runs OpenClaw 24/7 with a setup UI, webhook proxy, and GitHub-backed persistent state. The template is a thin Docker+npm shim; almost all application logic lives in the `@chrysb/alphaclaw` npm package sourced from `github:iamsteveng/alphaclaw`.

## Key files

| File | Purpose |
|------|---------|
| `Dockerfile` | Builds the Railway image: installs alphaclaw + Claude Code CLI, sets `ALPHACLAW_ROOT_DIR=/data` |
| `railway.toml` | Railway config: Dockerfile builder, health check at `/health`, persistent volume at `/data` |
| `package.json` | Single dependency — alphaclaw pinned to a specific commit hash (never `#main`) |
| `docker-compose.yml` | Local dev mirror of the Railway setup, mounts `openclaw-data:/data` |

## Local dev

```bash
npm run dev        # docker compose up --build
npm run dev:stop   # docker compose down
npm run dev:clean  # docker compose down -v  (wipes volume)
npm run dev:logs   # follow logs
npm run dev:shell  # bash into container
```

Requires a `.env` file with at least `SETUP_PASSWORD=<value>` for the setup UI.

## Architecture

```
Internet → :3000 (Express, alphaclaw)
├── /                     Setup UI (password-gated)
├── /api/status|env|...   Setup API endpoints
├── /api/* (else)         Proxy → OpenClaw gateway :18789
├── /webhook/*            Proxy → gateway (adds Bearer token)
├── /openclaw             Proxy → gateway control UI
└── WebSocket             Proxy → gateway
```

Persistent state lives entirely on the Railway volume at `/data`:
- `/data/.openclaw/` — git repo synced to GitHub (config, skills, memory, workspace)
- `/data/.env` — env vars managed via Setup UI (never committed with raw secrets)

## Deploying to Railway

### First-time deploy (new project)

```bash
# 1. Login
railway login

# 2. Create a new project and link this directory
railway init

# 3. Set the required variable before first deploy
railway variables --set "SETUP_PASSWORD=<your-password>"

# 4. Deploy (Railway builds via Dockerfile, streams logs)
railway up
```

After deploy, visit the Railway-assigned URL to complete the setup UI wizard (AI keys, GitHub repo, channel tokens).

### Redeploy an existing linked project (alphaclaw updated)

The standard redeploy path is to update the alphaclaw commit hash — this both pulls in the new code and triggers Railway to rebuild:

```bash
# 1. Get latest commit
git ls-remote https://github.com/iamsteveng/alphaclaw.git HEAD

# 2. Update package.json hash and regenerate lock file
#    Edit: "github:iamsteveng/alphaclaw#<new-sha>"
npm install --prefer-online

# 3. Verify lock file has the new commit
grep "resolved" package-lock.json | grep alphaclaw

# 4. Commit and push — Railway redeploys automatically on push to main
git add package.json package-lock.json
git commit -m "Update lock to alphaclaw <short-sha> (<description>)"
git push origin main
```

To force a manual redeploy without any code change:

```bash
railway up --detach
```

### Link this directory to an existing Railway project

```bash
railway link          # interactive picker
# or
railway link --project <PROJECT_ID> --service <SERVICE_NAME>
```

### Useful CLI commands

```bash
railway logs          # tail live deploy/runtime logs
railway status        # show linked project, environment, service
railway open          # open project dashboard in browser
railway deployment list --json   # list recent deployments and their status
```

## Railway volume

The volume `alphaclaw-data` mounts at `/data`. Size changes must be done via the Railway dashboard — the CLI (`railway volume update`) does not support resizing.
