# Local cluster with kind

The free dev loop. To the scheduler it looks like AKS:

| Node | Label | Taint |
|---|---|---|
| control plane | | kind default |
| system worker | | none |
| inference worker | `workload=inference` | `workload=inference:NoSchedule` |

kind cannot use the Mac's GPU. Only the label and taint are mimicked. There are no host port mappings and no
ingress: use `kubectl port-forward`.

## Tools

`docker` (CLI), `kind`, `kubectl`, `curl` and `shasum`. All versions pinned here are **unverified**.

## Container runtime

Pick one. The scripts only use the plain `docker` CLI and `kind`, follow the active docker context, and never
start or stop the runtime. Give the runtime about 4 CPUs and 8 GB.

- **Docker Desktop:** start the app, then set 4 CPUs and about 8 GB RAM in Settings > Resources.
- **Colima** (command unverified):

  ```bash
  colima start --cpu 4 --memory 8
  ```

  To change the size of a running instance, run `colima stop` first.

See which runtime is active (marked with `*`):

```bash
docker context ls
docker info --format '{{.NCPU}} {{.MemTotal}}'
```

## Before the first start: pins

1. **Calico checksum.** `infra/kind/calico-version.txt` ships with `REPLACE_ME`, and `kind-up.sh` refuses to run
   until it is replaced. Download the manifest, review it (especially the image tags), and print its sha256:

   ```bash
   version=v3.31.0
   curl -fsSL -o "${TMPDIR:-/tmp}/calico.yaml" \
     "https://raw.githubusercontent.com/projectcalico/calico/${version}/manifests/calico.yaml"
   grep 'image:' "${TMPDIR:-/tmp}/calico.yaml"
   shasum -a 256 "${TMPDIR:-/tmp}/calico.yaml"
   ```

   Put the hash in place of `REPLACE_ME`, keep the `# pragma: allowlist secret` comment, and commit it.
   Also check that the Calico release supports the Kubernetes version of the node image.

2. **Node image.** `infra/kind/kind-config.yaml` pins `kindest/node:v1.34.0` by tag. The release notes of your
   `kind` version (`kind version`) list the matching images with digests. Preferably append the `@sha256:...`
   digest from those notes to all three `image:` lines.

## Start and stop

```bash
bash scripts/kind-up.sh
bash scripts/kind-down.sh
```

`kind-up.sh` checks the runtime, verifies the Calico manifest, creates the cluster (or reuses an existing one),
installs Calico and waits until the nodes are Ready. The first run pulls images and takes a few minutes.

`kind-down.sh` deletes the cluster and `./.kube/kind-config`. The runtime must be running.

The default kubeconfig (`~/.kube/config`) is never used. Always pass both flags:

```bash
kubectl --kubeconfig ./.kube/kind-config --context kind-afinf get pods -A
```

## Confirm labels and taints

```bash
kubectl --kubeconfig ./.kube/kind-config --context kind-afinf get nodes -L workload
kubectl --kubeconfig ./.kube/kind-config --context kind-afinf describe node -l workload=inference
```

The second command must show `Taints: workload=inference:NoSchedule`. A pod runs on that node only if it
tolerates the taint. To be placed there for certain, it also needs a node selector `workload: inference`.

## Why Calico

kind's default CNI (kindnet) is replaced because, for this project, NetworkPolicy must be enforced, and the kindnet
shipped with older kind releases accepts policies without enforcing them. Newer releases may add support, but an
explicit CNI gives the same behaviour whatever the kind version. Without enforcement, a default-deny policy would
look fine locally and protect nothing.

Calico is installed from one manifest, with no Helm release to manage. Cilium would also work but is expected to
use more memory, which is scarce here. The AKS network policy engine may differ, so test policies on both.

Calico needs host networking and privileged containers, as a CNI does. It is upstream software installed into
the local cluster only, not one of this project's workloads.

To check that policies are enforced, apply a default-deny policy in a scratch namespace and confirm that traffic
to a pod there times out.

## Multi-arch images

The Mac runs **arm64** nodes and AKS runs **amd64**. Every image used in this project must be multi-arch
(a manifest list with both). Check before adding one:

```bash
docker manifest inspect <image>:<tag>
```

## Troubleshooting

- `kind-up.sh` failed half way: fix the cause and run it again, or run `kind-down.sh` first.
- Pod network check: the Calico IP pool should match `podSubnet` in the kind config (`10.244.0.0/16`):

  ```bash
  kubectl --kubeconfig ./.kube/kind-config --context kind-afinf get ippools.crd.projectcalico.org -o yaml
  ```
