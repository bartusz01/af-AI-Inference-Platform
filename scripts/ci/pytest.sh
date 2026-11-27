#!/usr/bin/env bash
# Run pytest on harness/ and cost/, each only when it has tests.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

dirs=()
for dir in harness cost; do
  [[ -d "$dir" ]] || continue
  tests="$(find "$dir" -type f \( -name 'test_*.py' -o -name '*_test.py' \) -not -path '*/.venv/*')"
  if [[ -n "$tests" ]]; then
    dirs+=("$dir")
  fi
done

if [[ "${#dirs[@]}" -eq 0 ]]; then
  echo "nothing to check: no tests in harness/ or cost/"
  exit 0
fi

# A missing requirements file fails the job.
python -m pip install -r harness/requirements-dev.txt
for dir in "${dirs[@]}"; do
  pytest "$dir"
done
