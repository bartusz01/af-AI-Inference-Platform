"""Print the YAML files under infra/ that kubeconform must check directly.

Fails closed: every YAML file is listed unless it is one of the documented exclusions.
Run from the repository root. Standard library only.
"""

import re
from pathlib import Path

KUSTOMIZATIONS = {"kustomization.yaml", "kustomization.yml", "Kustomization"}
KIND_CONFIG = Path("infra/kind/kind-config.yaml")
VALUES_NAME = re.compile(r"^(values([-.].+)?|.+[-.]values)\.ya?ml$")
TARGETS = Path("ci/helm-targets.txt")


def referenced_files(kustomization):
    """Return every existing file that a kustomization file mentions."""
    found = set()
    for line in kustomization.read_text(encoding="utf-8").splitlines():
        line = re.sub(r"(^|\s)#.*$", "", line)
        for token in re.split(r"[\s\[\]{},]+", line):
            token = token.strip("\"'").split("=")[-1].strip("\"'")
            if not token or token.endswith(":"):
                continue
            candidate = kustomization.parent / token
            if len(token) < 256 and candidate.is_file():
                found.add(candidate.resolve())
    return found


def helm_values_files():
    if not TARGETS.is_file():
        return set()
    rows = (line.split() for line in TARGETS.read_text(encoding="utf-8").splitlines())
    return {Path(r[4]).resolve() for r in rows if len(r) == 5 and not r[0].startswith("#")}


def main():
    files = sorted(p for p in Path("infra").rglob("*") if p.is_file())
    covered = helm_values_files() | {KIND_CONFIG.resolve()}
    for path in files:
        if path.name in KUSTOMIZATIONS:
            covered |= referenced_files(path)
    chart_dirs = {p.parent for p in files if p.name == "Chart.yaml"}
    for path in files:
        if path.suffix not in {".yaml", ".yml"} or path.name in KUSTOMIZATIONS:
            continue
        if VALUES_NAME.match(path.name) or path.resolve() in covered:
            continue
        if any(parent in chart_dirs for parent in path.parents):
            continue
        if ".terraform" in path.parts:
            continue
        print(path.as_posix())


if __name__ == "__main__":
    main()
