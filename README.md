# Agent sandbox: Claude Code + Hermes with a ticket workflow and a DevSecOps pipeline

A Docker sandbox in which **Claude Code** and **Hermes Agent** work under the same
rules, skills, review roles and guardrails, on **GitHub and GitLab**. Work items are
**issues**. The agent **plans** each one in dialogue with you and you **approve** it.
The agent then implements it, runs it through a **DevSecOps pipeline** (scanners plus
review subagents) and submits a **pull/merge request**. Only you merge.

Inspired by the c't/heise article "Schluss mit Vibe-Coding" (see [Acknowledgements](#acknowledgements))
and extended with:
- Hermes as a second agent, plus GitLab
- Kubernetes/GitOps, Ansible and PowerShell tooling
- a shared security gate
- guardrails that apply to both agents
- an **English-only rule** for everything that is persisted

```
  You (GitHub/GitLab web or app, ticket CLI, /new-item)      - German input is fine
        │  issue  [agent/todo]                               - stored in English
        ▼
  /plan-item ──▶ plan as issue comment  [agent/planned]
        │                        │
        │        ticket approve  ▼  (or "approved" in the chat)
        │                   [agent/approved]
        ▼
  /implement-item ─▶ worktree + branch agent/<nr>-<slug>          [agent/in-progress]
        │   ├─ implementation + tests, Conventional Commits
        │   ├─ A  devsecops-gate        (gitleaks, SOPS, kubeconform, trivy, semgrep, ...)
        │   ├─ B  review subagents      (code · security · k8s · iac, parallel, fresh context)
        │   └─ C  fixes + gate again
        ▼
  pull/merge request with DevSecOps report                        [agent/in-review]
        │
        ▼
  You: read, understand, merge  ─▶  Flux rolls it out
```

---

## Quick start

Requirements: Docker Desktop (or OrbStack/Podman) and a GitHub and/or GitLab token.

```bash
./sandbox.sh
```

The first call creates `.env` from `.env.example`. Fill in at least:

| Variable | Purpose |
|---|---|
| `GIT_USER_NAME`, `GIT_USER_EMAIL` | identity of the agent commits |
| `GH_TOKEN` | GitHub: fine-grained PAT, only for the agents' repos. *Contents*, *Issues*, *Pull requests* = read/write; *Metadata* = read. Add *Workflows* only if agents should edit `.github/workflows`. |
| `GITLAB_TOKEN`, `GITLAB_HOST` | GitLab: project/group access token, role **Developer**, scope `api` (gitlab.com or self-hosted) |
| `TICKET_DEFAULT_REPO`, `TICKET_REPOS` | e.g. `owner/k8s-ops gitlab.com/group/website` |
| `DOCS_LICENSE_DEFAULT`, `DOCS_COPYRIGHT_HOLDER`, `DOCS_SECURITY_CONTACT` | optional defaults for the documentation writer (otherwise it asks) |
| `HERMES_PROVIDER`, `HERMES_MODEL`, `HERMES_OPENROUTER_API_KEY` (or similar) | model access for Hermes |

Then start again. The first build takes a while (the image is about 8 GB):

```bash
./sandbox.sh            # shell in the container
./sandbox.sh doctor     # checks tokens, permissions, logins, guardrails
./sandbox.sh claude     # first time: /login (Claude subscription) - stays in the volume
./sandbox.sh hermes     # without HERMES_* in .env: run "hermes model" in the container
```

Prepare each repo once. These scripts run on the host, with your own `gh`/`glab` login:

```bash
scripts/github-setup.sh owner/k8s-ops --templates
scripts/gitlab-setup.sh gitlab.com/group/website --templates --protect
```

They create the `agent/*` labels and open a PR/MR with the issue template, PR/MR template
and DevSecOps CI. For GitHub repos with label sync (`delete-other-labels: true`, as in repos based
on the onedr0p cluster-template), the PR also adds the labels to `.github/labels.yaml`.

On Windows: `sandbox.cmd` or `.\sandbox.ps1` with the same commands.

> **Important:** `WORKSPACE_DIR` points to a *separate* folder (default `./workspace`). The agents
> clone into it fresh. Do not mount an existing working copy that holds keys or tokens next to the
> code (e.g. an `age.key`, an admin `kubeconfig`, push tokens or deploy keys in gitignored files).

---

## Language rule

You can write in your own language (e.g. German) - in tickets, in the chat, in approvals. **Everything that is persisted is
English:** issue titles and bodies, comments, plans, PR/MR texts, review comments, commit messages,
branch names, code, code comments and docs. Several places enforce this:

