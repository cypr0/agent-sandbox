<!--
  Template for docs/OPERATIONS.md - the runbook. Only for things that are operated
  (services, clusters, scheduled jobs, infrastructure). Skip it for pure libraries.
  Commands must be real and copy-pasteable; mark commands that change state clearly.
-->
# Operations

## Day-to-day

<Routine tasks: check health, view logs, common commands.>

## Deploy and update

<How changes reach production (e.g. PR → merge → Flux reconcile), how dependency updates arrive (Renovate),
how to verify a rollout.>

## Rollback

<How to undo a change safely (e.g. revert PR, Helm rollback through GitOps), and what cannot be rolled back (data migrations).>

## Backup and restore

<What is backed up, where, how often, and the tested restore procedure.>

## Secrets

<Where secrets live (SOPS-encrypted files, ExternalSecrets, password manager), how to rotate them. Never include values.>

## Troubleshooting

| Symptom | Likely cause | What to check / do |
|---|---|---|

## Maintenance tasks

<Periodic tasks (certificate renewal, version upgrades, cleanup) with frequency.>
