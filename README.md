# fullstack-devc

A polyglot development container with Python, Go, and TypeScript/JavaScript toolchains pre-installed.

## Included toolchains

| Language | Runtime | Package manager | Linter/formatter |
|----------|---------|-----------------|------------------|
| Python | 3.13 | `uv` | `ruff`, `mypy` |
| Go | 1.25 | native | `golangci-lint` |
| TypeScript/JS | Bun | `bun` | ESLint, Prettier |

Also includes: Git, GitHub CLI (`gh`), Google Cloud CLI (`gcloud`), AWS CLI (`aws`), kubectl, jq, vim, nano, Claude Code.

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
  "forwardPorts": [3000, 5173, 8000, 8080]
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

### Forwarded ports

| Port | Service |
|------|---------|
| 3000 | Frontend |
| 5173 | Vite dev server |
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

## Building

```bash
# Build and push multi-platform image
make docker

# Local build only
docker build -t fullstack-devc:local .
```