- `config/AGENTS.md` (house rules for both agents) makes it a hard rule. The agents keep talking
  to you in your language.
- `ticket new`, `ticket approve "note"`, `ticket reject` and `ticket block` translate your input
  with `claude -p` before posting. `ticket new` shows a preview and asks before it creates the issue.
  Set `TICKET_TRANSLATE=0` to switch this off.
- `/new-item` writes the ticket in English from the start.
- `/plan-item` first rewrites a non-English issue (e.g. one you typed in the GitHub app) in English.
  The original stays in the issue's edit history.
- The `code-reviewer` and `iac-reviewer` also check that code, comments and commits are in English.

---

## Submitting work: the ticket workflow

### State model (labels, identical on GitHub and GitLab)

| Label | Meaning | Set by |
|---|---|---|
| `agent/todo` | new work item | issue template, `ticket new`, `/new-item` |
| `agent/planned` | plan is posted as a comment on the issue | `/plan-item` |
| `agent/approved` | **you** approved the plan | `ticket approve` or "approved" in the chat |
| `agent/in-progress` | an agent is working on it | `/implement-item` |
| `agent/in-review` | PR/MR open, waiting for you | `/implement-item` |
| `agent/blocked` | question or problem | agent or `ticket block` |
| `agent/claude`, `agent/hermes` | preferred agent for `ticket run` | you |

### Repos and references

| | Repo | Issue | PR/MR |
|---|---|---|---|
| GitHub | `owner/repo` | `owner/repo#12` or URL | `owner/repo#7` or `.../pull/7` |
| GitLab | `gitlab.com/group/project` (self-hosted: `<host>/group/project`) | `gitlab.com/group/project#12` or URL | `gitlab.com/group/project!7` or `.../-/merge_requests/7` |

A plain number refers to the repo of the current directory, otherwise `TICKET_DEFAULT_REPO`.

### 1. Create a work item - four ways

1. **Web or mobile app:** GitHub *New issue → 🤖 Agent task*, or GitLab *New issue → template
   "Agent task"*. The template asks for goal, acceptance criteria, boundaries and risk, and sets
   `agent/todo`.
2. **Command line** (in the container, or on the host with `bin/` in your PATH):
   ```bash
   ticket new -R owner/k8s-ops -a claude "Paperless: Redis-NetworkPolicy ergänzen"
   ```
   This opens the editor with the template. German is fine: you get an English preview, then the
   issue is created. Piping works too: `echo "..." | ticket new "Title"`.
3. **In a conversation with the agent:** `/new-item gitlab.com/group/website Kontaktformular mit Spamschutz ...`.
   The agent asks follow-up questions, writes testable acceptance criteria in English and creates
   the issue.
4. **On the go via the Hermes gateway (optional):** connect Hermes to Telegram
   (`hermes gateway setup`) and message it "create a ticket: ...". It uses the same `/new-item` skill.

### 2. Plan

```bash
ticket run plan owner/k8s-ops#42          # starts Claude (or Hermes with agent/hermes) with /plan-item
# or inside a running agent:
/plan-item https://gitlab.com/group/website/-/issues/3
```

The agent reads the ticket and the code and experiments safely (`helm template`, `flux-local`,
read-only `kubectl`). It asks up to three questions. Then it posts the plan as an issue comment:
goal, steps, tests, **security assessment**, risk & rollback, and the planned review roles.

### 3. Approve

Read the plan on the issue, then:

```bash
ticket approve owner/k8s-ops#42 "ok, aber ohne Ingress"          # note is posted in English
ticket reject  owner/k8s-ops#42 "bitte ExternalSecret statt SOPS"   # back to agent/todo
```

Or simply say "passt, freigegeben" in the planning chat.

### 4. Implement

```bash
ticket run implement owner/k8s-ops#42                 # interactive - you can watch and step in
ticket run implement owner/k8s-ops#42 --auto          # autopilot (only with agent/approved)
ticket run implement gitlab.com/group/website#3 --agent hermes
```

The agent works in its own Git worktree (`workspace/.worktrees/<repo>/<nr>-<slug>`), so Claude
and Hermes can work on different tickets in the same repo at the same time. You can follow the
progress live in the `workspace` folder in your IDE.

In autopilot mode the agents run without asking:
- Claude: `claude -p ... --permission-mode bypassPermissions`
- Hermes: one-shot with the skill preloaded (`hermes chat --oneshot -s implement-item -q <url>`)

