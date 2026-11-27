#!/usr/bin/env bash
# kubeconform on every kustomization under infra/ and on manifests no kustomization covers.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

if [[ ! -d infra ]]; then
  echo "nothing to check: infra/ does not exist"
  exit 0
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
export KUBECONFIG=/dev/null

# Lists go through files so that a failing find or python3 fails the job.
find infra -type f \( -name kustomization.yaml -o -name kustomization.yml -o -name Kustomization \) \
  >"$work/kustomizations"
python3 -I scripts/ci/list_plain_manifests.py >"$work/plain"

checked=0
while read -r file <&3; do
  dir="$(dirname "$file")"
  echo "== kustomize $dir"
  kubectl kustomize "$dir" >"$work/rendered.yaml"
  kubeconform -strict -ignore-missing-schemas -summary "$work/rendered.yaml"
  checked=$((checked + 1))
done 3<"$work/kustomizations"

plain=()
while read -r file; do
  plain+=("$file")
done <"$work/plain"
if [[ "${#plain[@]}" -gt 0 ]]; then
  echo "== plain manifests: ${plain[*]}"
  kubeconform -strict -ignore-missing-schemas -summary "${plain[@]}"
  checked=$((checked + 1))
fi

if [[ "$checked" -eq 0 ]]; then
  echo "nothing to check: no kustomizations or plain manifests under infra/"
fi
