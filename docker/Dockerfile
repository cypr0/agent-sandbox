# syntax=docker/dockerfile:1
# Agent sandbox: Claude Code + Hermes Agent with tools for
# Kubernetes/GitOps, Ansible, PowerShell, shell, Go, web, GitHub/GitLab and DevSecOps.
# Builds for linux/arm64 (Apple Silicon) and linux/amd64.

ARG UV_VERSION=0.13.1
ARG HERMES_VERSION=v0.22.2
FROM ghcr.io/astral-sh/uv:${UV_VERSION} AS uv

# Hermes Agent: take code + bundled runtime (Python 3.14, Node, Chromium) from the
# official image - the way upstream intends it for containers.
FROM nousresearch/hermes-agent:${HERMES_VERSION} AS hermes
RUN rm -rf /opt/hermes/uv-cache \
 && ln -sfn "$(cat /etc/hermes/agent-browser-executable-path)" /opt/hermes/agent-browser-chrome

FROM debian:trixie-slim

ARG TARGETARCH
ARG TZ=Europe/Berlin
ARG USER_UID=1000
ARG USER_GID=1000

# ---- versions (pinned on purpose; to update: change the number + ./sandbox.sh build)
ARG GO_VERSION=1.27.2
ARG KUBECTL_VERSION=1.37.1
ARG HELM_VERSION=4.3.1
ARG KUSTOMIZE_VERSION=5.8.3
ARG FLUX_VERSION=2.9.6
ARG KUBECONFORM_VERSION=0.8.0
ARG KUBE_LINTER_VERSION=0.8.3
ARG SOPS_VERSION=3.13.3
ARG YQ_VERSION=4.54.1
ARG MISE_VERSION=2026.10.13
ARG GITLEAKS_VERSION=8.30.1
ARG TRIVY_VERSION=0.76.0
ARG HADOLINT_VERSION=2.15.1
ARG ACTIONLINT_VERSION=1.7.12
ARG PWSH_VERSION=7.6.7
ARG SEMGREP_VERSION=1.181.0
ARG FLUX_LOCAL_VERSION=8.4.0
ARG ZIZMOR_VERSION=1.31.1
# agent harness: "latest"/"stable" or a fixed version
ARG CLAUDE_CODE_VERSION=stable
ARG EXTRA_APT_PACKAGES=

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=${TZ}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# ------------------------------------------------------------ base
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl wget gnupg \
      git git-lfs openssh-client \
      bash-completion less nano vim-tiny tmux \
      procps psmisc lsof iputils-ping dnsutils netcat-openbsd \
      ripgrep fd-find jq bsdextrautils unzip zip xz-utils zstd tar file tree \
      build-essential pkg-config make \
      shellcheck \
      python3 python3-venv \
      tzdata locales \
      ${EXTRA_APT_PACKAGES} \
 && ln -sf /usr/bin/fdfind /usr/local/bin/fd \
 && ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime && echo "${TZ}" > /etc/timezone \
 && rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------ GitHub CLI
RUN mkdir -p /etc/apt/keyrings \
 && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /etc/apt/keyrings/githubcli.gpg \
 && chmod go+r /etc/apt/keyrings/githubcli.gpg \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list \
 && apt-get update && apt-get install -y --no-install-recommends gh \
 && rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------ Go
ENV PATH=/usr/local/go/bin:${PATH}
RUN curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${TARGETARCH}.tar.gz" | tar -xz -C /usr/local \
 && go version

# ------------------------------------------------------------ uv (Python toolchain)
COPY --from=uv /uv /uvx /usr/local/bin/
ENV UV_PYTHON_INSTALL_DIR=/opt/uv/python \
    UV_TOOL_DIR=/opt/uv/tools \
    UV_TOOL_BIN_DIR=/usr/local/bin \
    UV_LINK_MODE=copy

