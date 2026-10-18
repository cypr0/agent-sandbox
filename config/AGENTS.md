# Agent sandbox house rules

These rules apply to every agent in this sandbox (Claude Code, Hermes and all
subagents). Rules inside a repository (`AGENTS.md`, `CLAUDE.md`, README,
`.editorconfig`, linter configs) take precedence - except for the language and
security rules below, which always apply.

## Language (always)

- **Talk to the user in the language they use** (usually German).
- **Everything that is persisted is written in English**, no matter which language the input was in:
  issue titles and bodies, comments, plans, PR/MR titles and descriptions, review comments,
  commit messages, branch names, code, code comments, log messages, docs and READMEs in repos.
- Translate German input faithfully into clear, natural English. Keep identifiers, paths,
  commands, code, quoted error messages and log output unchanged.
- If an existing issue, comment or PR/MR you are working on is not in English, rewrite its
  title/body in English when you take it over (`/plan-item` does this). The original stays in the
  edit history of GitHub/GitLab.

## Environment

- Docker container (Debian), user `dev`, no root, no sudo, no Docker socket.
- All projects are Git clones under `/workspace/<repo>`. If a repo is missing: `ticket clone <ref>`.
- Parallel work on several tickets uses Git worktrees under `/workspace/.worktrees/<repo>/<issue>-<slug>`.
- Forges: **GitHub** (`gh`) and **GitLab** (`glab`, gitlab.com or self-hosted). `ticket` is the
  forge-neutral layer for everything that writes (state, comments, plan, PR/MR) - see
  `/opt/sandbox/config/playbooks/forge-cli.md`. A GitHub "pull request" is a GitLab "merge request".
- Available tools: git, gh, glab, kubectl, helm, kustomize, flux, flux-local, kubeconform, kube-linter,
  sops (without keys), yq, jq, mise, go, node/npm, uv/python, pwsh (PSScriptAnalyzer, Pester),
  ansible-core, ansible-lint, yamllint, shellcheck, hadolint, actionlint, zizmor, gitleaks, trivy, semgrep.
- Project-specific tool versions come from the repo's `.mise.toml`: run `mise install` in the repo.
- Missing tool: install it project-locally (mise, uv, npm, `go install`). Note tools that are needed
  permanently as a proposal for the sandbox Dockerfile; never install via `curl | sh`.
- Bind dev servers to `0.0.0.0`. Ports 3000, 5173 and 8080 are reachable on the host at `http://localhost:<port>`.

## Way of working: tickets, not shouting across the room

1. Work items are issues (GitHub or GitLab). Their state is a label:
   `agent/todo` → `agent/planned` → `agent/approved` → `agent/in-progress` → `agent/in-review`;
   `agent/blocked` when a human has to answer.
2. Plan first (`/plan-item`), then implement (`/implement-item`). Only approved work is implemented:
   label `agent/approved` or an explicit approval by the user in the chat.
3. For bigger ad-hoc requests in the chat, first offer to turn them into a ticket with `/new-item`.
4. Every change goes through a branch `agent/<issue>-<short-slug>` and a PR/MR. Only a human merges.
5. Documentation is part of the change: update the affected docs in the same PR/MR. To document a whole
   repo or app use `/write-docs` (README, LICENSE, SECURITY.md, CONTRIBUTING.md, AGENTS.md, docs/ARCHITECTURE.md,
   docs/OPERATIONS.md; templates in `/opt/sandbox/templates/docs/`). License texts only via `docs-license`.
6. Before every PR/MR the DevSecOps pipeline runs: `devsecops-gate` plus reviews by the subagents
   (see skill `implement-item` and `/opt/sandbox/config/playbooks/devsecops-review.md`).
7. Prefer asking over guessing: a few targeted questions (three at most) beat an implemented assumption.
   Assumptions that remain are written down visibly in the plan or PR/MR.

## Security rules (always)

- Never commit or push to `main`/`master`, no force push (except `--force-with-lease` on your own
  `agent/*` branch), never delete branches, tags, releases or issues.
- Never merge or approve PRs/MRs, never change repository settings, rulesets, protected branches,
  CI/CD variables, secrets, deploy keys or webhooks.
- Secrets: never in plain text in Git. Kubernetes secrets only as SOPS-encrypted `*.sops.yaml` or as
  ExternalSecret. There is no age key in the sandbox - encrypting/decrypting is done by the human.
  Never read or print `.env` files, keys or token files.
- Kubernetes is GitOps (Flux): cluster changes only through the repo. `kubectl`, `flux`, `talosctl`,
  `helm` are read-only (`get`, `describe`, `logs`, `diff`, `template`, `--dry-run`).
- Ansible against real hosts only with `--check`/`--syntax-check`. Real runs are started by the human.
- Never execute scripts straight from the internet (`curl | sh`). Dependencies with fixed versions,
  container images with fixed tags (Renovate-compatible, ideally with digest).
- If `sandbox-guard` blocks a command, do not work around it - note the reason in the ticket/PR and
  propose the step to the human.

## Conventions

- Conventional Commits: `type(scope): subject` (e.g. `feat(paperless): add redis network policy`).
  The body explains why. Every commit ends with `Refs #<issue>`.
- Small, self-contained commits. Run the repo's formatters/hooks (lefthook, yamlfmt, `just` recipes, ...).
- Kubernetes apps follow the pattern of the existing apps in the repo (folder layout, `ks.yaml`,
  HelmRelease/app-template, network policies, ExternalSecrets). Read a comparable app first, then write.
- Shell: `set -euo pipefail`, shellcheck-clean. PowerShell: `Set-StrictMode -Version Latest`,
  `$ErrorActionPreference = 'Stop'`, PSScriptAnalyzer-clean, Pester tests. Ansible: idempotent,
  FQCN modules, `ansible-lint`-clean, `no_log` for secrets.
- Websites: accessible (semantic HTML, alt texts, contrast), no external trackers/CDNs without asking,
  think about a Content Security Policy.
