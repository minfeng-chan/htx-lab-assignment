"""Conservative pre-plan triage of unified Terraform/Terragrunt diffs.

This is a textual risk screen, not an HCL evaluator or a live drift scanner.
"""
import argparse
import json
import re
import sys
from pathlib import Path


def analyse(diff):
    if diff.strip() and not diff.startswith("diff --git "):
        raise ValueError("Expected a unified git diff beginning with diff --git")
    findings = []
    for block in re.split(r"(?=^diff --git )", diff, flags=re.M):
        if not block.strip():
            continue
        header = block.splitlines()[0]
        path = header.split(" b/", 1)[-1]
        if not path.endswith((".tf", ".hcl", ".tfvars", ".json")):
            continue
        added = [line[1:] for line in block.splitlines() if line.startswith("+") and not line.startswith("+++")]
        removed = [line[1:] for line in block.splitlines() if line.startswith("-") and not line.startswith("---")]
        # Ignore exact/whitespace-only replacements, including formatter changes.
        normalize = lambda line: re.sub(r"\s+", "", line)
        adds = {normalize(line) for line in added}
        removes = {normalize(line) for line in removed}
        plus = "\n".join(line for line in added if normalize(line) not in removes)
        minus = "\n".join(line for line in removed if normalize(line) not in adds)
        if not plus.strip() and not minus.strip():
            continue
        def emit(level, reason, recommendation):
            findings.append({"change_description": f"Configuration change in {path}",
                             "risk_level": level, "reasoning": reason,
                             "recommendation": recommendation})
        initial = len(findings)
        if re.search(r"0\.0\.0\.0/0|::/0", plus):
            emit("high", "New unrestricted IPv4/IPv6 network range; ingress or egress requires review.",
                 "Limit the source/destination to the approved CIDR or security group.")
        wildcard_action = re.search(r'(?is)(?:actions?|not_actions)\s*[=:]\s*\[[^\]]*[\"\'][^\"\']*\*[^\"\']*[\"\']', plus)
        wildcard_resource = re.search(r'(?is)(?:resources?|not_resources)\s*[=:]\s*\[[^\]]*[\"\']\*[\"\']', plus)
        contextual_wildcard = re.search(r'(?i)iam|policy|permissions', block) and re.search(r'[\"\'](?:\*|(?!arn:)[a-z0-9-]+:[^\"\']*\*[^\"\']*)[\"\']', plus)
        if wildcard_action or wildcard_resource or contextual_wildcard:
            emit("high", "Wildcard IAM permission or unrestricted resource was introduced.",
                 "Scope actions and resources to the required service and resource ARN.")
        encryption = r"(?i)(?:storage_encrypted|encrypt|encrypted|sse_algorithm|server_side_encryption_configuration|kms_key_id)\s*[=:]"
        if re.search(encryption, minus) and not re.search(encryption, plus):
            emit("high", "Encryption configuration was removed; effective module defaults need review.",
                 "Retain explicit encryption or prove the replacement preserves it.")
        if re.search(r"(?i)(?:storage_encrypted|encrypt|encrypted)\s*[=:]\s*false", plus):
            emit("high", "Encryption was explicitly disabled.", "Keep encryption enabled.")
        if re.search(r"(?i)(?:publicly_accessible|endpoint_public_access)\s*=\s*true", plus) or re.search(r"(?i)(?:block_public_acls|block_public_policy|ignore_public_acls|restrict_public_buckets)\s*=\s*false", plus):
            emit("high", "Public access was enabled or a public-access block was disabled.",
                 "Keep the resource private and retain public-access protection.")
        if re.search(r"(?i)(network_acl|firewall|security.group|ingress|egress|cidr|from_port|to_port|ip_protocol)", path + plus + minus):
            emit("medium", "Network access controls or network ranges changed.",
                 "Review direction, sources, destinations, ports, and the architecture boundary.")
        if len(findings) == initial:
            if all(re.fullmatch(r'\s*(?:name|description)\s*=\s*"[^"$]*"\s*', line)
                   for line in (plus + "\n" + minus).splitlines() if line.strip()):
                emit("low", "Only literal name/description fields changed.", "Confirm the intended naming change in the plan.")
            else:
                emit("medium", "Textual rules cannot establish whether this configuration change is safe.",
                     "Review the module inputs and Terraform plan; resolve expressions manually.")
    return {"findings": findings, "summary": {level: sum(f["risk_level"] == level for f in findings)
            for level in ("low", "medium", "high")}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--diff", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        report = analyse(args.diff.read_text())
        code = 1 if report["summary"]["high"] else 0
    except (OSError, ValueError) as error:
        report = {"error": str(error), "findings": []}
        code = 2
    result = json.dumps(report, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(result)
    else:
        sys.stdout.write(result)
    return code


if __name__ == "__main__":
    sys.exit(main())
