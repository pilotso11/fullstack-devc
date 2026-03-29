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
    "source=${localEnv:HOME}/.claude,target=/home/developer/.claude,type=bind",
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
  "postStartCommand": "sudo chown -R developer:developer /home/developer/.claude /home/developer/.config/gh 2>/dev/null; true",

  "remoteUser": "developer"
}
```

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
- Mounts configured (Claude, GH CLI, SSH agent forwarding)
- Extensions added
- Ports forwarded (if any)
- Environment variables set (if any)
- Whether it was pushed to main
