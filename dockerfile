FROM haskell:9.6.4 as builder

ENV RESOLVER lts-22.17
ENV LC_ALL=C.UTF-8

# Install hledger and related tools
RUN stack setup --resolver=$RESOLVER && \
    stack install --resolver=$RESOLVER \
    hledger-lib-1.40 \
    hledger-1.40 \
    hledger-ui-1.40 \
    hledger-web-1.40

# Final stage
FROM debian:bookworm-slim
ENV DEBIAN_FRONTEND=noninteractive
ENV LC_ALL=C.UTF-8

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    pipx \
    neovim \
    libgmp10 \
    libtinfo6 \
    git \
    curl \
    ripgrep \
    fd-find \
    powerline \
    fonts-powerline \
    nodejs \
    npm \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy hledger binaries from builder
COPY --from=builder /root/.local/bin/hledger* /usr/local/bin/

# Install ledger-autosync using pipx
RUN pipx install ledger-autosync && \
    ln -s /root/.local/bin/ledger-autosync /usr/local/bin/ledger-autosync

# Install latest neovim from GitHub
RUN curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz && \
    tar xzf nvim-linux64.tar.gz && \
    cp -r nvim-linux64/* /usr/ && \
    rm -rf nvim-linux64*

# Create config directories
RUN mkdir -p /root/.config /root/.local/share/nvim

# Create entrypoint script
COPY <<-'EOF' /usr/local/bin/entrypoint.sh
#!/bin/bash
set -e

NVIM_CONFIG_DIR="/root/.config/nvim"
KICKSTART_URL="${KICKSTART_URL:-https://github.com/nvim-lua/kickstart.nvim.git}"

if [ ! -d "$NVIM_CONFIG_DIR" ]; then
    echo "Initializing Neovim config from $KICKSTART_URL"
    git clone "$KICKSTART_URL" "$NVIM_CONFIG_DIR"
    nvim --headless "+Lazy! sync" +qa || true
fi

exec "${@:-bash}"
EOF

RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /data
VOLUME ["/data", "/root/.config", "/root/.local/share/nvim"]

ENV EDITOR=nvim
ENV PATH="/root/.local/bin:$PATH"

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 CMD hledger --version || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
