---
name: new-item
description: Turn a rough idea into a well-formed work item (GitHub or GitLab issue) for the agents - with goal, acceptance criteria, boundaries and risk, written in English. Use when a new task, ticket or issue should be created, or when an ad-hoc request is too big for an immediate change.
argument-hint: "[repo] <description of the request>"
---

# Create a work item

You turn a request into a ticket that another agent can pick up later, with no
access to this conversation. This skill only creates the ticket - it changes no code.

## Input

`$ARGUMENTS`

If that is empty or only shows the placeholder, the input is in the user's message
(Hermes appends it to this skill). It may start with a repo (`owner/repo` for GitHub,
`gitlab.com/group/project` or `<host>/group/project` for GitLab); otherwise use the repo
of the current directory, otherwise `$TICKET_DEFAULT_REPO`. If the request itself is
missing, ask for it.

The user often writes in German. **The ticket is always written in English** - translate
faithfully, keep names, paths and identifiers. Talk to the user in their language.

## Steps

1. **Repo and duplicates:** `ticket info <repo>#0` shows the forge. Search for an existing open issue
   (`gh issue list -R <repo> --search "<keywords>"` or `glab issue list -R <url> --search "<keywords>"`).
   If there is one, show it and ask whether to extend it instead.
2. **Understand.** If the request touches an existing system, take a short read-only look at the repo
   (`ticket clone <repo>#0`) so terms, paths and app names in the ticket are correct.
3. **Questions** - at most three, only if really needed for goal, scope or acceptance criteria
   (Who uses it? How do I know it is done? What must not happen?).
4. **Write the ticket** to `/tmp/new-item.md`. Title: short, imperative, English
   (`paperless: add redis network policy`). Body exactly with these sections:

   ```markdown
   ### Goal / user story
   As a <role> I want <capability> so that <benefit>.

   ### Acceptance criteria
   - [ ] <testable criterion>
   - [ ] <testable criterion>

   ### Context & notes
   <affected apps/paths, links, examples in the repo>

   ### Boundaries
   <what is out of scope; assumptions>

   ### Risk
   <low | medium | high> - <one sentence why, e.g. "publicly reachable service">
   ```

5. **Create it:** `ticket new -R <repo> [-a claude|hermes] [-k <area label>] "<title>" < /tmp/new-item.md`
   (adds `agent/todo`). If the repo has area labels (`area/...`), pass the matching one with `-k`.
   If the `agent/*` labels are missing, run `ticket labels -R <repo>` first.
6. **Finish:** print the URL and offer to continue right away with `/plan-item <url>`.

## Rules

- No code changes, no branches, no commits.
- Acceptance criteria must be testable ("endpoint returns 200 and a JSON field `time`"), not vague.
- No secrets or internal credentials in the ticket.
