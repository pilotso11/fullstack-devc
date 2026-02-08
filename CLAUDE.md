# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

This is a **Docker-based polyglot development container** definition. The "product" is the container image itself — changes here affect the toolchain available to all projects that use this container.

Published to DockerHub as `pilotso11/fullstack-devc` via GitHub Actions on push to `main` or semver tags.

## Build Commands

```bash
# Build and push multi-platform image (requires Docker Buildx and DockerHub login)
make docker

# Local build only (no push)
docker buildx build --platform linux/amd64,linux/arm64 -t pilotso11/fullstack-devc:dev .

# Build for local architecture only (faster for testing)
docker build -t fullstack-devc:local .
```

## Container Architecture

- **Base**: Ubuntu 24.04
- **Workspace**: `/workspace` (bind-mounted from host)
- **Runs as**: root
- **Entrypoint**: `sleep infinity` (persistent background container)

### Included Runtimes & Tools

| Language | Runtime | Package Manager | Linter/Formatter |
|----------|---------|-----------------|------------------|
| Python | 3.13 | `uv` | `ruff`, `mypy` |
| Go | 1.25 | native | `golangci-lint` v1.56.2 |
| TypeScript/JS | Bun | `bun` | ESLint, Prettier |

Claude Code is also pre-installed at `/root/.claude/bin`.

### Port Forwarding (devcontainer)

- `3000` — Frontend
- `5173` — Vite dev server
- `8000` — Backend API
- `8080` — General HTTP

## Dependency Installation Pattern

The `postCreateCommand` in `devcontainer.json` auto-installs dependencies based on what's present in the workspace:

```bash
[ -f requirements.txt ] && uv pip install --system -r requirements.txt
[ -f go.mod ]           && go mod download
[ -f package.json ]     && bun install
```

This means the container is project-agnostic — drop in any polyglot project and dependencies install automatically.

## CI/CD

`.github/docker.yml` builds and pushes on:
- Push to `main` → tagged as branch name + SHA
- Semver tags (`v*`) → tagged as `major.minor.patch`, `major.minor`, `major`
- PRs → build only, no push

Requires `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` secrets in the GitHub repo.

## Multi-Platform Builds

The Dockerfile uses `$TARGETARCH` to select the correct Go binary for each platform. Docker Buildx handles this automatically when building with `--platform linux/amd64,linux/arm64`.
