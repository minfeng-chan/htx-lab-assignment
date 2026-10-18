"""Select changed dev units plus downstream dependents in dependency order."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess

APP = Path("infra/environments/dev/aws/ap-southeast-1/api.example.com")


def select(root, changed):
    units = {str(p.parent.relative_to(root)): p for p in (root / APP).rglob("terragrunt.hcl")}
    deps = {}
    for name, config in units.items():
        deps[name] = set()
        for relative in re.findall(r'config_path\s*=\s*"([^"$]+)"', config.read_text()):
            target = str((config.parent / relative).resolve().relative_to(root.resolve()))
            if target not in units:
                raise ValueError(f"Dependency outside dev application or missing: {name} -> {target}")
            deps[name].add(target)
    selected = set()
    for name in changed:
        path = Path(name)
        if path.suffix not in {".tf", ".hcl", ".tfvars"}:
            continue
        if name.startswith(str(APP) + "/") and path.name == "terragrunt.hcl" and not (root / path).exists():
            raise ValueError(f"Removed/moved unit requires explicit state migration or destroy review: {name}")
        if name.startswith("infra/modules/"):
            selected.update(units)  # Shared module changes: conservatively check every dev unit.
        for unit in units:
            directory = Path(unit)
            if directory in path.parents or (path.name in {"root.hcl", "account.hcl", "region.hcl", "env.hcl"} and path.parent in directory.parents):
                selected.add(unit)
    while True:
        dependents = {unit for unit in units if deps[unit] & selected}
        if dependents <= selected:
            break
        selected.update(dependents)
    ordered = []
    pending = set(selected)
    while pending:
        ready = sorted(unit for unit in pending if not (deps[unit] & pending))
        if not ready:
            raise ValueError("Cyclic Terragrunt dependencies")
        ordered.extend(ready)
        pending.difference_update(ready)
    return ordered


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    root = Path.cwd().resolve()
    base = subprocess.check_output(["git", "rev-parse", "--verify", "--end-of-options", args.base + "^{commit}"], text=True).strip()
    names = subprocess.check_output(["git", "diff", "--name-only", "--no-renames", "-z", base, "HEAD", "--", "infra"], text=True).split("\0")
    units = select(root, [name for name in names if name])
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps({"commit": subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip(), "units": units}, indent=2) + "\n")
    print("Selected units:", *units, sep="\n")
    if not units:
        print("No changed dev Terraform/Terragrunt units.")
    if os.environ.get("GITHUB_OUTPUT"):
        with open(os.environ["GITHUB_OUTPUT"], "a") as stream:
            stream.write(f"has_changes={'true' if units else 'false'}\n")


if __name__ == "__main__":
    main()
