#!/usr/bin/env bash
# init (no backend) + validate for every layer in infra/terraform/. "modules" is not a layer.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

base="infra/terraform"
if [[ ! -d "$base" ]]; then
  echo "nothing to check: $base does not exist"
  exit 0
fi

data="$(mktemp -d)"
trap 'rm -rf "$data"' EXIT
checked=0
for layer in "$base"/*/; do
  layer="${layer%/}"
  name="${layer##*/}"
  [[ -d "$layer" && "$name" != "modules" ]] || continue
  tf_files="$(find "$layer" -maxdepth 1 -type f -name '*.tf')"
  [[ -n "$tf_files" ]] || continue
  echo "== $layer"
  # A throwaway data dir never touches a local, already initialised backend.
  TF_DATA_DIR="$data/$name" terraform -chdir="$layer" init -backend=false -input=false
  TF_DATA_DIR="$data/$name" terraform -chdir="$layer" validate
  checked=$((checked + 1))
done

if [[ "$checked" -eq 0 ]]; then
  echo "nothing to check: no layer under $base contains .tf files"
fi
