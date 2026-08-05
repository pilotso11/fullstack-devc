# syntax=docker/dockerfile:1
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install base dependencies
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    build-essential \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common \
    sudo \
    unzip \
    zip \
    jq \
    vim \
    nano \
    perl \
    rsync \
    openssh-client \
    less \
    tree \
    net-tools \
    iputils-ping \
    traceroute \
    fzf \
    zsh \
    man-db

# Set up all APT repositories in a single layer
RUN mkdir -p /etc/apt/keyrings /usr/share/keyrings && \
    # GitHub CLI
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null && \
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    # kubectl (always included — small binary, useful with any cluster)
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg && \
    chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list > /dev/null

# Install all additional APT packages in one layer
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    python3-pip \
    gh \
    kubectl

# Install Go 1.25 (latest patch) from official image
COPY --from=golang:1.25 /usr/local/go /usr/local/go
ENV PATH="/usr/local/go/bin:${PATH}"

# Install Python 3.13 from official image (no PPA needed, cross-platform compatible)
COPY --from=python:3.13 /usr/local/bin/python3.13 /usr/local/bin/python3.13
COPY --from=python:3.13 /usr/local/lib/python3.13 /usr/local/lib/python3.13
COPY --from=python:3.13 /usr/local/include/python3.13 /usr/local/include/python3.13
COPY --from=python:3.13 /usr/local/lib/libpython3.13.so.1.0 /usr/local/lib/libpython3.13.so.1.0
RUN ln -sf libpython3.13.so.1.0 /usr/local/lib/libpython3.13.so && ldconfig

# Install Node.js 22 LTS via NodeSource
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/*

# Set Python 3.13 as default and install uv
RUN update-alternatives --install /usr/bin/python python /usr/local/bin/python3.13 1 && \
    update-alternatives --install /usr/bin/python3 python3 /usr/local/bin/python3.13 1 && \
    curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh

# Install golangci-lint (pinned version, direct download — avoids install.sh sbom checksum bug)
ARG GOLANGCI_LINT_VERSION=2.12.1
RUN ARCH=$(dpkg --print-architecture) && \
    curl -fsSLo /tmp/golangci-lint.tar.gz \
      "https://github.com/golangci/golangci-lint/releases/download/v${GOLANGCI_LINT_VERSION}/golangci-lint-${GOLANGCI_LINT_VERSION}-linux-${ARCH}.tar.gz" && \
    tar -xzf /tmp/golangci-lint.tar.gz -C /tmp && \
    mv "/tmp/golangci-lint-${GOLANGCI_LINT_VERSION}-linux-${ARCH}/golangci-lint" /usr/local/bin/golangci-lint && \
    rm -rf /tmp/golangci-lint.tar.gz "/tmp/golangci-lint-${GOLANGCI_LINT_VERSION}-linux-${ARCH}"

# Install Python dev tools globally
RUN --mount=type=cache,target=/root/.cache/uv \
    uv pip install --system \
    mypy \
    pytest \
    pytest-asyncio \
    pytest-cov \
    ruff

# Install Playwright browser dependencies (Chromium)
# These system libraries are needed for headless browser testing
RUN npx playwright install-deps chromium

# Install git-delta for better diff output
ARG GIT_DELTA_VERSION=0.18.2
RUN ARCH=$(dpkg --print-architecture) && \
    curl -fsSLo "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" "https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
    dpkg -i "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
    rm "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb"

# Persistent shell history directory (mount a volume to /commandhistory to persist across rebuilds)
RUN mkdir /commandhistory && touch /commandhistory/.bash_history /commandhistory/.zsh_history

# Create non-root developer user with passwordless sudo
RUN useradd -m -s /bin/zsh developer \
    && echo "developer ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
    && chown -R developer:developer /commandhistory

# Pre-create directories that devcontainer features may populate as root.
# This ensures correct ownership when features like Node.js write to ~/.npm.
RUN mkdir -p /home/developer/.npm /home/developer/.cache \
    && chown -R developer:developer /home/developer/.npm /home/developer/.cache

USER developer
ENV HOME=/home/developer
ENV GOPATH="/home/developer/go"
ENV PATH="/home/developer/.local/bin:/home/developer/.bun/bin:${GOPATH}/bin:${PATH}"

# Set devcontainer marker and enable claude features
ENV DEVCONTAINER=true
ENV CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=true

# Persistent history config
ENV HISTFILE=/commandhistory/.zsh_history
ENV SHELL=/bin/zsh

# Set up zsh with oh-my-zsh, fzf, and persistent history
ARG ZSH_IN_DOCKER_VERSION=1.2.0
RUN sh -c "$(curl -fsSL https://github.com/deluan/zsh-in-docker/releases/download/v${ZSH_IN_DOCKER_VERSION}/zsh-in-docker.sh)" -- \
    -p git \
    -p fzf \
    -a "export HISTFILE=/commandhistory/.zsh_history" \
    -a "export HISTSIZE=10000" \
    -a "export SAVEHIST=10000" \
    -a "setopt SHARE_HISTORY" \
    -a "[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ] && source /usr/share/doc/fzf/examples/key-bindings.zsh" \
    -a "[ -f /usr/share/doc/fzf/examples/completion.zsh ] && source /usr/share/doc/fzf/examples/completion.zsh" \
    -x

# Install Bun (includes Node.js/TypeScript tooling)
RUN curl -fsSL https://bun.sh/install | bash

# Install Playwright Chromium browser for component testing
RUN npx playwright install chromium

# Install AI coding assistants via bun (npm compatible)
RUN bun install -g @openai/codex @github/copilot

# Create wrapper scripts for AI tools to use bunx
RUN mkdir -p /home/developer/.local/bin && \
    echo '#!/bin/bash\nbunx --bun codex "$@"' > /home/developer/.local/bin/codex && \
    echo '#!/bin/bash\nbunx --bun copilot "$@"' > /home/developer/.local/bin/copilot && \
    chmod +x /home/developer/.local/bin/codex /home/developer/.local/bin/copilot

# Install Claude Code
RUN curl -fsSL https://claude.ai/install.sh | bash

# Install claude-switch (toggle between Claude API backends)
RUN curl -sSL https://raw.githubusercontent.com/pilotso11/claude-switch/main/install.sh | bash

# Install pi coding agent (https://pi.dev) — uses the system Node.js (>=22.19)
RUN sudo npm install -g --ignore-scripts @earendil-works/pi-coding-agent

# Configure claude alias and git-delta for convenience
RUN echo 'alias claude="claude --dangerously-skip-permissions"' >> ~/.zshrc && \
    echo 'alias claude="claude --dangerously-skip-permissions"' >> ~/.bashrc && \
    git config --global core.pager delta && \
    git config --global interactive.diffFilter "delta --color-only" && \
    git config --global delta.navigate true && \
    git config --global delta.side-by-side true && \
    git config --global merge.conflictstyle diff3 && \
    git config --global diff.colorMoved default

# Switch back to root so devcontainer features can install packages.
# Consumers should set "remoteUser": "developer" in their devcontainer.json.
USER root

# Create workspace directory with the expected runtime ownership
RUN mkdir -p /workspace && chown developer:developer /workspace
WORKDIR /workspace

# Keep container running
CMD ["sleep", "infinity"]
