#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

dir="infra/terraform"
if [[ ! -d "$dir" ]]; then
  echo "nothing to check: $dir does not exist"
  exit 0
fi
terraform fmt -check -diff -recursive "$dir"