`sandbox-guard` and the managed policies still apply. If something is unclear, the agent sets
the ticket to `agent/blocked` and asks on the issue.

### 5. Review and merge

The PR/MR contains:
- the gate table
- each review role's results
- open points with reasons
- the rollback path

Read it, ask questions (a PR/MR comment plus `/review-pr`), then merge. Afterwards `ticket clean`
removes the worktrees of merged branches.

### Keeping track

```bash
ticket ls                     # open work items by state (repo of the current folder)
ticket queue                  # approved work items in all TICKET_REPOS (GitHub and GitLab)
ticket show gitlab.com/group/website#3
```

### Reviewing other PRs/MRs (e.g. Renovate)

```bash
ticket run review owner/k8s-ops#169
ticket run review gitlab.com/group/website!12
```

`/review-pr` runs the gate and the reviewers. For dependency updates it also:
- reads the release notes of all skipped versions
- compares the Helm values of the old and new chart version

The result is a PR/MR comment with a recommendation: merge, merge after changes, or do not merge.
This is especially useful for major updates (`feat(container)!:` in Renovate's commit style).

---

## Documentation writer

`/write-docs` documents a whole repository or a single app inside a monorepo. It writes in English,
checks every statement against the code, and submits the result as a PR/MR like any other change.

```bash
ticket run docs owner/k8s-ops                                          # whole repo
ticket run docs owner/k8s-ops --path kubernetes/apps/paperless/paperless   # one app → its README.md
ticket run docs gitlab.com/group/website --only readme,security,license
ticket run docs owner/k8s-ops#57                                       # driven by a ticket (closes it)
# or inside a running agent:  /write-docs owner/k8s-ops
```

| File | Content |
|---|---|
| `README.md` | overview, quick start, configuration reference, usage, development, structure |
| `docs/ARCHITECTURE.md` | **detailed project description**: purpose, context, components, data flow (Mermaid), state, configuration, deployment, security model, design decisions, limitations |
| `docs/OPERATIONS.md` | runbook: deploy/update, rollback, backup/restore, secrets, troubleshooting |
| `SECURITY.md` | supported versions, private reporting channel, security measures, scope |
| `CONTRIBUTING.md` | workflow (including the agent ticket workflow), setup, checks, conventions |
| `AGENTS.md` | compact context for AI agents, so later sessions do not re-explore the repo (saves tokens) |
| `LICENSE` | official license text via `docs-license` - never written by the model |
| `<app>/README.md` | per-app documentation in monorepos (deployment, exposure, configuration, data, dependencies) |
| `CHANGELOG.md`, `CODE_OF_CONDUCT.md` | optional, only when they make sense (releases / public contributions) |

How it works:
1. The skill takes an inventory: existing docs, repo type, visibility, license, tooling.
   It asks you only what it cannot derive: license, security contact, scope. In autopilot it uses
   `DOCS_LICENSE_DEFAULT`, `DOCS_COPYRIGHT_HOLDER` and `DOCS_SECURITY_CONTACT` from `.env`.
2. `docs-writer` subagents write the documents in parallel, one per document or app, following the
   templates in `templates/docs/`.
   - They only write what they can verify in the repo; anything else becomes an open point in the PR/MR.
   - They update existing docs instead of overwriting them.
   - They never publish internal hostnames, IPs or secret values.
3. The gate checks the Markdown (broken relative links, unclosed code fences, template leftovers).
   `code-reviewer` checks accuracy and `security-reviewer` checks for information leaks.
4. The PR/MR also suggests a repository description and topics - setting them stays with you.

Docs also stay current during normal work: `/implement-item` updates the affected documentation in the
same PR/MR (delegating to `docs-writer` for bigger changes), and new apps get their README from
`templates/docs/APP-README.md`.

---

## DevSecOps pipeline

`config/playbooks/devsecops-review.md` defines the order. It applies to both agents.

### A. `devsecops-gate` - deterministic and diff-aware

The gate only checks what changed compared to `origin/<default>`, so legacy issues in the repo
do not block every PR/MR. You can run it yourself at any time: `devsecops-gate`,
`devsecops-gate --deep`, or `./sandbox.sh gate` from the host.

| Check | Tool | Blocks on |
|---|---|---|
| Secrets in commits and files | gitleaks | any finding |
| SOPS / plain-text secrets | yq | `kind: Secret` without SOPS, unencrypted `*.sops.yaml` |
| YAML | yamlfmt (if the repo uses it) or yamllint | yamllint errors |
| Kubernetes schema | kubeconform + CRD catalog | invalid manifest |
| Kubernetes best practices | kube-linter | - (warning) |
| Image pinning | yq | - (warning on `latest`/missing tag) |
| IaC misconfiguration | trivy config | HIGH/CRITICAL in changed files |
| Shell | shellcheck | errors |
| Dockerfiles | hadolint | errors |
| PowerShell | PSScriptAnalyzer | severity *Error* |
| Ansible | ansible-lint | blocker/critical |
| GitHub Actions | actionlint, zizmor | errors / high |
| GitLab CI | glab ci lint | invalid configuration |
| SAST | semgrep (`p/default`) | ERROR |
| Dependencies | trivy fs | CRITICAL in changed lockfiles |
| Tests | go test, npm/bun/pnpm test, Pester | failure |
| Documentation | link/fence check on changed Markdown | broken relative links, unclosed code fences (warning on TODO/template leftovers) |
| Flux (only `--deep`) | flux-local test + diff | rendering errors; the diff goes into the report |
| Project-specific checks | `.sandbox/checks.sh` in the repo | exit 1 |

The report is written to `.git/devsecops-report.md` (for worktrees, the worktree's git directory).
It goes into the PR/MR description.

### B. Review subagents

| Role | When | Focus |
|---|---|---|
| `code-reviewer` | always | correctness against acceptance criteria, tests, readability, repo conventions, English |
| `security-reviewer` | always | secrets, injection, authZ, exposure, supply chain, container/K8s hardening, assessment of scanner findings |
| `k8s-reviewer` | Kubernetes/Helm/Flux/Talos changed | Flux structure, HelmRelease values against `helm show values`, probes, resources, network policies, rendered diff, read-only live comparison |
| `iac-reviewer` | Ansible/PowerShell/Shell/Dockerfile/GitHub Actions/GitLab CI changed | idempotency, check mode/`-WhatIf`, error handling, pinning, CI hardening |

Every role starts with fresh context, so it did not "write the code itself". Each returns a
findings table with BLOCKER/MAJOR/MINOR/NIT. BLOCKER and MAJOR get fixed and the gate runs again.
There are at most two review rounds. Anything left open is documented with a reason in the PR/MR.

- **Claude Code:** the roles are real subagents in `~/.claude/agents/` (from `config/agents/`) and
  run in parallel via the Agent tool.
- **Hermes:** Hermes has no named subagent files. The skill calls `delegate_task` with one task per
  role, and each child agent first reads its role description from `config/agents/`.

---

## Skills, roles, rules - one source for both agents

| File | Claude Code | Hermes |
|---|---|---|
| `config/AGENTS.md` (house rules) | imported by the managed `CLAUDE.md` (`/etc/claude-code`) | appended to `SOUL.md` on start |
| `config/skills/*/SKILL.md` | `~/.claude/skills` → `/plan-item` etc. | `skills.external_dirs` → `/plan-item` etc. |
| `config/agents/*.md` (4 reviewers + `docs-writer`) | subagents | role text for `delegate_task` |
| `config/playbooks/devsecops-review.md` | pipeline procedure | same |
| `config/playbooks/forge-cli.md` | `gh` vs. `glab` cheat sheet | same |
| `templates/docs/*.md` | documentation templates for `/write-docs` | same |
| `config/claude/managed-settings.json` | policy + PreToolUse hook (cannot be overridden) | - |
| `config/hermes/managed/config.yaml` | - | policy + pre_tool_call hook (cannot be overridden) |
| `config/hermes/config.yaml` | - | initial config (model etc.), changeable later with `hermes model` |

Everything under `config/` and `bin/` is mounted **live** (read-only) into the container, so edits
on the host take effect immediately, without a rebuild. The exception is the initial files in the
volumes; `SEED_OVERWRITE=1` forces them to be copied again.

**Writing to the forge is forge-neutral:** skills use `ticket state|comment|upsert-comment|pr|pr-comment`.
The `ticket` script decides whether to call `gh` or `glab`. For reading, the skills use the native
CLIs (see `forge-cli.md`).

**Adding your own skill:** create `config/skills/<name>/SKILL.md` with `name` and `description` in
the frontmatter. For the input, write `$ARGUMENTS`: Claude replaces the placeholder, while Hermes
appends the input as text. The existing skills show how to handle both.

**Adding your own gate check:** put an executable `.sandbox/checks.sh` in the repo. Exit 0/1/2
means ok/FAIL/WARN. It receives the changed files as arguments.

---

## Security model

The sandbox relies on several layers. None of them is perfect on its own.

| Layer | Protection | Limit |
|---|---|---|
| **Container** | user `dev`, `cap_drop: ALL`, `no-new-privileges`, no sudo, no Docker socket; only `workspace/` from the host is visible; ports bound to 127.0.0.1 | Docker is not a VM; run it inside a VM for more isolation |
| **Tokens** | GitHub fine-grained PAT only for selected repos; GitLab Developer token | the agent can do whatever the token can |
| **Branch protection** | GitHub ruleset (`github-setup.sh --ruleset`), GitLab protected branch (`gitlab-setup.sh --protect`) | admins/maintainers can bypass - see below |
| **sandbox-guard** | one rule set, wired in as the Claude PreToolUse hook, the Hermes pre_tool_call hook, and shims in front of `git`/`gh`/`glab`. It blocks e.g. push to main, force push, `gh pr merge`/`glab mr merge`/approve, writing `kubectl`/`helm`/`flux`/`talosctl`, `sops -d`, `ansible-playbook` without `--check`, `curl \| sh` | prevents accidents, not a security boundary |
| **Hermes internal** | `approvals.deny` (applies even with `--yolo`), Tirith checks, `HERMES_WRITE_SAFE_ROOT=/workspace:/tmp:~/.hermes` | - |
| **Cluster** | optional read-only RBAC (`view`, no secrets); changes only via GitOps PR | - |
| **Secrets** | no age key in the sandbox; SOPS files stay encrypted; the gate checks for plain-text secrets | - |

The guard is tested in `tests/test-sandbox-guard.sh`, the forge layer in `tests/test-ticket.sh`, and the
documentation tooling in `tests/test-docs.sh`.

### Own identity for the agents (recommended)

If the agent uses a token of **your** account, it can do everything you can.

- **GitHub:** you are admin, so the ruleset does not apply to the agent. A cleaner setup:
  1. Create a GitHub account for the bot (e.g. `<owner>-bot`) and invite it to the repos as a
     *collaborator with write access*.
  2. Create a classic PAT with scope `repo` for the bot account. It only covers the repos the bot
     was invited to. Put it in `GH_TOKEN`.
  3. Run `scripts/github-setup.sh owner/k8s-ops --ruleset --bypass-app renovate`. Now `main` only
     accepts changes via PR, except for you (admin) and Renovate. Renovate only needs the exemption
     if it merges straight to main (`automergeType: "branch"`).
- **GitLab:** create a project or group access token with role **Developer** (scope `api`). That is
  a separate bot user. With the default branch protected (`gitlab-setup.sh --protect`), it can push
  `agent/*` branches and open MRs, but it can neither push nor merge to main.

The agent then technically cannot push or merge to main, whatever the prompt says. Commits and
PRs/MRs visibly carry the bot's identity.

### Claude subscription and Hermes

Claude Code logs in with your subscription in the sandbox (`/login`). Hermes deliberately does
**not** reuse that login (`auth.adopt_external_logins: false`). According to the Hermes docs it
only works with Max plus purchased extra usage, and the rotating tokens would invalidate each
other. Give Hermes its own access instead:
- OpenRouter
- an Anthropic API key from platform.claude.com
- a local model (`HERMES_PROVIDER=custom`)

---

## Kubernetes read access (optional)

For `kubectl get/describe/logs` (planning, k8s review), the sandbox can get read-only access:

1. Add `k8s/agent-sandbox-readonly.yaml` to the cluster repo via GitOps. A good first ticket for
   the agents: *"Add a read-only ServiceAccount for the agent sandbox"*.
2. On the host, with your admin kubeconfig:
   ```bash
   KUBECONFIG=/path/to/admin-kubeconfig scripts/k8s-readonly-access.sh 168h
   ```
   The script writes `secrets/kubeconfig` with a 7-day token. It also verifies that the token can
   neither write nor read secrets.

Writes always go through GitOps: agent → PR → you merge → Flux.

---

## Maintenance

```bash
./sandbox.sh update        # rebuild, latest Claude Code version
./sandbox.sh build         # rebuild (e.g. after changing the Dockerfile or HERMES_VERSION)
./sandbox.sh status | logs | stop | down
./sandbox.sh reset-state   # delete logins, sessions, Hermes memory, caches (workspace stays)
tests/test-sandbox-guard.sh && tests/test-ticket.sh && tests/test-docs.sh   # regression tests (bash >= 4, jq)
```

- Tool versions are pinned as `ARG`s at the top of `docker/Dockerfile`. Project tools (`talosctl`,
  `just`, `yamlfmt`, ...) come from each repo's `.mise.toml` (`mise install`).
- Hermes is taken from the official image `nousresearch/hermes-agent:<HERMES_VERSION>`: code is
  read-only under `/opt/hermes`, state lives in a volume. Like the official image, the sandbox uses
  Hermes' bundled Python 3.14 and Node 26 as `python3`/`node`.
- State lives in Docker volumes: `claude-home`, `hermes-home`, `sandbox-cache`, `mise-data`, `go-home`.

## Layout

```
sandbox.sh / sandbox.ps1 / sandbox.cmd   launchers (check prerequisites, build, start, exec)
compose.yaml, .env(.example)             container definition and settings
docker/                                   Dockerfile, entrypoint, shell profile
bin/                                      ticket, devsecops-gate, docs-license, sandbox-guard, sandbox-doctor, shims/{git,gh,glab}
config/AGENTS.md                          house rules (both agents)
config/skills/                            new-item, plan-item, implement-item, review-pr, write-docs
config/agents/                            code-, security-, k8s-, iac-reviewer, docs-writer
config/playbooks/                         devsecops-review.md (pipeline), forge-cli.md (gh vs. glab)
config/claude/                            managed settings + CLAUDE.md (→ /etc/claude-code)
config/hermes/                            managed policy, initial config, SOUL.md
templates/github/, templates/gitlab/      issue/PR/MR templates, labels, CI
templates/docs/                           README, ARCHITECTURE, OPERATIONS, SECURITY, CONTRIBUTING, AGENTS, APP-README
scripts/                                  github-setup.sh, gitlab-setup.sh, k8s-readonly-access.sh (host)
k8s/                                      read-only RBAC for the sandbox
tests/                                    regression tests for guard, ticket and docs tooling
workspace/                                the agents' Git clones (not versioned)
secrets/                                  optional kubeconfig (not versioned)
```

## Status, license and security

This is a personal project, shared as-is in the hope that it is useful. Issues and pull requests are
welcome, but there is no support guarantee.

- License: [MIT](LICENSE)
- Security policy and private vulnerability reporting: [SECURITY.md](SECURITY.md)
- Do not publish the built image: it contains Claude Code, which is proprietary software. The repository
  itself only contains the recipe; Claude Code is downloaded with Anthropic's installer at build time.

## Acknowledgements

- The idea - a container sandbox for coding agents with a plan/implement ticket workflow - comes from the
  c't/heise article *"Schluss mit Vibe-Coding: Sandbox für professionelle KI-Entwicklung gebaut"* by Jan Mahn
  (heise online, October 2026) and its companion repository [jamct/sandbox](https://github.com/jamct/sandbox).
  Concepts such as the split into `/plan-item` and `/implement-item` and the container layout follow the
  article; the code and texts of this project were written independently and extend the idea with Hermes
  Agent, GitLab support, the DevSecOps pipeline, the guardrails and the documentation writer.
- [Hermes Agent](https://github.com/NousResearch/hermes-agent) by Nous Research,
  [Claude Code](https://docs.claude.com/en/docs/claude-code) by Anthropic, and the many open-source tools
  the sandbox bundles.

## Troubleshooting

- **`sandbox-guard: BLOCKED ...`**: this is intended. Run the step yourself (on the host, or with
  `/usr/bin/git`, `/usr/bin/gh` or `/usr/local/bin/glab` in your own shell), or adjust the rule in
  `bin/sandbox-guard`.
- **Hermes does not show the skills:** check that `skills.external_dirs` in `$HERMES_HOME/config.yaml`
  contains `/opt/sandbox/config/skills`. The entrypoint enforces this on every start; `sandbox-doctor`
  checks it.
- **Labels disappear on GitHub:** the repo uses label sync. Add `templates/github/labels-snippet.yaml`
  to `.github/labels.yaml` (`github-setup.sh --templates` does this for you).
- **Translation does not happen:** `ticket` needs a logged-in `claude`. Without it the text is posted
  as entered, and `/plan-item` rewrites the issue in English later.
- **Web development:** start dev servers with `--host 0.0.0.0` and open them on the host at
  `http://localhost:3000`, `:5173` or `:8080`. To let Hermes' browser tool open the local dev
  server, set `security.allow_private_urls: true` in `$HERMES_HOME/config.yaml`.
