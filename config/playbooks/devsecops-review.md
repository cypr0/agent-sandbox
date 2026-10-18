# DevSecOps pipeline (procedure for implement-item and review-pr)

This file defines the mandatory order of checks and reviews. It applies to Claude
Code and Hermes alike - only how subagents are started differs (section B). All
findings, reports and comments are written in English.

```
 implementation ──▶ A. devsecops-gate ──▶ B. reviews (parallel) ──▶ C. fix ──▶ PR/MR
                      ▲   (FAIL? fix)        code / security /         │
                      └────── max. 3 ──────   k8s / iac                └─▶ gate again, optional 2nd review round
```

## A. Deterministic gate

```sh
devsecops-gate            # diff-aware against origin/<default>
devsecops-gate --deep     # plus flux-local test + diff (Flux repos with Kubernetes changes)
```

- Exit 1 = blocking findings (FAIL). Fix, commit, run again. At most 3 rounds; then document the remaining
  FAILs with a reason and open the PR/MR as draft.
- WARN: evaluate each. Fix it if that is cheap and in scope; otherwise justify it under *Open points*.
  Mark scanner false positives with a reason - never ignore them silently.
- The report ends up in `$(git rev-parse --absolute-git-dir)/devsecops-report.md`, single logs in the
  `devsecops/` folder next to it. Both are inputs for the reviewers.
- Never loosen scanner configs (ignore files, `# nosec`, `# shellcheck disable`) to get a green gate -
  unless with a comment that explains the concrete false positive.

## B. Reviews by subagents

Roles (descriptions in `/opt/sandbox/config/agents/<role>.md`):

| Role | When | Focus |
|---|---|---|
| `code-reviewer` | always | correctness against plan/acceptance criteria, tests, readability, repo conventions |
| `security-reviewer` | always | secrets, injection, authZ, supply chain, container/K8s hardening, scanner findings |
| `k8s-reviewer` | Kubernetes, Helm, Kustomize, Flux or Talos files changed | GitOps structure, HelmRelease, resources, probes, network policies, rendered diff |
| `iac-reviewer` | Ansible, PowerShell, Shell, Dockerfile, GitHub Actions, GitLab CI, justfile/Makefile changed | idempotency, error handling, check mode/-WhatIf, hardening, pinning |

**Docs-only changes** (e.g. from `/write-docs`): `code-reviewer` checks accuracy (every command, path, setting
and claim matches the repo), `security-reviewer` checks that no sensitive information is published (internal
hostnames, IPs, usernames, secret values, attack-relevant details) and that SECURITY.md describes a sound process.
`docs-writer` is an author role, not a reviewer.

Every reviewer gets **fresh context** and these inputs:
- issue URL and plan (comment containing `<!-- agent-plan -->`)
- working directory (worktree path) and base: `git diff origin/<default>...HEAD`
- path to the gate report
- the instruction: read only, change nothing, commit nothing; answer in the format below, in English

**Claude Code:** start all relevant roles **in one message, in parallel** via the Agent tool
(`subagent_type` = role name). The roles are installed as subagents.

**Hermes:** one single `delegate_task` call with one task per role (they run in parallel), e.g.
```
delegate_task(tasks=[
  {"goal": "Do a code review as code-reviewer and return the result in the required format.",
   "context": "First read /opt/sandbox/config/agents/code-reviewer.md and follow it as your role description. Issue: <url>. Worktree: <path>. Diff: git diff origin/<default>...HEAD. Gate report: <path>. Read only, change nothing."},
  {"goal": "Do a security review as security-reviewer ...", "context": "First read /opt/sandbox/config/agents/security-reviewer.md ..."}
])
```

### Mandatory format of every review answer

```markdown
### <role>: APPROVE | CHANGES_REQUESTED

| # | Severity | Location | Finding | Suggestion |
|---|---|---|---|---|
| 1 | BLOCKER | path:line | ... | ... |

**Overall verdict:** <1-3 sentences>
```

Severities:
- **BLOCKER** - security hole, secret leak, data loss, wrong behaviour against acceptance criteria, breaks build/deployment.
- **MAJOR** - likely bug, missing tests for core logic, clear violation of best practice or repo convention, unnecessary privileges.
- **MINOR** - improvement with real value, but not critical.
- **NIT** - style/taste.

## C. Fix and finish

1. Collect and deduplicate all findings (same place from two roles = one finding, highest severity).
2. Fix BLOCKER and MAJOR, MINOR if cheap, NIT at your discretion. Every fix is its own commit `fix(review): ...`.
   Not following a finding is allowed with a reason - the reason goes into the PR/MR.
3. Run `devsecops-gate` again. After bigger fixes (new logic, changed permissions) let the affected role
   review a second time. At most 2 review rounds in total.
4. Result for the PR/MR: gate table, review table (role, verdict, fixed, open), open points with reasons.
