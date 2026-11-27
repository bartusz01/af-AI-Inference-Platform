#!/usr/bin/env bash
# Download, verify (sha256) and unpack pinned CI tools. Fails closed.
# Usage: install-tool.sh <tool>...        install into $TOOLS_DIR (Linux amd64, for CI)
#        install-tool.sh --url <tool>     print the download URL only
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
versions="$root/ci/tool-versions.env"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

# Sets: version, sha, url, member (path of the binary inside the archive)
lookup() {
  local tool="$1" line
  line="$(awk -v t="$tool" '$1 == t { print $2, $3 }' "$versions")"
  [[ -n "$line" ]] || die "tool '$tool' is not listed in ci/tool-versions.env"
  [[ "$line" != *$'\n'* ]] || die "tool '$tool' is listed more than once"
  read -r version sha <<<"$line"
  case "$tool" in
    terraform)
      url="https://releases.hashicorp.com/terraform/${version}/terraform_${version}_linux_amd64.zip"
      member="terraform"
      ;;
    helm)
      url="https://get.helm.sh/helm-v${version}-linux-amd64.tar.gz"
      member="linux-amd64/helm"
      ;;
    kubeconform)
      url="https://github.com/yannh/kubeconform/releases/download/v${version}/kubeconform-linux-amd64.tar.gz"
      member="kubeconform"
      ;;
    ruff)
      url="https://github.com/astral-sh/ruff/releases/download/${version}/ruff-x86_64-unknown-linux-gnu.tar.gz"
      member="ruff-x86_64-unknown-linux-gnu/ruff"
      ;;
    shellcheck)
      url="https://github.com/koalaman/shellcheck/releases/download/v${version}/shellcheck-v${version}.linux.x86_64.tar.xz"
      member="shellcheck-v${version}/shellcheck"
      ;;
    *) die "no download rule for tool '$tool'" ;;
  esac
}

if [[ "${1:-}" == "--url" ]]; then
  [[ $# -eq 2 ]] || die "usage: install-tool.sh --url <tool>"
  lookup "$2"
  echo "$url"
  exit 0
fi

[[ $# -gt 0 ]] || die "usage: install-tool.sh <tool>..."

tools_dir="${TOOLS_DIR:-${RUNNER_TEMP:?set TOOLS_DIR or RUNNER_TEMP}/tools}"
mkdir -p "$tools_dir"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

for tool in "$@"; do
  lookup "$tool"
  [[ "$sha" != "REPLACE_ME" ]] ||
    die "$tool $version: sha256 is REPLACE_ME. Fill it in ci/tool-versions.env: curl -fsSL $url | shasum -a 256"
  [[ "$sha" =~ ^[0-9a-f]{64}$ ]] || die "$tool: sha256 must be 64 lowercase hex characters"

  mkdir -p "$work/$tool/out"
  archive="$work/$tool/${url##*/}"
  curl -fsSL --proto '=https' --tlsv1.2 --retry 3 -o "$archive" "$url"
  echo "$sha  $archive" | sha256sum -c -

  case "$archive" in
    *.zip) unzip -q "$archive" -d "$work/$tool/out" ;;
    *.tar.gz) tar -xzf "$archive" -C "$work/$tool/out" ;;
    *.tar.xz) tar -xJf "$archive" -C "$work/$tool/out" ;;
    *) die "$tool: unknown archive type" ;;
  esac
  install -m 0755 "$work/$tool/out/$member" "$tools_dir/$tool"
  echo "installed $tool $version into $tools_dir"
done

# Put the tools first on PATH for later workflow steps.
if [[ -n "${GITHUB_PATH:-}" ]]; then
  echo "$tools_dir" >>"$GITHUB_PATH"
fi
