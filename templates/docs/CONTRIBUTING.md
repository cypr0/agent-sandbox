<!--
  Template for CONTRIBUTING.md. Describe the real workflow of this repo - including the
  agent ticket workflow if the repo uses it. Commands must come from the repo.
-->
# Contributing

## Workflow

<How work is tracked and submitted: issues → plan → branch → pull/merge request → review → merge.
If the agent sandbox is used: labels `agent/*`, `/plan-item`, `/implement-item`, only humans merge.>

## Development setup

<Tools and how to install them (e.g. `mise install`), how to run the project locally.>

## Checks before opening a pull/merge request

<Formatters, linters, tests, and the DevSecOps gate - with the exact commands.>

## Conventions

- Commit messages: Conventional Commits (`type(scope): subject`), body explains why, reference the issue.
- Branches: `<type>/<issue>-<slug>` (agents use `agent/<issue>-<slug>`).
- Language: everything in the repo (code, comments, docs, commits) is English.
<Add repo-specific conventions: folder layout for new apps, naming, formatting.>

## Reporting bugs and security issues

<Bug reports via issues (with the template). Security issues: see SECURITY.md - not in public issues.>
