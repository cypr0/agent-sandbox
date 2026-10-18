# shellcheck shell=bash
# Interactive shell in the sandbox (loaded via /etc/bash.bashrc)
[ -n "${PS1:-}" ] || return 0

export EDITOR="${EDITOR:-nano}"
export HISTFILE="$HOME/.cache/bash_history"
export HISTSIZE=10000

# Prompt: [sandbox] dir (branch) $
__sandbox_branch() { git rev-parse --abbrev-ref HEAD 2>/dev/null | sed 's/.*/ (&)/'; }
PS1='\[\e[1;35m\][sandbox]\[\e[0m\] \[\e[1;34m\]\w\[\e[0;33m\]$(__sandbox_branch)\[\e[0m\] \$ '

alias ll='ls -lah'
alias k='kubectl'
alias g='git'

if [ -z "${SANDBOX_MOTD_SHOWN:-}" ]; then
  export SANDBOX_MOTD_SHOWN=1
  cat <<'EOF'

  Agent sandbox  -  projects live in /workspace
  ------------------------------------------------------------------
  claude                     start Claude Code (first time: /login)
  hermes                     start Hermes Agent (first time: hermes model)
  ticket help                create, approve and dispatch work items (GitHub + GitLab)
  devsecops-gate             lint/security gate for the current branch
  sandbox-doctor             check tokens, tools, logins and guardrails

  Skills (in claude and hermes):  /new-item  /plan-item  /implement-item  /review-pr  /write-docs

EOF
fi
