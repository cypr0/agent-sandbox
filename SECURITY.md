# Security policy

## Supported versions

This is a personal project that is shared as-is. Only the latest state of `main` receives fixes.

| Version | Supported |
|---|---|
| `main` | ✅ |
| older commits | ❌ |

## Reporting a vulnerability

Please report vulnerabilities **privately** through GitHub's
[private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability)
(the "Report a vulnerability" button in the repository's *Security* tab). Do not open a public issue
for a vulnerability.

Please include:
- what is affected (file, script, configuration) and in which commit,
- how to reproduce it,
- the impact you expect (e.g. a `sandbox-guard` bypass, a secret leaking into a PR, a container escape path).

You can expect an acknowledgement within a week. Fixes are published on `main`; the advisory is
published once a fix is available.

## Security model in short

The sandbox is **defence in depth**, not a hard isolation boundary. See the "Security model" section
of the [README](README.md) for details. In short:

- Agents run in a Docker container as a non-root user with all capabilities dropped, `no-new-privileges`,
  no sudo and no Docker socket; only the workspace folder of the host is mounted.
- `sandbox-guard` (Claude Code hook, Hermes hook, `git`/`gh`/`glab` shims) blocks dangerous commands to
  **prevent accidents**. It is not designed to stop a determined attacker inside the container.
- The effective protection of repositories comes from tokens with minimal permissions and from branch
  protection on GitHub/GitLab; cluster access is optional and read-only.
- The repository contains no secrets: `.env`, `secrets/` and `workspace/` are excluded via `.gitignore`.

## Scope

In scope: the scripts in `bin/` and `scripts/`, the container definition in `docker/` and `compose.yaml`,
and the policies, skills and agent roles in `config/`.

Out of scope - please report upstream:
- Claude Code (Anthropic), Hermes Agent (Nous Research), and the bundled tools (gh, glab, kubectl, Helm,
  Flux, trivy, gitleaks, semgrep, ...),
- behaviour of the language models themselves (e.g. a model ignoring an instruction), unless a sandbox
  control that should have stopped the resulting action failed.
