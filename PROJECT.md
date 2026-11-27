# AI Inference Platform (af-AI-Inference-Platform)

> A small, cost-capped platform on Kubernetes (kind locally, AKS in a free trial) that serves open-weight models, autoscales them with KEDA, is deployed by Argo CD, and is measured with a Python benchmark and cost model. Built so the owner learns the skills for running AI inference on Kubernetes.

- **Owner:** bartusz01
- **Repo:** `bartusz01/af-AI-Inference-Platform` (to be created by the owner; **public**, see assumption A9 and hard rule 8)
- **Status:** Scoping
- **Last updated:** 2026-11-26 (rev 3: CI jobs and "CI is green", single-node sizing, runtime-neutral kind scripts, neutral wording)

## Goal
The owner knows Kubernetes but not how to run AI inference on it. At the end there is a working, documented platform that shows, hands-on and at small scale, these skills for running AI inference on Kubernetes:

| Skill | What we do here | Real or simulated |
|---|---|---|
| AKS, node pools | AKS via Terraform, a system pool and a tainted "inference" pool | Real |
| GPU node pools | GPU pool written in Terraform, validated with `plan` only, plus a doc | Simulated (no GPU quota) |
| KEDA | Autoscale the model server on request load via Prometheus metrics | Real |
| Private networking | VNet, NetworkPolicy default-deny, authorized API ranges; private endpoints as tier B | Real / partly optional |
| Storage for model weights | Blob (system of record) to a PVC (serving copy) via a Job | Real |
| CMK | Key Vault key, Disk Encryption Set (tier B) | Real but optional |
| Secrets | Key Vault + workload identity + CSI driver | Real |
| LLM serving (vLLM / SGLang) | llama.cpp server on CPU as the baseline; vLLM CPU as a stretch; GPU tuning for vLLM/SGLang as a doc | Real (CPU) / doc |
| Optimising inference performance | Benchmark harness: TTFT, tokens/s, p50/p95/p99 across concurrency | Real |
| Python benchmark and eval harnesses | `harness/` | Real |
| Cost literacy, self-hosted vs managed | Cost model fed by measured throughput | Real inputs, assumed prices flagged |
| Non-LLM models on the same platform | Embedding model served next to the LLM | Real |
| Model registry standards | Registry entries: owner, licence, evaluation, deprecation, with a validator | Real |
| Terraform and GitOps | Terraform for Azure, Argo CD for everything in the cluster | Real |

## Success criteria
- [ ] `terraform apply` creates the AKS platform in the personal free-trial subscription and `terraform destroy` removes it. Each session is under about 2 hours.
- [ ] The same stack runs on kind on the Mac. Both are installed by Argo CD from this repo (app-of-apps).
- [ ] A chat completion request through the in-cluster gateway (API key required, via `kubectl port-forward`) returns a response from `Qwen2.5-1.5B-Instruct` (Q4, Apache-2.0) on CPU, on both kind and AKS.
- [ ] KEDA scales the model server from 1 to 2 replicas under load from the Python harness and back down after it stops. Scale-up and scale-down times are recorded. Both replicas share one node, so this shows autoscaling mechanics (scale-up and scale-down times), not a throughput gain.
- [ ] A benchmark report gives TTFT, tokens/s, and p50/p95/p99 latency at several concurrency levels, plus a small quality eval score.
- [ ] A cost document compares self-hosted with managed inference ($ per 1M tokens, break-even load), using measured throughput and prices the owner filled in.
- [ ] A GPU node pool exists in Terraform (disabled by default) and passes `terraform plan`. A doc explains what changes on real GPUs.
- [ ] Tier B: an embedding model runs on the same platform, and the registry entries for both models validate (owner, licence, evaluation, deprecation).
- [ ] The total credit spent stays under **$60** (planned about $10), and nothing is billed to a card.
- [ ] Every pull request passes CI: yaml-lint, secret-scan, Terraform fmt, Terraform init (no backend) + validate, Helm render + kubeconform, kubeconform on manifests, shellcheck, ruff and pytest (issue 01). Agents cannot run these tools, so CI is their feedback.

