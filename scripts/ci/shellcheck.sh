#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

if [[ ! -d scripts ]]; then
  echo "nothing to check: scripts/ does not exist"
  exit 0
fi

list="$(mktemp)"
trap 'rm -f "$list"' EXIT
find scripts -type f -name '*.sh' >"$list"

files=()
while read -r file; do
  files+=("$file")
done <"$list"

if [[ "${#files[@]}" -eq 0 ]]; then
  echo "nothing to check: no *.sh files under scripts/"
  exit 0
fi
printf 'checking %s\n' "${files[@]}"
shellcheck -x "${files[@]}"
