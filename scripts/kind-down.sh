#!/usr/bin/env bash
# Delete the local kind cluster "afinf" and its kubeconfig. See docs/kind.md.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
# shellcheck source=scripts/lib/kube-guard.sh
source scripts/lib/kube-guard.sh

cluster="afinf"
kubeconfig="./.kube/kind-config"

die() {
  echo "error: $*" >&2
  exit 1
}

for tool in docker kind; do
  command -v "$tool" >/dev/null 2>&1 || die "'${tool}' is not installed"
done
docker info >/dev/null 2>&1 ||
  die "no container runtime reachable with 'docker info'. Start Docker Desktop, or run 'colima start'."

kube_guard_kubeconfig "$kubeconfig"
export KUBECONFIG="$kubeconfig"

# If this fails, set -e stops here and the kubeconfig is kept.
kind delete cluster --name "$cluster" --kubeconfig "$kubeconfig"
rm -f "$kubeconfig"
# Remove .kube only if nothing else (for example aks-config) is in it.
rmdir ./.kube 2>/dev/null || true

echo "deleted cluster '${cluster}' and ${kubeconfig}"
