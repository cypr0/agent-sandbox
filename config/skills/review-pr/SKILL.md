---
name: review-pr
description: Run a pull request (GitHub) or merge request (GitLab) through the DevSecOps pipeline - devsecops-gate, reviews by code/security/k8s/iac subagents, changelog and breaking-change analysis for dependency updates (e.g. Renovate) - and post the result in English as a review comment. Use when a PR/MR should be checked, reviewed or assessed.
argument-hint: "<pr/mr-url | repo#nr | repo!nr | nr>"
disable-model-invocation: true
---

# Review a pull/merge request

You check a PR/MR and leave a review comment. You **never approve or merge** and you
never push to someone else's branch.

## Input

`$ARGUMENTS`

If that is empty or only shows the placeholder, the input is in the user's message
(Hermes appends it to this skill). Expected: a PR/MR URL, `owner/repo#nr` (GitHub),
`host/group/project!nr` (GitLab) or a number. If it is missing, ask for it.

Talk to the user in their language. **The review comment is English.**

## Steps

1. **Load the PR/MR:** `ticket info <ref>` (FORGE, REPO, NR, DIR), then
   GitHub: `gh pr view N -R <repo> --json number,title,body,author,baseRefName,headRefName,labels,files,url` and `gh pr checks N -R <repo>`;
   GitLab: `glab mr view N -R <url>` and `glab ci status`/pipeline in the MR view.
2. **Check out locally (isolated):**
   ```sh
   R=$(ticket clone <ref>)
   git -C "$R" fetch origin pull/N/head:pr-N --force            # GitHub
   git -C "$R" fetch origin merge-requests/N/head:pr-N --force  # GitLab
   git -C "$R" worktree add /workspace/.worktrees/$(basename "$R")/pr-N pr-N \
     || git -C /workspace/.worktrees/$(basename "$R")/pr-N reset --hard pr-N
   cd /workspace/.worktrees/$(basename "$R")/pr-N
   ```
3. **Classify the PR/MR:**
   - **Dependency update** (Renovate/Dependabot, titles like `update image ... (v1 ➔ v2)`, `chart ...`): also step 4.
   - **Agent PR/MR** (`agent/*` branch): check that description, the plan in the linked issue and the actual change match.
   - **Other:** normal review.
4. **Dependency updates only - changelog analysis:**
   - Read the release notes of all skipped versions (`gh release view` / `glab release view` in the upstream repo,
     otherwise changelog/Artifact Hub via web fetch). Look for breaking changes, migrations, changed defaults,
     removed values, new CRD versions, security fixes (CVE).
   - Helm charts: compare `helm show values <chart> --version <old>` with `<new>` and hold it against the repo's values.
   - Major bump (`!` in the title or 1.x → 2.x): be extra thorough and name required repo changes concretely.
5. **DevSecOps pipeline** per `/opt/sandbox/config/playbooks/devsecops-review.md`, sections A and B:
   - `devsecops-gate --base origin/<target branch>` (`--deep` for Kubernetes changes in Flux repos)
   - matching review subagents in parallel (Claude: Agent tool; Hermes: `delegate_task`)
   Section C (fixing) does not apply - you do not change the PR/MR. Exception: it is an `agent/*` PR/MR **and**
   the user explicitly asks for fixes; then fix on that branch as in `implement-item` phase 3.
6. **Write the comment** in English to `/tmp/review-<nr>.md` and post it: `ticket pr-comment <ref> /tmp/review-<nr>.md`

   ```markdown
   ## 🤖 DevSecOps review
   **Recommendation:** ✅ merge | ⚠️ merge after changes | ❌ do not merge - <one sentence why>

   ### Gate
   <table from the gate report>

   ### Reviews
   | Role | Verdict | BLOCKER | MAJOR | MINOR |
   |---|---|---|---|---|

   ### Key findings
   1. **[BLOCKER]** `path:line` - finding - suggestion

   ### Update analysis (dependencies only)
   - Breaking changes: ...
   - Required changes in this repo: ...
   - Security-relevant fixes: ...
   ```
7. **Clean up:** `git -C "$R" worktree remove /workspace/.worktrees/$(basename "$R")/pr-N`.
8. **Summary for the user** (in their language): recommendation + the three most important points + link.

## Rules

- No approve, no merge, no push to the PR/MR branch (except the exception above).
- Back every finding with evidence (file:line, command output, release-notes link). Never invent findings.
- Call scanner false positives what they are.
