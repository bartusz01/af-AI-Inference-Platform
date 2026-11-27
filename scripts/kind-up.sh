#!/usr/bin/env bash
# Create the local kind cluster "afinf" with Calico. Safe to run again. See docs/kind.md.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
# shellcheck source=scripts/lib/kube-guard.sh
source scripts/lib/kube-guard.sh

cluster="afinf"
context="kind-afinf"
kubeconfig="./.kube/kind-config"
config="infra/kind/kind-config.yaml"
calico_pin="infra/kind/calico-version.txt"
min_cpus=4
# A VM set to 8 GB reports a bit less than that, so the threshold is lower.
min_mem_bytes=7500000000

die() {
  echo "error: $*" >&2
  exit 1
}

runtime_help="no container runtime reachable with 'docker info'. Start Docker Desktop, or run 'colima start'.
Check the active docker context with 'docker context ls'."

for tool in docker kind kubectl curl shasum; do
  command -v "$tool" >/dev/null 2>&1 || die "'${tool}' is not installed"
done

# Preflight
docker info >/dev/null 2>&1 || die "$runtime_help"
resources="$(docker info --format '{{.NCPU}} {{.MemTotal}}')" || die "$runtime_help"
read -r cpus mem_bytes <<<"$resources"
# Some docker CLI versions exit 0 without a daemon and report zero CPUs.
[[ "$cpus" =~ ^[1-9][0-9]*$ && "$mem_bytes" =~ ^[0-9]+$ ]] || die "$runtime_help"
if ((cpus < min_cpus || mem_bytes < min_mem_bytes)); then
  echo "warning: the runtime has ${cpus} CPUs and ${mem_bytes} bytes of memory; 4 CPUs and about 8 GB are advised." >&2
  echo "warning: Docker Desktop: Settings > Resources. Colima: 'colima stop', then" >&2
  echo "warning: 'colima start --cpu 4 --memory 8' (see docs/kind.md)." >&2
fi

kube_guard_kubeconfig "$kubeconfig"
kube_guard_context "$context"

# Download and verify Calico first, so a bad pin fails before a cluster is created.
read -r calico_version calico_sha _ < <(grep -v '^#' "$calico_pin")
[[ "$calico_sha" =~ ^[0-9a-f]{64}$ ]] || die "no sha256 for Calico ${calico_version} in ${calico_pin} (see docs/kind.md)"

manifest="$(mktemp)"
trap 'rm -f "$manifest"' EXIT
curl --fail --silent --show-error --location --proto '=https' --output "$manifest" \
  "https://raw.githubusercontent.com/projectcalico/calico/${calico_version}/manifests/calico.yaml"
actual_sha="$(shasum -a 256 "$manifest")"
[[ "${actual_sha%% *}" == "$calico_sha" ]] || die "sha256 mismatch for the Calico ${calico_version} manifest"

mkdir -p ./.kube
# Nothing in this script may fall back to the default kubeconfig.
export KUBECONFIG="$kubeconfig"

clusters="$(kind get clusters)"
if grep -qx "$cluster" <<<"$clusters"; then
  echo "cluster '${cluster}' already exists: refreshing ${kubeconfig}"
  kind export kubeconfig --name "$cluster" --kubeconfig "$kubeconfig"
else
  kind create cluster --name "$cluster" --config "$config" --kubeconfig "$kubeconfig"
fi

current="$(kubectl --kubeconfig "$kubeconfig" config current-context)"
[[ "$current" == "$context" ]] || die "expected context '${context}' in ${kubeconfig}, found '${current}'"

# Server-side apply: the Calico CRDs can be too large for client-side apply.
guarded_kubectl "$kubeconfig" "$context" apply --server-side -f "$manifest"
guarded_kubectl "$kubeconfig" "$context" -n kube-system rollout status daemonset/calico-node --timeout=300s
guarded_kubectl "$kubeconfig" "$context" wait --for=condition=Ready nodes --all --timeout=300s
guarded_kubectl "$kubeconfig" "$context" get nodes -L workload

echo "ready: use --kubeconfig ${kubeconfig} --context ${context}"
