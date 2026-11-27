#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

dirs=()
for dir in harness cost; do
  [[ -d "$dir" ]] || continue
  py_files="$(find "$dir" -type f -name '*.py' -not -path '*/.venv/*')"
  if [[ -n "$py_files" ]]; then
    dirs+=("$dir")
  fi
done

if [[ "${#dirs[@]}" -eq 0 ]]; then
  echo "nothing to check: no Python files in harness/ or cost/"
  exit 0
fi
ruff check "${dirs[@]}"
