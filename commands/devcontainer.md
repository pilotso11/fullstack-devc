---
name: devcontainer
description: Set up a standard devcontainer configuration in the current project. Creates .devcontainer/devcontainer.json with standard mounts, SSH, GH CLI, and Claude config. Optionally commits and pushes to main.
arguments:
  - name: push
    description: "Pass 'push' to commit and push to main after creating the devcontainer"
    required: false
---

# Devcontainer Setup Command

Generate a `.devcontainer/devcontainer.json` in the current project using the standard development container configuration.

## Process

### Step 1: Gather Project Info

1. Determine project name from the current working directory basename
2. Detect the project's primary language/stack by checking for the presence of:
   - `go.mod` or `*.go` files → Go project
   - `package.json` → Node/TypeScript project
   - `requirements.txt`, `pyproject.toml`, `setup.py` → Python project
   - `Cargo.toml` → Rust project
   - Multiple languages detected → fullstack
3. Ask the user to confirm the detected stack, or specify if detection is wrong
4. Ask: "Include gcloud config mount? (y/n)"
5. Ask: "Any ports to forward? (comma-separated, or 'none')"
6. Ask: "Any project-specific environment variables to add to containerEnv? (or 'none')"

### Step 2: Determine VS Code Extensions

Based on the detected stack, select extensions:

**Always include:**
- `esbenp.prettier-vscode`
- `eamodio.gitlens`
- `GitHub.copilot`

**Go projects — add:**
- `golang.go`

**TypeScript/Node projects — add:**
- `dbaeumer.vscode-eslint`
- `biomejs.biome`
- `bradlc.vscode-tailwindcss`

**Python projects — add:**
- `ms-python.python`
- `ms-python.vscode-pylance`

**Rust projects — add:**
- `rust-lang.rust-analyzer`

**Fullstack (Go + TS) — add both Go and TypeScript sets.**

### Step 3: Generate devcontainer.json

Create `.devcontainer/devcontainer.json` with this structure. Use the gathered info to fill in the template:

```json
{
  "name": "<project-name>",
  "image": "pilotso11/fullstack-devc:latest",

  "hostRequirements": {
    "cpus": 2,
    "memory": "4gb"
  },

  "customizations": {
    "vscode": {
      "settings": {
        "editor.formatOnSave": true
      },
      "extensions": [
        "<detected extensions from Step 2>"
      ]
    }
  },

  "mounts": [
    "source=<project-name>-claude,target=/home/developer/.claude,type=volume",
    "source=<project-name>-pi,target=/home/developer/.pi,type=volume",
    "source=${localEnv:HOME}/.config/gh,target=/home/developer/.config/gh,type=bind",
    "source=/run/host-services/ssh-auth.sock,target=/ssh-agent,type=bind"
  ],

  "features": {
    "ghcr.io/devcontainers/features/common-utils:2": {
      "installZsh": true,
      "installOhMyZsh": true,
      "upgradePackages": true
    }
  },

  "containerEnv": {
    "TZ": "Europe/London"
  },

  "remoteEnv": {
    "SSH_AUTH_SOCK": "/ssh-agent",
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "true"
  },

  "overrideCommand": false,

  "postCreateCommand": "sudo mkdir -p /home/developer/.ssh && sudo chown developer:developer /home/developer/.ssh && ssh-keyscan github.com >> /home/developer/.ssh/known_hosts 2>/dev/null; true",
  "postStartCommand": "sudo chown -R developer:developer /home/developer/.claude /home/developer/.pi /home/developer/.config/gh /home/developer/.ssh 2>/dev/null; true",

  "remoteUser": "developer"
}
```

**Claude config mount — do not change to a bind mount:** The `~/.claude` mount is
a **named volume**, not `source=${localEnv:HOME}/.claude,...`. Host and container
have different `$HOME` (`/Users/<you>` vs `/home/developer`), and Claude Code
persists absolute plugin paths; a shared bind mount lets the container poison the
host's plugin config with `/home/developer/...` paths (`cache-miss` on the host)
and hands the Linux container macOS-built LSP binaries. Substitute the project
name into the volume source: `"source=<project-name>-claude,..."`. Authored config
(CLAUDE.md, settings.json, agents, commands) is carried in via the user's VS Code
`dotfiles.repository`; plugins re-install from `settings.json` `enabledPlugins`.

**pi config mount:** `~/.pi` follows the same named-volume pattern as `~/.claude`
(`source=<project-name>-pi,target=/home/developer/.pi`). pi keeps its settings,
sessions, installed packages, and model catalogs under `~/.pi/agent/`; a named
volume keeps that state container-local and persistent across rebuilds. Do not
bind-mount the host's `~/.pi`.

**Customization rules:**
- If the user opted **yes to gcloud**, add this mount to the `"mounts"` array:
  ```
  "source=${localEnv:HOME}/.config/gcloud,target=/home/developer/.config/gcloud,type=bind"
  ```
  and append `/home/developer/.config/gcloud` to the `postStartCommand` chown list
- If the user specified **forwarded ports**, add a `"forwardPorts": [...]` field
- If the user specified **containerEnv** vars, merge them into the `"containerEnv"` object alongside `"TZ"`
- For **Go projects**, add these VS Code settings:
  ```json
  "go.useLanguageServer": true,
  "go.toolsManagement.autoUpdate": true,
  "go.lintTool": "golangci-lint",
  "go.lintOnSave": "package",
  "go.formatTool": "goimports",
  "[go]": { "editor.defaultFormatter": "golang.go" }
  ```
- For **TypeScript projects**, add:
  ```json
  "[typescript]": { "editor.defaultFormatter": "esbenp.prettier-vscode" }
  ```

### Step 4: Write the File

1. Create the `.devcontainer/` directory if it doesn't exist
2. Write the `devcontainer.json` file
3. If a `.gitignore` exists, verify it does NOT ignore `.devcontainer/` — if it does, warn the user

### Step 5: Optional Push to Main

If the user passed the `push` argument OR answers yes when asked "Commit and push to main?":

1. Verify the project is a git repository (if not, run `git init`)
2. Stage only the `.devcontainer/devcontainer.json` file
3. Commit with message: `chore: add devcontainer configuration`
4. Push to main: `git push origin main`
5. If push fails (e.g., no remote), inform the user and suggest setting up a remote

If the user did not pass `push` and declines, just confirm the file was created.

### Step 6: Summary

Print a summary of what was created:
- Image used
- Mounts configured (Claude + pi named volumes, GH CLI, SSH agent forwarding)
- Extensions added
- Ports forwarded (if any)
- Environment variables set (if any)
- Whether it was pushed to main

Then print a **First use** note:
```
**First use:** The container's ~/.claude is a named volume (container-local),
not a bind mount of the host — this keeps the container's plugins, transcripts,
and auth separate so it can never write container paths back into your host
config. Credentials also live in the host Keychain and don't transfer. The first
time you open the devcontainer, run:

  claude login
  gh auth login
  pi        # then /login to select a provider (or set ANTHROPIC_API_KEY)

The named volume persists these across rebuilds, so it's a one-time step per
volume (per project).

To carry your authored Claude config (CLAUDE.md, settings.json, agents,
commands) into the container, keep it in a dotfiles repo and set in your VS Code
user settings:  "dotfiles.repository": "<you>/claude-dotfiles". Plugins
re-install automatically from settings.json's enabledPlugins list.
```
