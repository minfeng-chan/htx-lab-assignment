# Task 6 - Configuration Risk Detection

## How it works

- [detector.py](detector.py) checks Terraform/Terragrunt Git diffs with Python rules.
- The [pre-commit hook](../.githooks/pre-commit) checks staged changes; the [CI workflow](../.github/workflows/infra.yml) checks committed changes before plan.
- Python rules produce JSON findings: `change_description`, `risk_level`, `reasoning`, and `recommendation`.
- **High:** Public CIDRs, wildcard IAM permissions, encryption removal/disablement, or public-access enablement. Blocks the commit or CI plan.
- **Medium:** Network ACL/firewall/security-group changes or changes needing further review. Reports without blocking.
- **Low:** Literal name/description changes. Reports without blocking.
- Report: `reports/pre-commit-risk.json` (ignored by Git). Exit codes: `0` pass, `1` high risk, `2` check error.

## Setup

Run once after cloning; Python 3 is required. No packages or AWS credentials are needed.

```sh
git config --local core.hooksPath .githooks
```

Commit normally. The hook checks only staged changes, including the first commit. Each developer must install the hook locally. Local hooks can be bypassed; CI repeats the check before Terraform plan.

## CI integration

- The workflow runs a separate risk job for PRs (including forks) and manual runs, without AWS credentials. It also runs detector tests.
- Uses the same baseline as unit selection: PR base commit, or manual `base_ref` (default `HEAD^`).
- Checks the Git diff under `infra/` and uploads `risk.json`, including when high-risk findings fail the check.
- Plan requires the risk job to pass; apply requires plan to pass. High risk or detector errors stop deployment; low/medium findings remain available for review.
- This checks configuration changes, not live AWS drift. Manual runs should choose a baseline covering all intended changes.

## Test

```sh
python3 -m unittest discover -s drift-detector/tests -v
python3 drift-detector/detector.py --diff drift-detector/fixtures/sample.diff
```

The sample diff exits `1` because it opens all TCP ports to the Internet.

## Optional AI reviewer

- [ai-agent/prompt.md](ai-agent/prompt.md) defines an optional LLM review of IaC changes.
- The LLM would explain medium-risk changes and their impact; high-risk findings would also include precautions and safer alternatives.
- It supplements the Python rules and must never clear a rule-based high-risk block.
- Redact secrets before submission, validate its JSON response, and send uncertain/failed reviews to a human.
- Only the prompt is implemented. No LLM API call is connected to the hook or CI; both use Python rules only.

## Limits

- Text-based rules; no HCL evaluation, live AWS drift checking, or plan JSON parsing.
- Expressions and external module defaults still require human plan review.
- Public egress and encryption declaration removal are flagged conservatively.
- Scoped S3 resources such as `incoming/*` are allowed; unrestricted IAM resources/actions are flagged.
