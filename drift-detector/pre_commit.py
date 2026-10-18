"""Run the risk detector against staged IaC only. No external dependencies."""
import json
from pathlib import Path
import subprocess
import sys

from detector import analyse


def main():
    root = Path(subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip())
    diff = subprocess.check_output(
        ["git", "diff", "--cached", "--no-ext-diff", "--no-renames", "--unified=80", "--", "infra"],
        cwd=root, text=True)
    report = analyse(diff)
    output = root / "reports/pre-commit-risk.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
    if report["summary"]["high"]:
        print("Commit blocked: high-risk IaC changes. Review reports/pre-commit-risk.json.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f"Risk check failed: {error}", file=sys.stderr)
        sys.exit(2)
