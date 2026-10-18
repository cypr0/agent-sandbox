<!--
  Template for SECURITY.md. Keep it accurate and actionable.
  Reporting channel: use the configured contact (DOCS_SECURITY_CONTACT). For public GitHub repos
  prefer "private vulnerability reporting" (Security tab); for GitLab, confidential issues.
  Never publish internal hostnames, IPs or real secrets here.
-->
# Security policy

## Supported versions

<Which versions/branches receive security fixes (e.g. "only the latest state of `main`" for a homelab/GitOps repo).>

| Version | Supported |
|---|---|
| `main` | ✅ |

## Reporting a vulnerability

<How to report privately, what to include, and what to expect (acknowledgement time, disclosure).
Ask reporters not to open public issues for vulnerabilities.>

## Security measures in this repository

<Short, factual list of what the repo does to stay secure, e.g.:
- secrets are encrypted with SOPS/age or provided via ExternalSecrets - no plain-text secrets in Git
- dependencies and container images are pinned and updated by Renovate
- pull/merge requests run secret scanning and IaC checks (devsecops gate)
- the default branch is protected; changes go through reviewed pull/merge requests>

## Scope

<What is in and out of scope (e.g. third-party upstream software → report upstream).>
