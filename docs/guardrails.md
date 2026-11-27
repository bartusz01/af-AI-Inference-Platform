# Guardrails

The rules are in [PROJECT.md](../PROJECT.md). This is the checklist to apply them.
Do not paste the output of these commands into issues, PRs or commits: it contains real ids.

## Session-start checklist (AKS sessions)

- [ ] **Subscription.** The active one is the free trial, and it matches `AZURE_SUBSCRIPTION_ID`:

  ```bash
  az account show --query '{name:name, id:id}' -o table
  test "$(az account show --query id -o tsv)" = "${AZURE_SUBSCRIPTION_ID:?not set}" && echo OK || echo STOP
  ```

- [ ] **Kubeconfig and context.** Never the default kubeconfig. Use `./.kube/kind-config` or `./.kube/aks-config`,
  and only the contexts `kind-afinf` or `afinf-aks`. Pass both flags on every `kubectl` command
  (for `helm` the second flag is `--kube-context`). The AKS file exists only after the cluster does.

  ```bash
  kubectl --kubeconfig ./.kube/aks-config config get-contexts
  kubectl --kubeconfig ./.kube/aks-config --context afinf-aks get nodes
  ```

- [ ] **Budget alerts.** Cost Management alerts (about $25, $50, $100) exist, and the free trial spending limit is on
  (check in the Azure portal). Look at the credit used so far; the total stays under $60.
- [ ] **End time.** Decide when the session ends (under about 2 hours).

## Session-end checklist

- [ ] **Destroy** the `platform` layer, with the same variable file used for `apply`:

  ```bash
  terraform -chdir=infra/terraform/platform destroy -var-file=terraform.tfvars
  ```

- [ ] Check in the portal that no AKS cluster, node resource group, load balancer, public IP or unexpected disk is left.
  Only `foundation` and the state storage persist.

## Public repo

This repository is public. Anything pushed must be treated as published, even if removed later.

Owner-side steps:

- [ ] **Secret scanning and push protection:** Settings > Code security. Enable *Secret scanning* and
  *Push protection*.
- [ ] **Branch protection on `main`:** Settings > Branches (or Rules > Rulesets). Require a pull request before
  merging. After the first green run, also require the CI checks.
- [ ] **Before the first push** (and whenever in doubt), run both commands from the repo root.

  GUIDs that look like subscription, tenant or object ids, anywhere in history (the all-zero placeholder is
  filtered out). Expected output: nothing.

  ```bash
  git log --all -p | grep -ioE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' \
    | grep -vE '^0{8}-0{4}-0{4}-0{4}-0{12}$' | sort -u
  ```

  `.tfvars` files ever committed (`*.tfvars.example` is allowed and not matched). Expected output: nothing.

  ```bash
  git log --all --pretty=format: --name-only | grep -iE '\.tfvars(\.json)?$' | sort -u
  ```

- [ ] **Commit author emails** are public too. Check them, and use the GitHub `noreply` address if you prefer:

  ```bash
  git log --all --format='%ae%n%ce' | sort -u
  ```

If something real was pushed, rotate or revoke it first. Rewriting history alone is not enough.
