FROM --platform=$BUILDPLATFORM ubuntu:24.04

ARG TARGETPLATFORM
ARG BUILDPLATFORM
ARG TARGETOS
ARG TARGETARCH

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
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install Python 3.13 via deadsnakes PPA (not in Ubuntu 24.04 default repos)
RUN add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && apt-get install -y \
    python3.13 \
    python3.13-dev \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*


# Set Python 3.13 as default
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.13 1 && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.13 1

# Install uv (fast Python package installer)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"

# Install Go 1.25 (latest patch) from official image
COPY --from=golang:1.25 /usr/local/go /usr/local/go
ENV PATH="/usr/local/go/bin:${PATH}"
ENV GOPATH="/root/go"
ENV PATH="${GOPATH}/bin:${PATH}"

# Install golangci-lint
RUN curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b /usr/local/bin v1.56.2

# Install Bun (includes Node.js/TypeScript tooling)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

# Install Claude Code
RUN curl -fsSL https://claude.ai/install.sh | bash

# Install Python dev tools globally using uv
RUN uv pip install --system \
    mypy \
    pytest \
    pytest-asyncio \
    pytest-cov \
    ruff

# Create workspace directory
WORKDIR /workspace

# Keep container running
CMD ["sleep", "infinity"]
