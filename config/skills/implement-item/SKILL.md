---
name: implement-item
description: Implement an approved, planned GitHub or GitLab issue, run it through the DevSecOps pipeline (tests, devsecops-gate, code/security/Kubernetes/IaC review by subagents, fixes) and submit it as a pull/merge request - everything persisted in English. Use when a ticket with a plan should be implemented.
argument-hint: "<issue-url | repo#nr | nr>"
disable-model-invocation: true
---

# Implement a work item

You implement a planned and approved issue, run it through the DevSecOps pipeline
and submit it as a pull request (GitHub) or merge request (GitLab). Only a human merges.

## Input

`$ARGUMENTS`

If that is empty or only shows the placeholder, the input is in the user's message
(Hermes appends it to this skill). Expected: an issue URL (GitHub or GitLab), `repo#nr`
or a number. If it is missing, ask for it.

Talk to the user in their language. **Code, comments, commits, branch names, PR/MR text and
issue comments are English.**

## Phase 1 - preparation

1. **Load issue and plan:** `ticket info <ref>` and `ticket show <ref>`. The plan is the comment containing
   `<!-- agent-plan -->`. No plan comment means no implementation: stop and suggest running `/plan-item` first.
2. **Check approval:** label `agent/approved` or an explicit approval by the user in this chat.
   Otherwise stop and explain how to approve (`ticket approve <ref>`).
3. **State:** `ticket state <ref> in-progress` and a short comment via `ticket comment`
   (`🛠️ Implementation started (<agent>, branch agent/<nr>-<slug>)`).
4. **Create a worktree** (isolated, so parallel agents do not interfere):
   ```sh
   R=$(ticket clone <ref>); DEF=<DEFAULT_BRANCH from ticket info>
   WT=/workspace/.worktrees/$(basename "$R")/<nr>-<slug>
   git -C "$R" worktree add "$WT" -b agent/<nr>-<slug> "origin/$DEF"   # branch exists already: add without -b
   cd "$WT"
   ```
   If the repo has a `.mise.toml`: `mise install` (also installs git hooks such as lefthook).

## Phase 2 - implementation

5. **Implement the plan step by step** and stay consistent with how the repo already does things.
   Write tests first where that helps. Record every departure from the plan together with its reason -
   it goes into the PR/MR.
6. **Commit** whenever a step is complete in itself: Conventional Commit in English, the body explains the
   motivation, the last line is `Refs #<nr>`.
7. **Run the checks** the plan names (tests, linters, build, `helm template`, `flux-local`, ...).
   Move on only with a green result.
8. **Documentation:** update the docs the change affects - README (configuration, usage), `docs/ARCHITECTURE.md`,
   `docs/OPERATIONS.md`, `AGENTS.md`, the app's own README in monorepos. For more than a few lines delegate to the
   `docs-writer` subagent (Claude: Agent tool; Hermes: `delegate_task` with `/opt/sandbox/config/agents/docs-writer.md`).
   Commit as `docs(<scope>): ...`. A new app/component in a monorepo gets its README from `templates/docs/APP-README.md`.

## Phase 3 - DevSecOps pipeline (mandatory, in this order)

Follow **`/opt/sandbox/config/playbooks/devsecops-review.md`** exactly - read it now. In short:

- **A. Gate:** `devsecops-gate` (Flux repos with Kubernetes changes: `devsecops-gate --deep`).
  Fix FAIL and repeat (max. 3 rounds). WARN: evaluate - fix or justify.
- **B. Reviews:** subagents with fresh context, in parallel: `code-reviewer` and `security-reviewer` always,
  `k8s-reviewer` for Kubernetes/Helm/Flux/Talos files, `iac-reviewer` for Ansible/PowerShell/Shell/Dockerfile/CI.
- **C. Fix:** fix BLOCKER and MAJOR (`fix(review): ...`), run the gate again, after bigger fixes a second
  review round of the affected role only (max. 2 rounds in total).

## Phase 4 - pull/merge request

9. **Push:** `git push -u origin agent/<nr>-<slug>`.
10. **PR/MR text** in English to `/tmp/pr-<nr>.md` (template below), then
   `ticket pr <ref> --branch agent/<nr>-<slug> --title "<conventional title>" --body-file /tmp/pr-<nr>.md`
   - add `--draft` if BLOCKERs remain.
11. **Update the issue:** `ticket state <ref> in-review` (with open BLOCKERs: `blocked`) and
    `ticket comment` with the PR/MR link and a three-line summary.
12. **Summary for the user** (in their language): PR/MR URL, branch/worktree, gate result, review result,
    open points, what the human should check before merging.

### PR/MR template

```markdown
## Summary
<2-5 sentences, reference to the ticket>

## Changes
- ...

## How it was verified
- <tests/commands and result>

## DevSecOps
<table from the gate report (<git-dir>/devsecops-report.md), without the details blocks>

| Review | Result | Fixed | Open |
|---|---|---|---|
| code-reviewer | ✅/⚠️/❌ | n | n |
| security-reviewer | ... | | |

### Open points / deliberately not done
- <finding> - <reason>

## Differences from the plan
- none | ...

## Rollback
<e.g. revert this PR/MR; Flux reconciles the previous state>

Closes #<nr>
```

## Rules

- Never commit or push to the default branch, no `--force` (only `--force-with-lease` on your own branch).
- Never merge or approve. Never read or commit `.env` files or keys. Secrets only SOPS-encrypted - if a new
  secret is needed, add a template without values and describe in the PR/MR what the human has to encrypt.
- If `sandbox-guard` blocks something, do not work around it: document it under *Open points*.
- Resolve ambiguity instead of guessing: ask the user (interactive mode), or set the issue to `blocked` and post
  the question on it (autopilot).
