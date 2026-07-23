# Feed Digester — factory image. Runs the Editor supervisor loop (scripts/editor_entrypoint.sh),
# which clones the repo on first boot and builds/runs the product from within.
FROM python:3.11-slim

# Tools the factory needs at runtime: git + gh (PR workflow), make, and the Claude Code CLI.
RUN apt-get update && apt-get install -y --no-install-recommends \
      git curl ca-certificates coreutils \
 && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list \
 && apt-get update && apt-get install -y --no-install-recommends gh \
 && rm -rf /var/lib/apt/lists/*

# Claude Code CLI (OAuth session is provided via the mounted ~/.claude at runtime).
RUN curl -fsSL https://claude.ai/install.sh | bash \
 && ln -sf /root/.local/bin/claude /usr/local/bin/claude || true

# Non-root user — required for TWO reasons:
#   1. Full-autonomy posture: Claude Code refuses --dangerously-skip-permissions as root, and the
#      entrypoint launches the Editor with that flag, so a root container cannot run the factory.
#   2. The mounted OAuth dir is owned by the host UID (see CLAUDE.md "How to run" / Permissions posture).
RUN useradd -m -u 1000 factory
USER factory
WORKDIR /app

# The entrypoint clones the actual project on first boot; only the bootstrap script is baked in.
COPY --chown=factory:factory scripts/editor_entrypoint.sh /app/scripts/editor_entrypoint.sh
RUN chmod +x /app/scripts/editor_entrypoint.sh

ENTRYPOINT ["/app/scripts/editor_entrypoint.sh"]
