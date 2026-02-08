# fullstack-devc

A polyglot development container with Python, Go, and TypeScript/JavaScript toolchains pre-installed.

## Included toolchains

| Language | Runtime | Package manager | Linter/formatter |
|----------|---------|-----------------|------------------|
| Python | 3.13 | `uv` | `ruff`, `mypy` |
| Go | 1.25 | native | `golangci-lint` |
| TypeScript/JS | Bun | `bun` | ESLint, Prettier |

Also includes: Git, Claude Code, Firebase CLI.

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

Add a `.devcontainer/devcontainer.json` to your project referencing the image:

```json
{
  "image": "pilotso11/fullstack-devc:latest"
}
```

Or use this repository's `.devcontainer/devcontainer.json` directly, which also configures VS Code extensions and port forwarding.

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
