"""Plan selected units, or apply their saved plans in the recorded order."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["plan", "apply"])
    parser.add_argument("--manifest", type=Path, required=True)
    args = parser.parse_args()
    manifest = args.manifest.resolve()
    data = json.loads(manifest.read_text())
    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
    if commit != data["commit"]:
        raise ValueError("Saved plans belong to a different Git commit")
    root = Path.cwd().resolve()
    app = root / "infra/environments/dev/aws/ap-southeast-1/api.example.com"
    for unit in data["units"]:
        directory = (root / unit).resolve()
        if not directory.is_relative_to(app) or not (directory / "terragrunt.hcl").is_file():
            raise ValueError(f"Invalid dev unit: {unit}")
        output = manifest.parent / directory.relative_to(app)
        output.mkdir(parents=True, exist_ok=True)
        command = ["terragrunt", "--working-dir", str(directory)]
        def run(*arguments, **kwargs):
            subprocess.run([*command, *arguments], check=True, **kwargs)
        if args.command == "plan":
            run("init", "-input=false")
            run("plan", "-input=false", "-lock-timeout=5m", "-out=" + str(output / "tfplan"))
            with (output / "plan.txt").open("w") as stream:
                run("show", "-no-color", str(output / "tfplan"), stdout=stream)
            shutil.copyfile(directory / ".terraform.lock.hcl", output / "terraform.lock.hcl")
        else:
            shutil.copyfile(output / "terraform.lock.hcl", directory / ".terraform.lock.hcl")
            run("init", "-input=false", "-lockfile=readonly")
            run("apply", "-input=false", "-lock-timeout=5m", str(output / "tfplan"))


if __name__ == "__main__":
    main()
