# fullstack-devc

A polyglot development container with Python, Go, and TypeScript/JavaScript toolchains pre-installed.

## Included toolchains

| Language | Runtime | Package manager | Linter/formatter |
|----------|---------|-----------------|------------------|
| Python | 3.13 | `uv` | `ruff`, `mypy` |
| Go | 1.25 | native | `golangci-lint` |
| TypeScript/JS | Bun | `bun` | ESLint, Prettier |

Also includes: Git, GitHub CLI (`gh`), Google Cloud CLI (`gcloud`), AWS CLI (`aws`), kubectl, PostgreSQL 17, jq, vim, nano, Claude Code, claude-switch, OpenAI Codex CLI (`codex`), GitHub Copilot CLI (`copilot`).

## Platform support

The image is built for `linux/amd64` and `linux/arm64`.

| Host | Platform used |
|------|--------------|
| Linux (x86_64) | `linux/amd64` |
| Linux (ARM64) | `linux/arm64` |
| macOS (Apple Silicon) | `linux/arm64` via Docker Desktop |
| macOS (Intel) | `linux/amd64` via Docker Desktop |
| Windows | `linux/amd64` via Docker Desktop / WSL2 |

## Usage

### As a VS Code dev container

Add a `.devcontainer/devcontainer.json` to your project:

```json
{
  "name": "My Project",
  "image": "pilotso11/fullstack-devc:latest",
  "remoteUser": "developer",
  "mounts": [
    "source=${localEnv:HOME}/.claude,target=/home/developer/.claude,type=bind,consistency=cached",
    "source=${localEnv:HOME}/.config/gcloud,target=/home/developer/.config/gcloud,type=bind"
  ],
  "postCreateCommand": "bash -c '[ -f requirements.txt ] && uv pip install --system -r requirements.txt; [ -f go.mod ] && go mod download; [ -f package.json ] && bun install; true'",
  "forwardPorts": [3000, 5173, 5432, 8000, 8080]
}
```

The `mounts` configuration shares your host's `~/.claude` directory with the container, persisting Claude Code settings, API keys, and session history across all projects. Alternatively, use a named volume for per-project isolation:

```json
"mounts": [
  "source=myproject-claude-settings,target=/home/developer/.claude,type=volume"
]
```

### Dependency auto-installation

On container creation, dependencies are installed automatically based on files present in the workspace:

- `requirements.txt` → `uv pip install --system -r requirements.txt`
- `go.mod` → `go mod download`
- `package.json` → `bun install`

### Services

Optional services are installed but not started automatically. Start them when needed.

#### PostgreSQL 17

Start and stop with:

```bash
pg-start   # Initialize (first run) and start PostgreSQL
pg-stop    # Stop PostgreSQL
```

Configured via environment variables (set on the container via `docker run -e` or `containerEnv` in devcontainer.json):

| Variable | Default | Description |
|----------|---------|-------------|
| `DATABASE_USER` | `postgres` | PostgreSQL role name |
| `DATABASE_PASSWORD` | `postgres` | Role password |
| `DATABASE_URL` | `postgresql://postgres:postgres@localhost:5432/postgres` | Connection string for your application |

`pg-start` creates the role and database from these variables on first run. Storage is ephemeral — data is lost when the container is removed.

### Forwarded ports

| Port | Service |
|------|---------|
| 3000 | Frontend |
| 5173 | Vite dev server |
| 5432 | PostgreSQL |
| 8000 | Backend API |
| 8080 | General HTTP |

## Image tags

| Tag | Source |
|-----|--------|
| `latest` | Latest build from `main` or weekly scheduled rebuild |
| `main` | Most recent push to `main` |
| `1.2.3` / `1.2` / `1` | Semver release from a `v*` git tag |
| `sha-<hash>` | Specific commit |

The image is rebuilt every Monday at 02:00 UTC with no layer cache, ensuring the latest Ubuntu security patches, Go patch release, python patches, uv, and Claude Code update are always included in `latest`.

## Claude Code Plugin

This repo includes a Claude Code plugin that provides a `/devcontainer` slash command. When invoked in any project, it generates a `.devcontainer/devcontainer.json` tailored to the project's detected language stack.

### Installing the plugin

Add this repo as a plugin marketplace, then install the plugin:

```bash
claude plugin marketplace add https://github.com/pilotso11/fullstack-devc
claude plugin install fullstack-devc
```

Or from a local clone:

```bash
git clone https://github.com/pilotso11/fullstack-devc.git
claude plugin marketplace add /path/to/fullstack-devc
claude plugin install fullstack-devc
```

Restart Claude Code after installing. The `/devcontainer` command will be available in any project.

### What `/devcontainer` does

- Detects your project's language stack (Go, TypeScript, Python, Rust, or fullstack)
- Asks about gcloud mounts, port forwarding, and environment variables
- Generates a `.devcontainer/devcontainer.json` with appropriate VS Code extensions, mounts (Claude, GH CLI, SSH agent), and settings
- Optionally commits and pushes the config to main

## Building

```bash
# Build and push multi-platform image
make docker

# Local build only
docker build -t fullstack-devc:local .
```
