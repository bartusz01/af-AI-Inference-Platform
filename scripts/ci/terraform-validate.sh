#!/usr/bin/env bash
# init (no backend) + validate for every directory in the repo that contains .tf files.
# Directories named "modules" (not layers) or ".terraform" (downloads) are skipped, with everything below them.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

tf_files="$(find . -type d \( -name .git -o -name .terraform -o -name modules \) -prune \
  -o -type f -name '*.tf' -print)"
if [[ -z "$tf_files" ]]; then
  echo "nothing to check: no directory outside modules/ contains .tf files"
  exit 0
fi
layers="$(while IFS= read -r file; do dirname "$file"; done <<<"$tf_files" | sort -u)"

data="$(mktemp -d)"
trap 'rm -rf "$data"' EXIT
checked=0
while IFS= read -r layer; do
  layer="${layer#./}"
  echo "== $layer"
  init_args=(-backend=false -input=false)
  # A lock file in the checkout is a committed one: init must not change it.
  if [[ -f "$layer/.terraform.lock.hcl" ]]; then
    init_args+=(-lockfile=readonly)
  fi
  checked=$((checked + 1))
  # A throwaway data dir never touches a local, already initialised backend.
  # stdin is redirected so terraform cannot consume the list of layers.
  TF_DATA_DIR="$data/$checked" terraform -chdir="$layer" init "${init_args[@]}" </dev/null
  TF_DATA_DIR="$data/$checked" terraform -chdir="$layer" validate </dev/null
done <<<"$layers"
