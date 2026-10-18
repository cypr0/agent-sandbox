---
name: write-docs
description: Create or update a repository's documentation set - README, LICENSE, SECURITY.md, CONTRIBUTING.md, AGENTS.md, docs/ARCHITECTURE.md (detailed project description) and docs/OPERATIONS.md, or a README for a single app in a monorepo - verified against the code, in English, submitted as a pull/merge request. Use when a repo or app should be documented or its docs refreshed.
argument-hint: "<repo | issue-ref> [path/to/app] [--only readme,license,security,contributing,agents,architecture,operations,changelog,coc]"
disable-model-invocation: true
---

# Write documentation

You document a repository (or one app inside it) and submit the result as a pull
request (GitHub) or merge request (GitLab). Only a human merges.

## Input

`$ARGUMENTS`

If that is empty or only shows the placeholder, the input is in the user's message
(Hermes appends it to this skill). Expected:
- a repo (`owner/repo`, `gitlab.com/group/project`) or an issue reference (`repo#nr`, URL) - with an issue,
  its plan/acceptance criteria define the scope and the PR closes it;
- optionally a path to document a single app/component (e.g. `kubernetes/apps/paperless/paperless`);
- optionally `--only <list>` to restrict the document set.

Talk to the user in their language. **All documentation is English.**

## Document set

| File | Content | Template |
|---|---|---|
| `README.md` | overview, quick start, configuration, usage, development, structure | `templates/docs/README.md` |
| `docs/ARCHITECTURE.md` | **detailed project description**: purpose, context, components, data flow, state, configuration, deployment, security model, decisions, limitations | `templates/docs/ARCHITECTURE.md` |
| `docs/OPERATIONS.md` | runbook: deploy/update, rollback, backup/restore, secrets, troubleshooting (only for operated systems) | `templates/docs/OPERATIONS.md` |
| `SECURITY.md` | supported versions, private reporting, security measures, scope | `templates/docs/SECURITY.md` |
| `CONTRIBUTING.md` | workflow, setup, checks, conventions | `templates/docs/CONTRIBUTING.md` |
| `AGENTS.md` | compact context for AI agents (saves tokens in every later session) | `templates/docs/AGENTS.md` |
| `LICENSE` | official license text via `docs-license` - **never written by hand** | - |
| `CHANGELOG.md` | optional: only if the repo uses tags/releases; Keep a Changelog format from Conventional Commits | - |
| `CODE_OF_CONDUCT.md` | optional: only for public repos that accept outside contributions; ask first | - |
| `<app>/README.md` | when a path is given: one app/component | `templates/docs/APP-README.md` |

Templates are in `/opt/sandbox/templates/docs/`.

## Phase 1 - inventory

1. `ticket info <ref>` (with a plain repo use `<repo>#0`) and `ticket clone <ref>`.
2. Worktree and branch (never on the default branch):
   ```sh
   R=$(ticket clone <ref>); DEF=<DEFAULT_BRANCH>
   WT=/workspace/.worktrees/$(basename "$R")/docs-<slug>        # with an issue: <nr>-docs-<slug>
   git -C "$R" worktree add "$WT" -b agent/docs-<slug> "origin/$DEF"   # with an issue: agent/<nr>-docs-<slug>
   cd "$WT"
   ```
3. Collect facts:
   - existing docs (`ls`, `rg --files -g '*.md'`), their age and quality
   - repo type: application/service, library, GitOps/IaC (Flux, Helm, Talos), scripts (PowerShell, Ansible, Bash), website
   - visibility: GitHub `gh repo view <repo> --json visibility,description,repositoryTopics,licenseInfo`;
     GitLab `glab api projects/<enc>` (`visibility`, `description`, `topics`)
   - existing LICENSE (keep it unless the user asks to change it), CI, tooling (`.mise.toml`, justfile, package.json ...)
   - for monorepos (e.g. `kubernetes/apps/*/*`): the list of apps and which ones lack a README
4. **Decisions** - ask the user (interactive) or use the defaults (autopilot):
   - **License** (only if missing): `$DOCS_LICENSE_DEFAULT` (e.g. `mit`); copyright holder `$DOCS_COPYRIGHT_HOLDER`.
     If no default is set: ask. In autopilot without a default: skip LICENSE and say so in the PR.
     Private repos may deliberately have no license - ask instead of assuming.
   - **Security contact:** `$DOCS_SECURITY_CONTACT`; otherwise GitHub private vulnerability reporting
     (public GitHub repos) or confidential issues (GitLab).
   - **Scope:** which documents (default: all missing ones + refresh of existing ones; `--only` restricts).
     For a monorepo with many apps: confirm whether to document all apps or a selection.
5. Tell the user the plan in a few lines (in their language) before writing.

## Phase 2 - write

6. Delegate the writing to `docs-writer` subagents with fresh context, **in parallel** - one task per document,
   and one per app for per-app READMEs (batches of at most 4):
   - **Claude Code:** Agent tool with `subagent_type: docs-writer`.
   - **Hermes:** `delegate_task` with one task per document; context: "First read
     /opt/sandbox/config/agents/docs-writer.md and follow it as your role description. Worktree: ... Document: ...
     Template: ... Facts: ...".
   Pass each writer the facts from phase 1 and the decisions. README and ARCHITECTURE should be written by the
   same writer or in sequence, so they stay consistent.
7. **LICENSE:** `docs-license <spdx-key> "<holder>" > LICENSE` (e.g. `mit`, `apache-2.0`, `gpl-3.0`, `agpl-3.0`, `mpl-2.0`,
   `bsd-3-clause`, `unlicense`). Mention the license in the README.
8. Read everything once as an editor: consistent names, no contradictions between files, no duplicated sections,
   no placeholders, all relative links valid, English only.
9. Commit per document group: `docs(readme): ...`, `docs(architecture): ...`, `docs(security): add security policy`,
   `docs(license): add MIT license` - with `Refs #<nr>` when there is an issue.

## Phase 3 - checks and review

10. `devsecops-gate` - covers secrets and the docs check (broken relative links, unclosed code fences). Fix FAILs.
11. Reviews per `/opt/sandbox/config/playbooks/devsecops-review.md` section B, for docs:
    - `code-reviewer`: **accuracy** - every command, path, setting and claim matches the repo.
    - `security-reviewer`: **no sensitive information** (internal hostnames, IPs, usernames, secret values, details that
      help an attacker) and a sound SECURITY.md process.
    Fix BLOCKER/MAJOR, max. 2 rounds.

## Phase 4 - pull/merge request

12. `git push -u origin <branch>` and `ticket pr <ref> --branch <branch> --title "docs: <summary>" --body-file /tmp/pr-docs.md`.
    The PR/MR text (English) contains: documents created/updated, decisions (license, security contact), open points the
    writers could not verify, gate/review tables, and a **suggested repository description and topics** - setting
    them is a repo setting, so the human does it.
13. With an issue: `ticket state <ref> in-review` and a comment with the link.
14. Summary for the user (in their language): PR/MR link, what was documented, open points to answer.

## Rules

- Never commit to the default branch; never merge.
- Never write license text yourself, never replace an existing LICENSE without an explicit request.
- Document only verified facts; unknowns go into the PR as open points, not into the docs.
- No secrets or internal infrastructure details in docs, especially in public repos.
