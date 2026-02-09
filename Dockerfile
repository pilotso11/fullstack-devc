FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install base dependencies
RUN apt-get update && apt-get install -y \
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
    && rm -rf /var/lib/apt/lists/*

# Install GitHub CLI
RUN mkdir -p /etc/apt/keyrings && \
    wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null && \
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null

# Install Python 3.13 via deadsnakes PPA (not in Ubuntu 24.04 default repos)
RUN add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && apt-get install -y \
    python3.13 \
    python3.13-dev \
    python3-pip \
    gh \
    && rm -rf /var/lib/apt/lists/*

# Set Python 3.13 as default
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.13 1 && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.13 1

# Install uv to system path
RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh

# Install Go 1.25 (latest patch) from official image
COPY --from=golang:1.25 /usr/local/go /usr/local/go
ENV PATH="/usr/local/go/bin:${PATH}"

# Install golangci-lint (latest version)
RUN curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b /usr/local/bin

# Install Python dev tools globally
RUN uv pip install --system \
    mypy \
    pytest \
    pytest-asyncio \
    pytest-cov \
    ruff

# Create non-root developer user with passwordless sudo
RUN useradd -m -s /bin/bash developer \
    && echo "developer ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER developer
ENV HOME=/home/developer
ENV GOPATH="/home/developer/go"
ENV PATH="/home/developer/.local/bin:/home/developer/.bun/bin:${GOPATH}/bin:${PATH}"

# Enable claude features
ENV CLAUDE_UNSAFE_MODE=true
ENV CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=true


# Install Bun (includes Node.js/TypeScript tooling)
RUN curl -fsSL https://bun.sh/install | bash

# Install Claude Code
RUN curl -fsSL https://claude.ai/install.sh | bash

# Create workspace directory
WORKDIR /workspace

# Keep container running
CMD ["sleep", "infinity"]
