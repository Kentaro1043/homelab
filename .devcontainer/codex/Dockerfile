FROM ghcr.io/astral-sh/uv:0.11.21 AS uv

FROM mcr.microsoft.com/devcontainers/javascript-node:24-bookworm

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG CODEX_VERSION=0.147.0
ARG CONTEXT7_VERSION=4.0.2
ARG NIX_VERSION=2.34.1
ARG SERENA_REVISION=7067f566c0c8f33ae05cd2a37ffe3c0a2f774347
ARG CODEX_SKILLS_REVISION=49f948faa9258a0c61caceaf225e179651397431

LABEL org.opencontainers.image.source="https://github.com/Kentaro1043/homelab"

COPY --from=uv /uv /uvx /usr/local/bin/

# Debian security updates must remain installable without rebuilding pinned package lists.
# hadolint ignore=DL3008
RUN apt-get update \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install --yes --no-install-recommends \
        bubblewrap \
        build-essential \
        ca-certificates \
        curl \
        gh \
        git \
        jq \
        openssh-client \
        python3 \
        python3-venv \
        poppler-utils \
        ripgrep \
    && rm -rf /var/lib/apt/lists/*

RUN npm install --global --omit=dev \
        "@openai/codex@${CODEX_VERSION}" \
        "@upstash/context7-mcp@${CONTEXT7_VERSION}" \
    && npm cache clean --force

ENV UV_TOOL_DIR=/opt/uv-tools
ENV UV_TOOL_BIN_DIR=/usr/local/bin

RUN uv tool install \
        "git+https://github.com/oraios/serena.git@${SERENA_REVISION}" \
    && uv venv /opt/codex-python \
    && uv pip install --python /opt/codex-python/bin/python \
        pdfplumber==0.11.10 \
        pypdf==6.15.0 \
        reportlab==5.0.0

RUN git clone --filter=blob:none https://github.com/openai/skills.git /tmp/codex-skills \
    && git -C /tmp/codex-skills checkout "${CODEX_SKILLS_REVISION}" \
    && install -d -o node -g node /opt/codex-skills \
    && for skill in \
        gh-address-comments \
        gh-fix-ci \
        pdf \
        security-best-practices \
        security-threat-model \
        yeet; do \
        cp -a "/tmp/codex-skills/skills/.curated/${skill}" /opt/codex-skills/; \
    done \
    && chown -R node:node /opt/codex-skills \
    && rm -rf /tmp/codex-skills

RUN install -d -o node -g node /nix /home/node/.config/nix

USER node

RUN git config --global user.name Kentaro1043 \
    && git config --global user.email 71170923+Kentaro1043@users.noreply.github.com \
    && git config --global init.defaultBranch main \
    && git config --global pull.rebase false

RUN curl --fail --location --silent --show-error \
        "https://releases.nixos.org/nix/nix-${NIX_VERSION}/install" \
        | sh -s -- --no-daemon \
    && printf '%s\n' \
        'experimental-features = nix-command flakes' \
        'sandbox = false' \
        > /home/node/.config/nix/nix.conf

ENV PATH="/home/node/.nix-profile/bin:/opt/codex-python/bin:${PATH}"
ENV CODEX_HOME=/home/node/.codex

WORKDIR /workspace/homelab
