# AI Inference Platform

Build a small, cost-capped Kubernetes platform (kind locally, AKS in a free trial) that serves open-weight models,
autoscales them, and measures them, to learn how to run AI inference on Kubernetes.

Full scope: [PROJECT.md](PROJECT.md). Before any session: [docs/guardrails.md](docs/guardrails.md).
CI: [docs/ci.md](docs/ci.md).

## Hard rules (agents and owner)

Copied from `PROJECT.md`.

1. **Free trial only.** The subscription stays a free trial. The owner never clicks "Upgrade". Total planned credit use
   is at most $60.
2. **Subscription pinning.** The owner's Azure login may have access to other subscriptions. Terraform requires
   `subscription_id` as an input with no default. Every Azure script starts with a guard that aborts unless
   `az account show` matches `AZURE_SUBSCRIPTION_ID`. The subscription id goes in a git-ignored `*.tfvars` or env var.
3. **Kubeconfig isolation.** The default kubeconfig may contain other clusters. Scripts and the harness never use it.
   They use `./.kube/kind-config` or `./.kube/aks-config` (git-ignored), always pass `--kubeconfig` and `--context`,
   and refuse any context not on the allow-list (`kind-afinf`, `afinf-aks`).
4. **Destroy after each session.** The `platform` Terraform layer (AKS, VNet, identities) is destroyed at the end of
   every AKS session. The `foundation` layer (ACR Basic, Key Vault, weights storage) and the state storage are small
   and persistent until the final teardown (issue 28).
5. **Budget alerts first.** Before the first `terraform apply`, the owner has set Cost Management budget alerts
   (about $25, $50, $100) and checked that the free trial spending limit is on (issue 02).
6. **Agents never run `az`, `terraform`, `kubectl` or `helm` against anything.** They write files. The owner runs
   `plan`, `apply`, `bootstrap` and `destroy`.
7. **vCPU cap.** Total regional vCPUs is 4. The design must fit in 4 vCPUs at all times: no node autoscaling beyond
   that, no AKS upgrades (they need surge capacity), no extra VMs (no jump host).
8. **Public repo hygiene.** The repo is public. Never commit subscription, tenant or object ids, public IPs, email
   addresses, real resource-group or account names with suffixes, or any secret. Those live in git-ignored `*.tfvars`,
   `backend.hcl` and env vars. Examples use obvious placeholders. The owner enables GitHub secret scanning and push
   protection (issue 01).
