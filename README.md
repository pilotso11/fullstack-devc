# fullstack-devc

A polyglot development container with Python, Go, and TypeScript/JavaScript toolchains pre-installed.

## Included toolchains

| Language | Runtime | Package manager | Linter/formatter |
|----------|---------|-----------------|------------------|
| Python | 3.13 | `uv` | `ruff`, `mypy` |
| Go | 1.25 | native | `golangci-lint` |
| TypeScript/JS | Bun | `bun` | ESLint, Prettier |

Also includes: Git, GitHub CLI (`gh`), kubectl, jq, vim, nano, Claude Code, claude-switch, OpenAI Codex CLI (`codex`), GitHub Copilot CLI (`copilot`).

Google Cloud CLI (`gcloud`), AWS CLI (`aws`), and kubectl are available in the `-cloud` image variant.

PostgreSQL 17 is available as a separate image variant — see [Image variants](#image-variants) below.

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
    "source=myproject-claude,target=/home/developer/.claude,type=volume",
    "source=${localEnv:HOME}/.config/gcloud,target=/home/developer/.config/gcloud,type=bind"
  ],
  "postCreateCommand": "bash -c '[ -f requirements.txt ] && uv pip install --system -r requirements.txt; [ -f go.mod ] && go mod download; [ -f package.json ] && bun install; true'",
  "forwardPorts": [3000, 5173, 5432, 8000, 8080]
}
```

### Claude Code config: use a named volume, not a bind mount

The container's `~/.claude` uses a **named volume** so the container keeps its
own plugins, transcripts, and auth. **Do not** bind-mount the host's `~/.claude`
(`source=${localEnv:HOME}/.claude,...`): the host and container have different
`$HOME` values (`/Users/<you>` vs `/home/developer`), and Claude Code's plugin
subsystem persists **absolute** install paths. A shared directory lets the
container write `/home/developer/...` paths back into the host's config, which
then fail to load on the host (`cache-miss` / "plugin not cached"). Named-volume
isolation avoids this, and also avoids handing the Linux container macOS-built
LSP plugin binaries.

To carry your **authored** config (`CLAUDE.md`, `settings.json`, agents,
commands) into every container, keep it in a dotfiles repo and set this once in
your **VS Code user settings**:

```jsonc
"dotfiles.repository": "<you>/claude-dotfiles",
"dotfiles.installCommand": "install.sh"
```

VS Code clones it into each container and your install script symlinks the
authored files into the volume-backed `~/.claude`. Plugins re-install
automatically from the `enabledPlugins` / `extraKnownMarketplaces` lists in
`settings.json`, so the plugin *set* travels without the platform-specific
binaries.

### Dependency auto-installation

On container creation, dependencies are installed automatically based on files present in the workspace:

- `requirements.txt` → `uv pip install --system -r requirements.txt`
- `go.mod` → `go mod download`
- `package.json` → `bun install`

### Services

PostgreSQL 17 is available in the `-pg` image variant. It is not started automatically — start it when needed.

#### PostgreSQL 17 (requires `-pg` variant)

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

## Image variants

Three image variants are published:

| Variant | Tag suffix | PostgreSQL | gcloud / AWS CLI |
|---------|-----------|------------|-----------------|
| Base (default) | *(none)* | ✗ | ✗ |
| Cloud | `-cloud` | ✗ | ✓ |
| Postgres | `-pg` | ✓ | ✗ |

Use the base image (`pilotso11/fullstack-devc:latest`) for most projects — it includes kubectl for managing any cluster. Use the `-cloud` variant when you additionally need Google Cloud CLI or AWS CLI. Use the `-pg` variant when you need a bundled PostgreSQL 17 server.

## Image tags

| Tag | Source |
|-----|--------|
| `latest` | Latest build from `main` or weekly scheduled rebuild (base, includes kubectl) |
| `latest-cloud` | Latest build from `main` or weekly scheduled rebuild (with gcloud/AWS CLI) |
| `latest-pg` | Latest build from `main` or weekly scheduled rebuild (with PostgreSQL 17) |
| `main` | Most recent push to `main` |
| `main-cloud` | Most recent push to `main` (with gcloud/AWS CLI) |
| `main-pg` | Most recent push to `main` (with PostgreSQL 17) |
| `1.2.3` / `1.2` / `1` | Semver release from a `v*` git tag |
| `1.2.3-cloud` / `1.2-cloud` / `1-cloud` | Semver release with gcloud/AWS CLI |
| `1.2.3-pg` / `1.2-pg` / `1-pg` | Semver release with PostgreSQL 17 |
| `sha-<hash>` | Specific commit |
| `sha-<hash>-cloud` | Specific commit with gcloud/AWS CLI |
| `sha-<hash>-pg` | Specific commit with PostgreSQL 17 |

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
# Build and push multi-platform base image (no PostgreSQL, no cloud CLIs)
make docker

# Build and push multi-platform cloud variant (gcloud, kubectl, AWS CLI)
make docker-cloud

# Build and push multi-platform postgres variant
make docker-pg

# Local build only (base)
docker build -t fullstack-devc:local .

# Local build only (cloud variant)
docker build --build-arg INCLUDE_CLOUD=true -t fullstack-devc:local-cloud .

# Local build only (postgres variant)
docker build --build-arg INCLUDE_POSTGRES=true -t fullstack-devc:local-pg .
```