# ------------------------------------------------------------ Kubernetes / GitOps / security (binaries)
RUN set -eux; \
    A="${TARGETARCH}"; \
    case "$A" in amd64) GL=x64; TV=64bit; HL=x86_64; KL=""; MS=x64;; arm64) GL=arm64; TV=ARM64; HL=arm64; KL=_arm64; MS=arm64;; esac; \
    cd /tmp; \
    curl -fsSLo /usr/local/bin/kubectl "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${A}/kubectl"; \
    curl -fsSL "https://get.helm.sh/helm-v${HELM_VERSION}-linux-${A}.tar.gz" | tar -xz --strip-components=1 -C /usr/local/bin "linux-${A}/helm"; \
    curl -fsSL "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${KUSTOMIZE_VERSION}/kustomize_v${KUSTOMIZE_VERSION}_linux_${A}.tar.gz" | tar -xz -C /usr/local/bin kustomize; \
    curl -fsSL "https://github.com/fluxcd/flux2/releases/download/v${FLUX_VERSION}/flux_${FLUX_VERSION}_linux_${A}.tar.gz" | tar -xz -C /usr/local/bin flux; \
    curl -fsSL "https://github.com/yannh/kubeconform/releases/download/v${KUBECONFORM_VERSION}/kubeconform-linux-${A}.tar.gz" | tar -xz -C /usr/local/bin kubeconform; \
    curl -fsSL "https://github.com/stackrox/kube-linter/releases/download/v${KUBE_LINTER_VERSION}/kube-linter-linux${KL}.tar.gz" | tar -xz -C /usr/local/bin kube-linter; \
    curl -fsSLo /usr/local/bin/sops "https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.linux.${A}"; \
    curl -fsSLo /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_${A}"; \
    curl -fsSLo /usr/local/bin/mise "https://github.com/jdx/mise/releases/download/v${MISE_VERSION}/mise-v${MISE_VERSION}-linux-${MS}"; \
    curl -fsSL "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_${GL}.tar.gz" | tar -xz -C /usr/local/bin gitleaks; \
    curl -fsSLO "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-${TV}.tar.gz"; \
    curl -fsSL "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_checksums.txt" | grep " trivy_${TRIVY_VERSION}_Linux-${TV}.tar.gz\$" | sha256sum -c -; \
    tar -xzf "trivy_${TRIVY_VERSION}_Linux-${TV}.tar.gz" -C /usr/local/bin trivy; rm -f trivy_*.tar.gz; \
    curl -fsSLo /usr/local/bin/hadolint "https://github.com/hadolint/hadolint/releases/download/v${HADOLINT_VERSION}/hadolint-linux-${HL}"; \
    curl -fsSL "https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}/actionlint_${ACTIONLINT_VERSION}_linux_${A}.tar.gz" | tar -xz -C /usr/local/bin actionlint; \
    chmod 0755 /usr/local/bin/*; \
    for b in kubectl helm kustomize flux kubeconform kube-linter sops yq mise gitleaks trivy hadolint actionlint; do command -v "$b" >/dev/null; done; \
    kubectl version --client; helm version --short; flux --version; trivy --version | head -1

# ------------------------------------------------------------ PowerShell + PSScriptAnalyzer + Pester
RUN set -eux; \
    case "${TARGETARCH}" in amd64) P=x64;; arm64) P=arm64;; esac; \
    apt-get update; \
    icu="$(apt-cache search --names-only '^libicu[0-9]+$' | awk '{print $1}' | sort -V | tail -1)"; \
    apt-get install -y --no-install-recommends "$icu" libssl3t64 || apt-get install -y --no-install-recommends "$icu" libssl3; \
    rm -rf /var/lib/apt/lists/*; \
    mkdir -p /opt/microsoft/powershell/7; \
    curl -fsSL "https://github.com/PowerShell/PowerShell/releases/download/v${PWSH_VERSION}/powershell-${PWSH_VERSION}-linux-${P}.tar.gz" | tar -xz -C /opt/microsoft/powershell/7; \
    chmod +x /opt/microsoft/powershell/7/pwsh; ln -s /opt/microsoft/powershell/7/pwsh /usr/local/bin/pwsh; \
    POWERSHELL_TELEMETRY_OPTOUT=1 pwsh -NoLogo -NoProfile -Command \
      "Set-PSRepository PSGallery -InstallationPolicy Trusted; Install-Module PSScriptAnalyzer,Pester -Scope AllUsers -Force -ErrorAction Stop"; \
    pwsh -NoLogo -NoProfile -Command '(Get-Module -ListAvailable PSScriptAnalyzer,Pester).Name'

# ------------------------------------------------------------ Python-based tools (one venv each via uv)
RUN set -eux; \
    uv tool install "ansible-core"; \
    uv tool install "ansible-lint"; \
    uv tool install "yamllint"; \
    uv tool install "semgrep==${SEMGREP_VERSION}"; \
    uv tool install "flux-local==${FLUX_LOCAL_VERSION}"; \
    uv tool install "zizmor==${ZIZMOR_VERSION}"; \
    uv tool install "pre-commit"; \
    chmod -R a+rX /opt/uv; \
    ansible --version | head -1; ansible-lint --version | head -1; semgrep --version; flux-local --help >/dev/null

# ------------------------------------------------------------ Hermes Agent
# Code is read-only in the image (/opt/hermes), state lives in the volume $HERMES_HOME.
# As in the official image: python3/node/npm come from Hermes' bundled runtime
# (Python 3.14, Node 26) - the Hermes venv expects its interpreter in /usr/local/bin.
COPY --from=hermes /opt/hermes /opt/hermes
ENV HERMES_RUNTIME_DIR=/opt/hermes/tools \
    HERMES_PYTHON=/opt/hermes/.venv/bin/python \
    PLAYWRIGHT_BROWSERS_PATH=/opt/hermes/tools \
    HERMES_WEB_DIST=/opt/hermes/hermes_cli/web_dist \
    HERMES_TUI_DIR=/opt/hermes/ui-tui \
    AGENT_BROWSER_EXECUTABLE_PATH=/opt/hermes/agent-browser-chrome \
    PYTHONDONTWRITEBYTECODE=1
RUN apt-get update && apt-get install -y --no-install-recommends \
      libatomic1 libffi8 \
      libasound2t64 libatk-bridge2.0-0t64 libatk1.0-0t64 libatspi2.0-0t64 libcairo2 libcups2t64 libdbus-1-3 \
      libgbm1 libglib2.0-0t64 libnspr4 libnss3 libpango-1.0-0 libx11-6 libxcb1 libxcomposite1 libxdamage1 \
      libxext6 libxfixes3 libxkbcommon0 libxrandr2 fonts-dejavu-core \
 && rm -rf /var/lib/apt/lists/* \
 && T=/opt/hermes/tools \
 && ln -sf "$(ls -d "$T"/python-*/bin/python3 | head -1)" /usr/local/bin/python3 \
 && ln -sf "$(ls -d "$T"/node-*/bin/node | head -1)" /usr/local/bin/node \
 && ln -sf "$(ls -d "$T"/npm-*/bin/npm | head -1)" /usr/local/bin/npm \
 && ln -sf "$(ls -d "$T"/npm-*/bin/npx | head -1)" /usr/local/bin/npx \
 && ln -sf "$(ls -d "$T"/ffmpeg-*/bin/ffmpeg | head -1)" /usr/local/bin/ffmpeg \
 && ln -sf /opt/hermes/.venv/bin/hermes /usr/local/bin/hermes \
 && python3 --version && node --version && npm --version && HERMES_HOME=/tmp/hermes-build hermes --version && rm -rf /tmp/hermes-build

