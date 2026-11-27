# CI

Workflow: `.github/workflows/checks.yml`. It runs on pull requests and on pushes to `main`, with
`permissions: contents: read` and no secrets. Agents cannot run these tools, so CI is their feedback.

## Jobs

| Job | Checks | Does not check |
|---|---|---|
| `yaml-lint` | `yamllint --strict .` | meaning of the YAML |
| `secret-scan` | `detect-secrets` on all files | git history; ids such as plain GUIDs may pass |
| `terraform-fmt` | formatting under `infra/terraform/` | correctness |
| `terraform-validate` | `init -backend=false` and `validate` per layer (`modules/` is not a layer) | never calls Azure: no `plan`, quota, SKU or permission checks |
| `helm-kubeconform` | renders each chart in `ci/helm-targets.txt`, then `kubeconform -strict` | install behaviour, anything needing a cluster |
| `kubeconform-manifests` | every kustomization under `infra/`, plus uncovered YAML | CRD resources (see below), admission, policy |
| `ruff` | `ruff check harness cost` (default rules, `ruff.toml`) | formatting |
| `pytest` | `pytest harness`, `pytest cost`, each only if it has tests | anything needing a cluster or Azure |
| `shellcheck` | every `*.sh` under `scripts/` | runtime behaviour |

Nothing in CI needs a cluster. A job with nothing to check says so and passes. Tool installation still runs, so a
wrong or missing checksum fails the job even then.

### CRDs and schemas

`kubeconform-manifests` uses `-ignore-missing-schemas`: **CRD resources (Argo CD, KEDA, SecretProviderClass) are
skipped because their schemas are missing.** A mistyped `kind` is skipped the same way, so read the "Skipped" count.

`helm-kubeconform` uses `-strict` without that flag. A chart that renders a kind with no schema (this can include
`CustomResourceDefinition`) fails the job; the issue that adds such a chart has to deal with it.

### What counts as a plain manifest

Every `*.yaml` / `*.yml` under `infra/` is checked, except: `kustomization.yaml`; files that a kustomization
mentions; `infra/kind/kind-config.yaml`; Helm values files (listed in `ci/helm-targets.txt`, or named `values.yaml`,
`values-*.yaml`, `*-values.yaml`, `*.values.yaml`); and everything inside a local chart (a directory with
`Chart.yaml`), which is **not** checked unless a job is added for it.

## Run locally

From the repo root, with the tools installed on your machine (versions may differ from CI):

```bash
yamllint --strict .
bash scripts/ci/terraform-fmt.sh
bash scripts/ci/terraform-validate.sh
bash scripts/ci/helm-kubeconform.sh
bash scripts/ci/kubeconform-manifests.sh
bash scripts/ci/ruff.sh
bash scripts/ci/pytest.sh          # installs packages: activate a virtualenv first
bash scripts/ci/shellcheck.sh
pip install detect-secrets==1.5.0 && detect-secrets scan --all-files --exclude-files '^[.]git/|^[.]venv/'
```

`detect-secrets scan` prints JSON; `results` must be empty. Local ignored files (`.kube/`, `*.tfvars`) can show up
there although CI never sees them. Never share that output.

The scripts use a temporary Terraform data directory and Helm repo config, and set `KUBECONFIG=/dev/null`.
`install-tool.sh` downloads Linux amd64 binaries, so do not use it to install on a Mac.

If you commit a `.terraform.lock.hcl` created on the Mac, add the CI platform's hashes first:
`terraform -chdir=infra/terraform/<layer> providers lock -platform=linux_amd64 -platform=darwin_arm64`.

## Add a Helm target

Add one line to `ci/helm-targets.txt`:

```text
<repo-name> <repo-url> <chart> <version> <values-file>
```

Pin the version. The values file path is relative to the repo root and must exist. Only HTTP(S) chart repositories
work (`helm repo add`), not `oci://`.

## Pinned versions

All versions are **unverified**: they were chosen without access to any registry.

| Tool | Version | URL | Checksum status |
|---|---|---|---|
| terraform | 1.13.5 | <https://releases.hashicorp.com/terraform/1.13.5/terraform_1.13.5_linux_amd64.zip> | `REPLACE_ME` |
| helm | 3.19.0 | <https://get.helm.sh/helm-v3.19.0-linux-amd64.tar.gz> | `REPLACE_ME` |
| kubeconform | 0.7.0 | <https://github.com/yannh/kubeconform/releases/download/v0.7.0/kubeconform-linux-amd64.tar.gz> | `REPLACE_ME` |
| ruff | 0.14.5 | <https://github.com/astral-sh/ruff/releases/download/0.14.5/ruff-x86_64-unknown-linux-gnu.tar.gz> | `REPLACE_ME` |
| shellcheck | 0.11.0 | <https://github.com/koalaman/shellcheck/releases/download/v0.11.0/shellcheck-v0.11.0.linux.x86_64.tar.xz> | `REPLACE_ME` |
| kubectl | runner image | preinstalled on `ubuntu-24.04` | not downloaded |
| actions/checkout | v4 | GitHub Actions | tag, not a commit SHA |
| actions/setup-python | v5 | GitHub Actions | tag, not a commit SHA |
| Python | 3.13 | via `actions/setup-python` | latest patch |
| yamllint | 1.35.1 | PyPI (template job) | no hash check |
| detect-secrets | 1.5.0 | PyPI (template job) | no hash check |

Not pinned: the kubeconform schemas (fetched at run time, default Kubernetes version), Terraform providers (pinned by
each layer's lock file) and the runner image contents.

## Update a pinned tool

1. Change the version in `ci/tool-versions.env` (the only place CI reads it).
2. Get the URL and checksum, and compare the result with the checksum the vendor publishes for that release:

   ```bash
   url="$(bash scripts/ci/install-tool.sh --url terraform)"
   curl -fsSL "$url" | shasum -a 256
   ```

3. Put the 64-character value in `ci/tool-versions.env`, keeping the `# pragma: allowlist secret` comment.
4. Update the table above and open a PR.
