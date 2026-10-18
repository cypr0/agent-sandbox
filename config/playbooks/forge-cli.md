# Forge cheat sheet: GitHub (`gh`) and GitLab (`glab`)

Work out the forge first: `ticket info <ref>` prints `FORGE`, `REPO`, `NR`, `URL`, `DIR`,
`DEFAULT_BRANCH` and `CLI`. A GitHub *pull request (PR)* is a GitLab *merge request (MR)*;
a GitHub *comment* is a GitLab *note*. GitLab references MRs with `!7`, issues with `#12`.

## Writes: always through `ticket` (same commands on both forges)

| Purpose | Command |
|---|---|
| Clone/update repo, print path | `ticket clone <ref>` |
| Set state label | `ticket state <ref> planned` (todo, planned, approved, in-progress, in-review, blocked) |
| Comment on an issue | `ticket comment <ref> /tmp/file.md` |
| Create or update the plan comment | `ticket upsert-comment <ref> '<!-- agent-plan -->' /tmp/plan.md` |
| Open PR/MR against the default branch | `ticket pr <ref> --branch agent/12-x --title "feat(x): ..." --body-file /tmp/pr.md [--draft]` |
| Review comment on a PR/MR (never approve) | `ticket pr-comment <pr-ref> /tmp/review.md` |
| Create an issue | `ticket new -R <repo> "Title" < /tmp/body.md` (add `-a claude\|hermes`, `-k <label>`) |

## Reads: native CLIs

| Purpose | GitHub | GitLab |
|---|---|---|
| Issue with comments | `gh issue view N -R o/r --comments` | `glab issue view N -R https://host/g/p --comments` |
| Issue as JSON | `gh issue view N -R o/r --json title,body,labels,comments` | `glab api projects/<enc>/issues/N` + `.../notes` |
| Search issues | `gh issue list -R o/r --search "..."` | `glab issue list -R <url> --search "..."` |
| PR/MR details | `gh pr view N -R o/r --json ...` | `glab mr view N -R <url>` |
| PR/MR diff | `gh pr diff N -R o/r` | `glab mr diff N -R <url>` |
| CI status | `gh pr checks N -R o/r` | `glab ci status` / `glab mr view N` |
| Labels | `gh label list -R o/r` | `glab label list -R <url>` |
| Fetch PR/MR head locally | `git fetch origin pull/N/head:pr-N` | `git fetch origin merge-requests/N/head:mr-N` |
| Releases (upstream) | `gh release view <tag> -R o/r` | `glab release view <tag> -R <url>` |
| Raw API | `gh api repos/o/r/...` | `glab api projects/<url-encoded-path>/...` (self-hosted: `--hostname <host>`) |

`<enc>` is the URL-encoded project path, e.g. `group%2Fwebsite`.