## Non-goals
- GPU inference for real. The free-trial quota is zero for usable GPU families, and the owner will not upgrade the subscription.
- SGLang deployment (needs a GPU). It appears only in a doc.
- Multi-region, high availability, SLAs, production hardening beyond the Kubernetes conventions in the agent rules.
- Public exposure: no Ingress, no public LoadBalancer for the app, no DNS or TLS certificates.
- Training or fine-tuning models. Gated models that need a Hugging Face token.
- Using any Azure subscription or Kubernetes cluster other than the ones created for this project.
- Full observability stack (Grafana, Alertmanager, Log Analytics). Only a minimal Prometheus.

## Resources and constraints
- **Hardware:** MacBook Pro, Apple M5, 24 GB RAM, also used for other tasks at the same time. Keep the kind footprint to about 8 GB for the container runtime.
- **Local tools:** `kubectl`, `helm`, `kind`, `az`, `terraform` installed. Some need updates. A container runtime (Docker Desktop or Colima, the owner's decision, see A10) must be installed and running. Python 3.13.13 for the harness.
- **GitHub:** personal account `bartusz01`, repo `af-AI-Inference-Platform`. (The local git user name `Bart-AI-augmented` is only a local setting.)
- **Azure:** personal free trial, brand new, about $200 credit for 30 days, region `westeurope` (another region is fine). Quota seen on 2026-11-26: **Total Regional vCPUs = 4**, Dedicated vCPUs = 0, every modern GPU family = 0.
- **Budget:**
  - Azure: credit only, never upgrade. See the hard rules.
  - Claude: Claude Pro until **2026-12-04**, then a free account with much lower capacity. See "Work order".
  - Owner time: about 15 hours of hands-on time. This is a suggestion, to be reviewed after the first milestones.
- **Constraints:** one folder only, the owner's own GitHub account only, no third-party Claude plugins, no clusters other than the ones named in this spec.

### Hard rules for this project (agents and owner)
1. **Free trial only.** The subscription stays a free trial. The owner never clicks "Upgrade". Total planned credit use is at most $60.
2. **Subscription pinning.** The owner's Azure login may have access to other subscriptions. Terraform requires `subscription_id` as an input with no default. Every Azure script starts with a guard that aborts unless `az account show` matches `AZURE_SUBSCRIPTION_ID`. The subscription id goes in a git-ignored `*.tfvars` or env var.
3. **Kubeconfig isolation.** The default kubeconfig may contain other clusters. Scripts and the harness never use it. They use `./.kube/kind-config` or `./.kube/aks-config` (git-ignored), always pass `--kubeconfig` and `--context`, and refuse any context not on the allow-list (`kind-afinf`, `afinf-aks`).
4. **Destroy after each session.** The `platform` Terraform layer (AKS, VNet, identities) is destroyed at the end of every AKS session. The `foundation` layer (ACR Basic, Key Vault, weights storage) and the state storage are small and persistent until the final teardown (issue 28).
5. **Budget alerts first.** Before the first `terraform apply`, the owner has set Cost Management budget alerts (about $25, $50, $100) and checked that the free trial spending limit is on (issue 02).
6. **Agents never run `az`, `terraform`, `kubectl` or `helm` against anything.** They write files. The owner runs `plan`, `apply`, `bootstrap` and `destroy`.
7. **vCPU cap.** Total regional vCPUs is 4. The design must fit in 4 vCPUs at all times: no node autoscaling beyond that, no AKS upgrades (they need surge capacity), no extra VMs (no jump host).
8. **Public repo hygiene.** The repo is public. Never commit subscription, tenant or object ids, public IPs, email addresses, real resource-group or account names with suffixes, or any secret. Those live in git-ignored `*.tfvars`, `backend.hcl` and env vars. Examples use obvious placeholders. The owner enables GitHub secret scanning and push protection (issue 01).

### Agent limits (apply to every issue)
Agents cannot download anything or run `terraform`, `helm`, `docker`, `az`, `pytest` or `ruff`. So they cannot validate against real providers, charts or tests. **CI does that instead** (issue 01, assumption A17). Every issue that adds Terraform, Helm or manifest, or Python code has "CI is green" as an acceptance criterion, and no acceptance criterion may require an agent to run those tools. Every PR must still list the exact commands the owner runs for what CI cannot check (`terraform init -backend-config`, `plan`, `apply`, tests on a cluster), and must state every version it pinned, marked "unverified". Pinned versions are checked by the owner at review. If a needed version or image tag is unknown, the agent writes the best-known pin and flags it. It does not use `latest`. It never invents a checksum: an unknown sha256 is written as `REPLACE_ME`.

## Security requirements
- **Data sensitivity:** none. Prompts and the eval set are synthetic and written for this project. No personal or confidential data enters the cluster.
- **Exposure:** local-only access. All Services are `ClusterIP`. Access is by `kubectl port-forward`. The AKS API server is public but restricted with `api_server_authorized_ip_ranges` (owner's IP, a variable, not committed). No Ingress.
- **Secrets:** never in git, never read or printed by agents. Terraform state and `*.tfvars` are git-ignored. State lives in an Azure Storage account with Entra ID auth (no keys). The gateway API key lives in Key Vault, reaches pods through workload identity + the CSI driver on AKS, and is a manually created Secret on kind. The owner creates secret values with documented commands that never echo them. Because the repo is public, Argo CD reads it anonymously and needs no credential. Nothing sensitive may be in the repo for that reason (hard rule 8).
- **Cluster hygiene:** the Kubernetes conventions in `rules/agent-rules.md` apply (limits, securityContext, pinned images, default-deny NetworkPolicy, probes, no wildcard RBAC). Namespaces get Pod Security `restricted` labels.
- **Models:** only models with a clear open licence (SPDX recorded in the registry). Weights are pinned by sha256.

## Architecture in one paragraph
Terraform has three layers. `bootstrap` (state storage, a script), `foundation` (persistent: ACR Basic, Key Vault, weights storage account), and `platform` (per session: VNet, AKS Free tier with a system pool of 1 x 2 vCPU and a tainted inference pool of 1 x 2 vCPU, workload identities). Argo CD (installed by a script) syncs `infra/gitops/` from this repo. Namespaces: `argocd`, `keda`, `monitoring`, `inference`. In `inference`: llama.cpp server(s) on the inference pool with weights on a PVC, an nginx gateway (API key, rate limit), and later an embeddings server. Prometheus scrapes the model server, and KEDA scales it from those metrics. Python tools in `harness/` and `cost/` measure and price it. kind mimics the same two pools with node labels and taints.

## Milestones
Tier A = must, B = nice, C = stretch. Issue files are in `issues/`.

| # | Milestone | Definition of done | Issues |
|---|---|---|---|
| 1 | Guardrails and Azure foundation | Repo skeleton and ignore rules exist, and the CI jobs run green on it. Subscription guard and cost runbook exist and budget alerts are set. State storage and the foundation layer plan and apply cleanly. | 01 (A), 02 (A), 03 (A), 04 (A) |
| 2 | Clusters and GitOps | kind cluster comes up and down with one script. AKS platform plans and applies. Argo CD manages a root app that creates the namespaces with default-deny on both clusters. | 05 (A), 06 (A), 07 (A), 08 (A), 09 (A), 10 (A) |
| 3 | Serving platform | Chat request through the gateway works on kind and on AKS. KEDA, Prometheus, secrets and weights loading all work. The smoke test passes. | 11 to 17 (A) |
| 4 | Measure and compare | Benchmark, eval, scale test and cost model run and their results are written up. | 18 to 21 (A) |
| 5 | Breadth | Embedding model, model registry and the real-AKS-GPU doc exist. Private endpoints and CMK are written and planned. | 22 (B), 23 (B), 24 (B), 25 (B), 26 (B), 27 (C) |
| 6 | Wrap-up | README, architecture diagram, lessons learned, and a teardown script that leaves nothing billable. | 28 (A) |

### Work order (because Claude Pro ends 2026-12-04)
Agents' capacity drops after that, and writing code is the part that needs it. The owner's own `apply` sessions do not. So create and work the issues in this order:
1. **Wave 1, local only, no Azure needed:** 01, 08, 09, 10, 11 (kind part), 12, 13, 14, 16, 17, 18.
2. **Wave 2, written now, applied later:** 03, 04, 05, 06, 07, 15, 02. (Do 02 and set the budget alerts before the first apply.)
3. **Wave 3:** 19, 20, 21, then tier B (22 to 26), then 28.

The Azure 30-day clock probably started when the subscription was created. Don't run `apply` until Wave 1 is done and reviewed. Terraform can be written and planned earlier at no cost.

### Cost estimate (unverified, check the Azure pricing calculator)
AKS Free tier has no control-plane fee. Two `Standard_D2s_v5` nodes cost about $0.1/h each, plus a Standard LB and public IP (about $0.03/h) and small disks, so roughly **$0.3/h**. Six 2-hour sessions come to about $4 to $5. Persistent items (ACR Basic about $5/month, Key Vault, storage) come to about $6/month. The 4-vCPU cap, not credit, is the binding limit.

## Assumptions
Each is open to challenge. Items marked (confirmed) were confirmed by the owner.
- A1. Region `westeurope`. Another region is acceptable if a VM size is not available.
- A2. VM size `Standard_D2s_v5` (amd64) (confirmed available in westeurope on 2026-11-26, but **only in zone 1**; zones 2 and 3 are `NotAvailableForSubscription`). So both node pools are pinned to `zones = ["1"]` (a variable), Azure Disk PVCs are LRS and live in zone 1, and there is no zone redundancy. If AKS rejects zone pinning, fall back to no zones. An ARM size (`Standard_D2ps_v6`) would match the Mac's images but is not assumed. All images must be multi-arch, because kind on the Mac runs arm64 and AKS runs amd64.
- A3. Node plan is 1 x 2 vCPU system pool plus 1 x 2 vCPU inference pool, with no spare capacity and **no node autoscaling**. The inference pool is a single 2-vCPU node, so **both model-server replicas (KEDA maximum 2) must fit on it together**. Each model-server pod therefore requests **at most 0.8 CPU and 2 GB** (write `2G`, not `2Gi`, which is slightly larger). Arithmetic (unverified, the owner checks `kubectl describe node`): allocatable is about 1.9 CPU and about 5.5 GB, so 2 x 0.8 = 1.6 CPU and 2 x 2 = 4 GB leave about 0.3 CPU and 1.5 GB for node DaemonSets and the embeddings server (issue 22, which may not fit; see that issue). CPU is the binding limit, not memory. Because a third pod cannot be scheduled, the model-server Deployment must not surge during a rolling update (issue 12). Fallback: a single 4-vCPU `Standard_D4s_v5` pool, selectable by a Terraform variable.
- A4. Model: `Qwen2.5-1.5B-Instruct` GGUF Q4_K_M (Apache-2.0, ungated), served by llama.cpp `llama-server` (OpenAI-compatible, `/metrics`). The 3B variant has a different licence, so do not swap it in without checking.
- A5. vLLM on CPU is a stretch only, because arm64 support is uncertain and it needs amd64 and more RAM. SGLang is out.
- A6. Prometheus (minimal) plus the KEDA Prometheus scaler, not the KEDA HTTP add-on (beta).
- A7. Terraform state in Azure Storage (Entra ID auth, versioning, soft delete) in its own resource group, created by a script the owner runs. For a client I would also use a separate subscription for state, private access, and CI with OIDC. These are out of scope here.
- A8. Key Vault and weights storage are persistent (a destroyed Key Vault keeps its name reserved while soft-deleted). The CMK vault (tier B) uses a random name and 7-day retention.
- A9. (confirmed) The repo is public on the owner's free GitHub account (private repos are possible on the free plan, but public is simpler: no Argo CD credential). Consequence: hard rule 8, secret scanning and push protection on, and no real ids in the repo.
- A10. (confirmed) The owner is fine with either Docker Desktop (free for personal use) or Colima, and picks one at install time. The kind scripts and docs use only the plain `docker` CLI and `kind`, so either works. Nothing may depend on a Docker Desktop-only feature. Guide for the runtime VM: 4 CPUs and about 8 GB.
- A11. The Azure free trial has a spending limit that stops resources instead of billing when credit runs out. The owner verifies this in the portal.
- A12. Budget alerts via Terraform may not be supported on the free trial, so issue 02 is a runbook first and Terraform second.
- A13. The 15-hour budget is the owner's hands-on time and is a guide, not a cap. Agents' working time is not counted.
- A14. (confirmed) Python 3.13.13 locally. Code targets 3.11+ (stdlib `tomllib`), with `httpx` as the only runtime dependency of the harness.
- A15. Image and chart versions are chosen by agents from their knowledge and flagged unverified, since they cannot check registries.
- A16. The prompts for benchmark and eval are written from scratch for this project, with no external datasets.
- A17. CI policy (issue 01, `.github/workflows/checks.yml`): one job per check. Only official `actions/*` actions are used (no other third-party actions). Terraform, Helm, kubeconform, shellcheck, kubectl (if needed) and ruff are direct downloads from the vendor with a pinned version and a `sha256sum -c` check. Every pinned version is unverified until the owner confirms it. Agents cannot download, so they do not know the sha256 values: they write `REPLACE_ME`, the job fails closed on it, and the owner fills the values in before merging.
- A18. Issue 01 carries the labels `agent:infra` AND `ci`, because the runner only allows changes to `.github/workflows/` on `ci`-labelled issues.

## Open questions for the owner
- **Checksums (issue 01):** the owner fills in the sha256 values left as `REPLACE_ME` in the CI workflow, from the commands listed in that PR, before merging it.
- **Label `ci` on issue 23:** issue 23 also edits `checks.yml`. If it should keep that step, it needs the `ci` label too. Left unchanged; no answer given yet.
- **Issue 22 fit:** with the LLM pods at 0.8 CPU each, the embeddings server probably does not fit on the inference node next to two replicas (see issue 22). Owner decided not to decide now; the PR for issue 22 must do the arithmetic and propose a fix.
- Still to do on the owner's side: set the budget alerts and check the spending limit (issue 02) before the first `apply`.

## Change history
| Date | Change | PR |
|---|---|---|
| 2026-11-26 | Initial scope (draft in `scratch/`) | n/a |
| 2026-11-26 | Rev 2: public repo (rule 8, A9), Python 3.13 (A14), zone-1-only quota for D2s_v5 (A2); issues 01, 05, 09, 10 updated | n/a |
| 2026-11-26 | Rev 3: issue 01 adds CI jobs (labels `agent:infra` + `ci`; A17, A18); "CI is green" replaces agent-run checks in all Terraform and Python issues; model-server pods request at most 0.8 CPU and 2 GB on the single inference node (A3; issues 12, 14, 22); scale-test report wording (issue 20); runtime-neutral kind scripts (A10, issue 08); neutral public wording everywhere | n/a |
| 2026-11-26 | Rev 3b: `shellcheck` CI job added to issue 01 (7 jobs); Helm charts of issues 13 and 14 registered in `ci/helm-targets.txt`; "CI is green (shellcheck)" added to every issue with shell scripts; A10 confirmed (Docker Desktop or Colima, either) | n/a |
