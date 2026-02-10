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
    && rm -rf /var/lib/apt/lists/*

# Install GitHub CLI
RUN mkdir -p /etc/apt/keyrings && \
    wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null && \
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null

# Install Google Cloud CLI
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
    wget -qO- https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg

# Install kubectl
RUN curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg && \
    chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

# Install Python 3.13 via deadsnakes PPA (not in Ubuntu 24.04 default repos)
RUN add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && apt-get install -y \
    python3.13 \
    python3.13-dev \
    python3-pip \
    gh \
    google-cloud-cli \
    kubectl \
    && rm -rf /var/lib/apt/lists/*

# Install AWS CLI v2
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then \
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"; \
    elif [ "$ARCH" = "aarch64" ]; then \
        curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"; \
    fi && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf awscliv2.zip aws

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
ENV CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=true


# Install Bun (includes Node.js/TypeScript tooling)
RUN curl -fsSL https://bun.sh/install | bash

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

# Create workspace directory
WORKDIR /workspace

# Keep container running
CMD ["sleep", "infinity"]
