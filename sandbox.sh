#!/usr/bin/env bash
# Start and enter the agent sandbox (macOS/Linux). Compatible with bash 3.2.
#
#   ./sandbox.sh                 shell in the container (builds/starts if needed)
#   ./sandbox.sh claude [args]   start Claude Code directly
#   ./sandbox.sh hermes [args]   start Hermes Agent directly
#   ./sandbox.sh ticket [args]   ticket tool in the container
#   ./sandbox.sh gate [args]     devsecops-gate in the container
#   ./sandbox.sh doctor          check the setup
#   ./sandbox.sh build           rebuild the image
#   ./sandbox.sh update          rebuild incl. the latest Claude Code version
#   ./sandbox.sh status|logs|stop|down
#   ./sandbox.sh reset-state     delete logins/sessions/caches (volumes) - asks first
set -euo pipefail

cd "$(dirname "$0")"
SERVICE=sandbox

red()    { printf '\033[31m%s\033[0m\n' "$*" >&2; }
yellow() { printf '\033[33m%s\033[0m\n' "$*" >&2; }
green()  { printf '\033[32m%s\033[0m\n' "$*" >&2; }
die()    { red "✘ $*"; exit 1; }

# ---------------------------------------------------------------- container engine
if [ -n "${DOCKER:-}" ]; then :
elif command -v docker >/dev/null 2>&1; then DOCKER=docker
elif command -v podman >/dev/null 2>&1; then DOCKER=podman
else die "Neither Docker nor Podman found. Install: https://docs.docker.com/get-docker/"; fi
$DOCKER info >/dev/null 2>&1 || die "$DOCKER is not running (start Docker Desktop/OrbStack/the Podman machine)."
$DOCKER compose version >/dev/null 2>&1 || die "'$DOCKER compose' missing (Compose v2 required)."
compose() { $DOCKER compose "$@"; }

# ---------------------------------------------------------------- check .env
if [ ! -f .env ]; then
  cp .env.example .env
  chmod 600 .env
  yellow "→ Created .env from .env.example. Fill it in (at least GIT_USER_NAME, GIT_USER_EMAIL and GH_TOKEN"
  yellow "  and/or GITLAB_TOKEN), then run ./sandbox.sh again."
  exit 1
fi
# read .env without executing it as shell code
envval() { sed -n "s/^$1=//p" .env | tail -1 | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//"; }
[ -n "$(envval GH_TOKEN)$(envval GITLAB_TOKEN)" ] || yellow "! GH_TOKEN and GITLAB_TOKEN are empty - tickets and PRs/MRs will not work."
[ -n "$(envval GIT_USER_NAME)" ]  || yellow "! GIT_USER_NAME is empty - agent commits have no identity."
[ -n "$(envval GIT_USER_EMAIL)" ] || yellow "! GIT_USER_EMAIL is empty."
if [ "$(stat -f %Lp .env 2>/dev/null || stat -c %a .env 2>/dev/null)" != "600" ]; then
  chmod 600 .env && yellow "! Set permissions of .env to 600."
fi

ws="$(envval WORKSPACE_DIR)"; ws="${ws:-./workspace}"
mkdir -p "$ws" secrets

# use the host UID/GID in the image (matters on Linux for file ownership in the workspace)
export SANDBOX_UID="${SANDBOX_UID:-$(id -u)}"
export SANDBOX_GID="${SANDBOX_GID:-$(id -g)}"

# ---------------------------------------------------------------- provide the container
ensure_up() {
  local img; img="$(envval SANDBOX_IMAGE)"; img="${img:-agent-sandbox:local}"
  if ! $DOCKER image inspect "$img" >/dev/null 2>&1; then
    green "→ First start: building the image (takes a few minutes) ..."
    compose build
  fi
  if [ -z "$(compose ps -q --status running "$SERVICE" 2>/dev/null)" ]; then
    compose up -d --remove-orphans >/dev/null
  fi
}

tty_flags() { if [ -t 0 ] && [ -t 1 ]; then echo "-it"; else echo "-T"; fi; }
run_in() { local t; ensure_up; t="$(tty_flags)"; compose exec "$t" "$SERVICE" "$@"; }

case "${1:-shell}" in
  shell)       run_in bash ;;
  claude)      shift; run_in claude "$@" ;;
  hermes)      shift; run_in hermes "$@" ;;
  ticket)      shift; run_in ticket "$@" ;;
  gate)        shift; run_in devsecops-gate "$@" ;;
  doctor)      run_in sandbox-doctor ;;
  exec)        shift; run_in "$@" ;;
  build)       compose build --pull && compose up -d --force-recreate >/dev/null && green "✔ rebuilt and started" ;;
  update)      CACHE_BUST_AGENTS="$(date +%s)" compose build --pull && compose up -d --force-recreate >/dev/null \
                 && green "✔ updated" && run_in sh -c 'claude --version; hermes --version | head -1' ;;
  status)      compose ps ;;
  logs)        compose logs --tail 100 -f ;;
  stop)        compose stop ;;
  down)        compose down ;;
  reset-state)
    printf 'Delete all logins, sessions, Hermes memory and caches? [yes/N] '
    read -r a; [ "$a" = "yes" ] || exit 0
    compose down -v && green "✔ Volumes deleted. The workspace is untouched." ;;
  -h|--help|help) sed -n '2,15p' "$0" ;;
  *) die "Unknown command: $1 (./sandbox.sh help)" ;;
esac
