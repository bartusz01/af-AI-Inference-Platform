#!/usr/bin/env bash
# Kubeconfig isolation (PROJECT.md hard rule 3). Source this file, do not run it.
# Minimal version created by issue 08; issue 07 may extend it.
# Callers must run from the repository root.

# Abort unless the path is one of the project kubeconfigs and is not a symlink.
kube_guard_kubeconfig() {
  local kubeconfig="${1:-}"
  case "$kubeconfig" in
    ./.kube/kind-config | ./.kube/aks-config) ;;
    *)
      echo "kube-guard: refusing kubeconfig '${kubeconfig}'" >&2
      return 1
      ;;
  esac
  # A symlink could point at the default kubeconfig.
  if [[ -L ./.kube || -L "$kubeconfig" ]]; then
    echo "kube-guard: refusing symlinked kubeconfig '${kubeconfig}'" >&2
    return 1
  fi
}

# Abort unless the context is on the allow-list.
kube_guard_context() {
  local context="${1:-}"
  case "$context" in
    kind-afinf | afinf-aks) ;;
    *)
      echo "kube-guard: refusing context '${context}'" >&2
      return 1
      ;;
  esac
}

# Run kubectl with an allowed kubeconfig and context.
# Usage: guarded_kubectl <kubeconfig> <context> <kubectl arguments...>
guarded_kubectl() {
  local kubeconfig="${1:-}"
  local context="${2:-}"
  kube_guard_kubeconfig "$kubeconfig" || return 1
  kube_guard_context "$context" || return 1
  shift 2
  kubectl --kubeconfig "$kubeconfig" --context "$context" "$@"
}