# ------------------------------------------------------------ GitLab CLI (glab)
ARG GLAB_VERSION=1.123.0
RUN set -eux; \
    base="https://gitlab.com/api/v4/projects/gitlab-org%2Fcli/packages/generic/glab/${GLAB_VERSION}"; \
    f="glab_${GLAB_VERSION}_linux_${TARGETARCH}.tar.gz"; \
    cd /tmp; curl -fsSLo "$f" "$base/$f"; \
    curl -fsSL "$base/checksums.txt" | grep " ${f}\$" | sha256sum -c -; \
    tar -xzf "$f" -C /usr/local bin/glab; rm -f "$f"; \
    glab --version

# ------------------------------------------------------------ user
RUN set -eux; \
    if getent passwd "${USER_UID}" >/dev/null; then userdel -r "$(getent passwd "${USER_UID}" | cut -d: -f1)" || true; fi; \
    if ! getent group "${USER_GID}" >/dev/null; then groupadd -g "${USER_GID}" dev; fi; \
    useradd -l -m -u "${USER_UID}" -g "${USER_GID}" -s /bin/bash dev; \
    mkdir -p /workspace /opt/sandbox \
             /home/dev/.claude /home/dev/.hermes /home/dev/.cache /home/dev/go \
             /home/dev/.local/bin /home/dev/.local/share/mise /home/dev/.config /home/dev/.secrets /home/dev/.npm-global; \
    chown -R "${USER_UID}:${USER_GID}" /workspace /home/dev

COPY --chmod=0755 entrypoint.sh /usr/local/bin/sandbox-entrypoint
COPY --chmod=0644 profile.sh /etc/profile.d/zz-sandbox.sh
RUN echo '[ -f /etc/profile.d/zz-sandbox.sh ] && . /etc/profile.d/zz-sandbox.sh' >> /etc/bash.bashrc

USER dev
ENV HOME=/home/dev \
    GOPATH=/home/dev/go \
    CLAUDE_CONFIG_DIR=/home/dev/.claude \
    HERMES_HOME=/home/dev/.hermes \
    DISABLE_AUTOUPDATER=1 \
    MISE_TRUSTED_CONFIG_PATHS=/workspace \
    NPM_CONFIG_PREFIX=/home/dev/.npm-global \
    XDG_RUNTIME_DIR=/tmp/hermes-runtime \
    HERMES_MANAGED_DIR=/opt/sandbox/config/hermes/managed \
    HERMES_WRITE_SAFE_ROOT=/workspace:/tmp:/home/dev/.hermes \
    HERMES_ACCEPT_HOOKS=1 \
    TERMINAL_HOME_MODE=real \
    PATH=/opt/sandbox/bin/shims:/opt/sandbox/bin:/home/dev/.local/bin:/home/dev/.npm-global/bin:/home/dev/go/bin:/usr/local/go/bin:/usr/local/bin:/usr/bin:/bin:/home/dev/.local/share/mise/shims

# ------------------------------------------------------------ Claude Code (native installer, as dev)
ARG CACHE_BUST_AGENTS=0
RUN curl -fsSL https://claude.ai/install.sh | bash -s -- "${CLAUDE_CODE_VERSION}" \
 && /home/dev/.local/bin/claude --version

WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/sandbox-entrypoint"]
CMD ["sleep", "infinity"]
