---
name: plan-item
description: Analyse a GitHub or GitLab issue and, in dialogue with the user, work out an implementation plan including a security assessment, posted in English as a comment on the issue - without changing code. Use when a ticket/issue should be planned, broken down or prepared for implementation.
argument-hint: "<issue-url | repo#nr | nr>"
---

# Plan a work item

This skill produces a plan, not code. It studies the issue and the repository, may
try things out in `/tmp`, and ends with a plan comment on the issue. The repository
itself stays untouched: no file edits, no branches, no commits.

## Input

`$ARGUMENTS`

If that is empty or only shows the placeholder, the input is in the user's message
(Hermes appends it to this skill). Expected: an issue URL (GitHub or GitLab),
`repo#nr`, or a number (then the repo of the current directory applies). If it is
missing, ask for it.

Talk to the user in their language. **Everything you write to the forge is English.**

## Step 0: context

```sh
ticket info <ref>          # FORGE, REPO, NR, URL, DIR, DEFAULT_BRANCH, CLI
ticket show <ref>          # issue with comments
ticket clone <ref>         # clone or fetch /workspace/<repo>
```

- Work with the state of `origin/<DEFAULT_BRANCH>`. Do not check out another branch in the main
  checkout (other agents may be working there); read other states via `git show origin/<branch>:<path>`.
- A comment containing `<!-- agent-plan -->` is the existing plan: revise it instead of starting over.
- Read commands for each forge: `/opt/sandbox/config/playbooks/forge-cli.md`.

## Steps

1. **Normalize the language.** If the issue title or body is not in English, translate it faithfully
   and update the issue (GitHub: `gh issue edit N -R <repo> --title ... --body-file ...`;
   GitLab: `glab issue update N -R <url> --title ... --description ...`). Tell the user you did.
2. **Understand the ticket.** Title, body, acceptance criteria, comments, linked PRs/MRs.
3. **Understand code and system.** Locate the code and config the change touches and study how the repo
   already solves similar problems (for Kubernetes: an existing app of the same kind is the reference).
   Take build, test and lint commands from the repo itself (README, `.mise.toml`, `justfile`, `package.json`,
   `go.mod`, CI config). Look facts up rather than assuming them.
4. **Experimenting is allowed** - read-only and without side effects: try libraries in `/tmp`,
   `helm template`, `helm show values`, `kustomize build`, `flux-local get`, `kubectl get/describe`
   (if cluster read access exists), read release notes.
5. **Questions.** Where the requirements contradict each other or leave gaps that would change the
   solution, ask the user - in their language, three questions at most - and wait for the answers before
   writing the plan. Typical topics: error handling, reachability (internal/external), data
   persistence/backup, compatibility.
6. **Write the plan** in English to `/tmp/plan-<nr>.md`, exactly with these sections:

   ```markdown
   <!-- agent-plan -->
   ## Implementation plan

   **Objective:** <1-3 sentences>
   **Effort:** S | M | L    **Risk:** low | medium | high

   ### Context & assumptions
   ### Scope of change
   - `path` - why
   ### Implementation steps
   1. <small enough to implement and check on its own>
   ### Verification
   - <new/changed tests, commands; devsecops-gate (Flux repos: --deep)>
   ### Security assessment
   - Attack surface / reachability: ...
   - Secrets & permissions (RBAC, securityContext, network policy, token scopes): ...
   - Supply chain (pinned images/dependencies, provenance): ...
   - Data (persistence, backup, personal data): ...
   ### Risk & rollback
   - What can go wrong, who is affected, how to roll back (GitOps: revert PR/MR)?
   ### Review roles
   - code-reviewer, security-reviewer [, k8s-reviewer] [, iac-reviewer] - with reason
   ### Open questions
   ### Done when
   - [ ] all acceptance criteria of the ticket
   - [ ] devsecops-gate without blocking findings, reviews without open BLOCKER/MAJOR
   - [ ] PR/MR with DevSecOps report, linked with `Closes #<nr>`
   ```

7. **Post the plan:** `ticket upsert-comment <ref> '<!-- agent-plan -->' /tmp/plan-<nr>.md`
   (creates or updates the plan comment).
8. **Set the state:** `ticket state <ref> planned`. If open questions block the implementation:
   `ticket state <ref> blocked` and post the questions in English with `ticket comment`.
9. **Approval.** Give the user a short summary of the plan as a few bullet points (in their language) and
   ask for approval. If the user explicitly approves in the chat:
   `ticket state <ref> approved` and post `✅ Plan approved in chat.` via `ticket comment`.
   Point out that implementation starts with `/implement-item <url>` or `ticket run implement <ref>`.

## Rules

- Read-only towards the repository: nothing is edited, committed, branched or proposed as a PR/MR here.
- Uncertain assumptions belong in *Open questions*; the implementation steps contain only what is known.
- Write the plan for a reader who has never seen this conversation.
- The security assessment is mandatory, even if short ("no new attack surface because ...").
