#!/usr/bin/env bash
# Runs on every container start: set up Git/GitHub/GitLab, put the configuration
# from /opt/sandbox/config into the volumes, then run CMD.
set -euo pipefail

CFG=/opt/sandbox/config
mkdir -p "$CLAUDE_CONFIG_DIR" "$HERMES_HOME" "$HOME/.cache" "$HOME/.local/bin" "$HOME/.npm-global"
mkdir -p "${XDG_RUNTIME_DIR:-/tmp/hermes-runtime}" && chmod 0700 "${XDG_RUNTIME_DIR:-/tmp/hermes-runtime}"
mkdir -p /workspace/.worktrees

# seed <source> <target>: only create if missing (or SEED_OVERWRITE=1)
seed() {
  if [ -f "$1" ] && { [ ! -e "$2" ] || [ "${SEED_OVERWRITE:-0}" = "1" ]; }; then
    install -D -m 0600 "$1" "$2"
  fi
}

# ---------------------------------------------------------------- Git
git config --global init.defaultBranch main
git config --global pull.rebase true
git config --global push.autoSetupRemote true
git config --global fetch.prune true
git config --global --replace-all safe.directory '*'
if [ -n "${GIT_USER_NAME:-}" ]; then git config --global user.name "$GIT_USER_NAME"; fi
if [ -n "${GIT_USER_EMAIL:-}" ]; then git config --global user.email "$GIT_USER_EMAIL"; fi

# GitHub: git over HTTPS authenticates through gh (GH_TOKEN)
if [ -n "${GH_TOKEN:-}" ]; then
  host="${GH_HOST:-github.com}"
  git config --global --unset-all "credential.https://${host}.helper" 2>/dev/null || true
  git config --global --add "credential.https://${host}.helper" ""
  git config --global --add "credential.https://${host}.helper" "!/usr/bin/gh auth git-credential"
  # SSH URLs (git@github.com:...) -> HTTPS; there are no SSH keys in the container
  git config --global "url.https://${host}/.insteadOf" "git@${host}:"
fi

# GitLab: git over HTTPS with GITLAB_TOKEN (glab reads GITLAB_TOKEN/GITLAB_HOST itself)
if [ -n "${GITLAB_TOKEN:-}" ]; then
  host="${GITLAB_HOST:-gitlab.com}"; host="${host#https://}"; host="${host%/}"
  git config --global --unset-all "credential.https://${host}.helper" 2>/dev/null || true
  git config --global --add "credential.https://${host}.helper" ""
  # shellcheck disable=SC2016  # expanded by git at runtime, not here
  git config --global --add "credential.https://${host}.helper" \
    '!f() { test "$1" = get && echo username=oauth2 && echo "password=${GITLAB_TOKEN}"; }; f'
  git config --global "url.https://${host}/.insteadOf" "git@${host}:"
fi

# ---------------------------------------------------------------- Claude Code
# Policy + CLAUDE.md come as managed settings from /etc/claude-code (read-only).
# The user settings.json stays writable in the volume.
seed "$CFG/claude-user/settings.json" "$CLAUDE_CONFIG_DIR/settings.json"

# ---------------------------------------------------------------- Hermes Agent
# Policy comes from $HERMES_MANAGED_DIR (read-only). Initial config once:
seed "$CFG/hermes/config.yaml" "$HERMES_HOME/config.yaml"
hcfg="$HERMES_HOME/config.yaml"

# Hermes' skill discovery reads only the user config (not the managed policy):
# make sure the shared skills are always in there.
yq -i '.skills.external_dirs = ((.skills.external_dirs // []) + ["/opt/sandbox/config/skills"] | unique)' "$hcfg"

# Bundled Hermes skills (the official image does this in its init hook)
( cd /tmp && /opt/hermes/.venv/bin/python /opt/hermes/tools/skills_sync.py >/dev/null 2>&1 ) || true

# Pre-approve the managed guard hook (first-use consent), so "hermes hooks doctor" is green
# and the hook fires from the very first command. HERMES_ACCEPT_HOOKS=1 is the runtime fallback.
( cd /tmp && /opt/hermes/.venv/bin/python -P -c '
import site, sys
site.addsitedir("/opt/hermes/.venv/lib/python3.14/site-packages"); sys.path.insert(0, "/opt/hermes")
from hermes_cli.config import load_config
from agent.shell_hooks import register_from_config
register_from_config(load_config(), accept_hooks=True)
' >/dev/null 2>&1 ) || true

# SOUL.md = role + house rules (from $HERMES_HOME Hermes only loads SOUL.md globally).
# Regenerated on every start - edit config/hermes/SOUL.md or config/AGENTS.md instead.
{ cat "$CFG/hermes/SOUL.md"; echo; cat "$CFG/AGENTS.md"; } > "$HERMES_HOME/SOUL.md"

# Mirror provider keys from the sandbox .env into $HERMES_HOME/.env.
# Only the marked block is managed; entries from "hermes setup" are kept.
henv="$HERMES_HOME/.env"
touch "$henv"; chmod 0600 "$henv"
sed -i '/^# >>> sandbox-managed/,/^# <<< sandbox-managed/d' "$henv"
{
  echo "# >>> sandbox-managed (from the sandbox .env, rewritten on every start)"
  if [ -n "${HERMES_OPENROUTER_API_KEY:-}" ]; then echo "OPENROUTER_API_KEY=${HERMES_OPENROUTER_API_KEY}"; fi
  if [ -n "${HERMES_ANTHROPIC_API_KEY:-}" ]; then echo "ANTHROPIC_API_KEY=${HERMES_ANTHROPIC_API_KEY}"; fi
  if [ -n "${HERMES_OPENAI_API_KEY:-}" ]; then echo "OPENAI_API_KEY=${HERMES_OPENAI_API_KEY}"; fi
  echo "# <<< sandbox-managed"
} >> "$henv"

# Model from the sandbox .env (only if set)
if [ -n "${HERMES_PROVIDER:-}" ]; then yq -i '.model.provider = strenv(HERMES_PROVIDER)' "$hcfg"; fi
if [ -n "${HERMES_MODEL:-}" ]; then yq -i '.model.default = strenv(HERMES_MODEL)' "$hcfg"; fi
if [ -n "${HERMES_BASE_URL:-}" ]; then yq -i '.model.base_url = strenv(HERMES_BASE_URL)' "$hcfg"; fi

exec "$@"
