<!--
  Template for a README inside a single app/component of a monorepo,
  e.g. kubernetes/apps/<namespace>/<app>/README.md in a Flux/GitOps repo.
  Describe this app only; link the repo-level docs for general topics.
-->
# <App name>

<What the app is (upstream project + link), what it is used for here, who uses it.>

## How it is deployed

- **Namespace:** `...`
- **Source:** <Helm chart / app-template / manifests> - version pinned in `...`
- **Flux Kustomization:** `ks.yaml` (`dependsOn`: ...)
- **Image(s):** <repository:tag, updated by Renovate>

## Exposure and access

<Internal or external, hostname pattern (use the substitution variable, e.g. `${SECRET_DOMAIN}`, never real values),
authentication in front, network policies.>

## Configuration

<Important values and where they live; secrets: which SOPS file / ExternalSecret provides which keys (names only).>

## Data

<Persistent volumes, databases, backups.>

## Dependencies

<Other apps/services it needs (databases, auth, storage) and who depends on it.>

## Operations

<Upgrade notes, common issues, useful read-only commands (`kubectl -n <ns> get ...`, `flux get hr -n <ns>`).>
