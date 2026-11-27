#!/usr/bin/env bash
# Render every chart in ci/helm-targets.txt and validate it with kubeconform.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

targets="ci/helm-targets.txt"
if [[ ! -f "$targets" ]]; then
  echo "nothing to check: $targets does not exist"
  exit 0
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
# Never use the caller's kubeconfig or Helm repository settings.
export KUBECONFIG=/dev/null
export HELM_REPOSITORY_CONFIG="$work/repositories.yaml"
export HELM_REPOSITORY_CACHE="$work/cache"

checked=0
# File descriptor 3 keeps commands in the loop from reading the target list.
while read -r repo url chart version values extra <&3 || [[ -n "${repo:-}" ]]; do
  [[ -n "${repo:-}" && "$repo" != \#* ]] || continue
  if [[ -z "$values" || -n "$extra" ]]; then
    echo "ERROR: $targets: expected 5 fields in line starting with '$repo'" >&2
    exit 1
  fi
  if [[ ! -f "$values" ]]; then
    echo "ERROR: values file not found: $values" >&2
    exit 1
  fi
  echo "== $repo/$chart $version ($values)"
  helm repo add --force-update "$repo" "$url"
  helm template "$chart" "$repo/$chart" --version "$version" -f "$values" |
    kubeconform -strict -summary
  checked=$((checked + 1))
done 3<"$targets"

if [[ "$checked" -eq 0 ]]; then
  echo "nothing to check: $targets has no entries"
fi
