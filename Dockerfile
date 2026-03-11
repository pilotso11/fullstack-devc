# syntax=docker/dockerfile:1
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install base dependencies
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    wget \
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
    traceroute

# Set up all APT repositories in a single layer
RUN mkdir -p /etc/apt/keyrings /usr/share/keyrings && \
    # GitHub CLI
    wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null && \
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    # Google Cloud CLI
    wget -qO- https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee /etc/apt/sources.list.d/google-cloud-sdk.list > /dev/null && \
    # kubectl
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg && \
    chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list > /dev/null && \
    # PostgreSQL 17
    curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /etc/apt/keyrings/postgresql.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/postgresql.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
    # Python 3.13 via deadsnakes PPA (not in Ubuntu 24.04 default repos)
    add-apt-repository --no-update ppa:deadsnakes/ppa

# Install all additional APT packages in one layer
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    python3.13 \
    python3.13-dev \
    python3-pip \
    gh \
    google-cloud-cli \
    kubectl \
    postgresql-17 \
    postgresql-client-17

# Configure PostgreSQL 17 for container use (listen on all interfaces, allow remote auth)
# and install management scripts
RUN sed -i "s/^#listen_addresses.*/listen_addresses = '*'/" /etc/postgresql/17/main/postgresql.conf && \
    echo "host all all 0.0.0.0/0 scram-sha-256" >> /etc/postgresql/17/main/pg_hba.conf && \
    echo "host all all ::/0 scram-sha-256" >> /etc/postgresql/17/main/pg_hba.conf
COPY --chmod=755 scripts/pg-start scripts/pg-stop /usr/local/bin/

# Install AWS CLI v2
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then AWSARCH="x86_64"; else AWSARCH="aarch64"; fi && \
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${AWSARCH}.zip" -o /tmp/awscliv2.zip && \
    unzip -q /tmp/awscliv2.zip -d /tmp && \
    /tmp/aws/install && \
    rm -rf /tmp/awscliv2.zip /tmp/aws

# Install Go 1.25 (latest patch) from official image
COPY --from=golang:1.25 /usr/local/go /usr/local/go
ENV PATH="/usr/local/go/bin:${PATH}"

# Install Node.js 22 LTS via NodeSource
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/*

# Set Python 3.13 as default and install uv
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.13 1 && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.13 1 && \
    curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh

# Install golangci-lint (latest version)
RUN curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b /usr/local/bin

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

# Create non-root developer user with passwordless sudo
RUN useradd -m -s /bin/bash developer \
    && echo "developer ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Pre-create directories that devcontainer features may populate as root.
# This ensures correct ownership when features like Node.js write to ~/.npm.
RUN mkdir -p /home/developer/.npm /home/developer/.cache \
    && chown -R developer:developer /home/developer/.npm /home/developer/.cache

USER developer
ENV HOME=/home/developer
ENV GOPATH="/home/developer/go"
ENV PATH="/home/developer/.local/bin:/home/developer/.bun/bin:${GOPATH}/bin:${PATH}"

# Enable claude features
ENV CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=true

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

# Configure claude alias for convenience
RUN echo 'alias claude="claude --dangerously-skip-permissions"' >> ~/.bashrc

EXPOSE 5432

# Create workspace directory
WORKDIR /workspace

# Keep container running
CMD ["sleep", "infinity"]
