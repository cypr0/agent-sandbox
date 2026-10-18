#!/usr/bin/env bash
# Creates ./secrets/kubeconfig with a time-limited, read-only token for the
# ServiceAccount agent-sandbox/agent-sandbox-reader (k8s/agent-sandbox-readonly.yaml).
# Runs on the HOST with your normal (admin) kubeconfig - that one never leaves the host.
#
#   KUBECONFIG=/path/to/admin-kubeconfig scripts/k8s-readonly-access.sh [duration]
#   duration: e.g. 168h (default), 720h
set -euo pipefail
cd "$(dirname "$0")/.."

NS=agent-sandbox SA=agent-sandbox-reader DURATION="${1:-168h}"
out=secrets/kubeconfig

kubectl -n "$NS" get serviceaccount "$SA" >/dev/null 2>&1 || {
  echo "ServiceAccount $NS/$SA missing - roll out k8s/agent-sandbox-readonly.yaml first (via a GitOps PR)." >&2; exit 1; }

server="$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')"
ca="$(kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')"
cluster="$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')"
token="$(kubectl -n "$NS" create token "$SA" --duration "$DURATION")"

case "$server" in *://127.0.0.1*|*://localhost*)
  echo "Warning: API server $server points to localhost - inside the container use host.docker.internal if needed." >&2;; esac

umask 077
mkdir -p secrets
cat >"$out" <<EOF
apiVersion: v1
kind: Config
clusters:
  - name: ${cluster}
    cluster:
      server: ${server}
      certificate-authority-data: ${ca}
users:
  - name: ${SA}
    user:
      token: ${token}
contexts:
  - name: ${cluster}-readonly
    context:
      cluster: ${cluster}
      user: ${SA}
current-context: ${cluster}-readonly
EOF

echo "→ wrote $out (valid for: $DURATION)"
if KUBECONFIG="$out" kubectl auth can-i create deployments -A >/dev/null 2>&1; then
  echo "ERROR: the token can write - deleting the file." >&2; rm -f "$out"; exit 1
fi
if KUBECONFIG="$out" kubectl auth can-i get secrets -A >/dev/null 2>&1; then
  echo "ERROR: the token can read secrets - deleting the file." >&2; rm -f "$out"; exit 1
fi
echo "✔ verified read-only (no write access, no secrets). In the sandbox: kubectl get nodes"
