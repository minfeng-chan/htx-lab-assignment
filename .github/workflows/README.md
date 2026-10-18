# CI/CD Pipeline

## How it works

- Uses GitHub Actions and Terragrunt for changed dev infrastructure units.
- **PR:** Validate/lint + risk check -> plan -> approve -> apply.
- **Manual on main:** Risk check -> plan -> approve -> apply; skip validate/lint.
- Review `units.json` and each unit's `plan.txt` in the artifact before approving. Apply uses those saved plans in dependency order.
- PR deployments happen before merge. Fork PRs run validation and risk checks only; they receive no AWS credentials.
- No push trigger. Risk checks use the same Git baseline as unit selection; high findings or check errors stop plan/apply. Download the JSON risk report from the workflow artifacts.

## Files

- [infra.yml](infra.yml): workflow jobs and approval gate.
- [select-units.py](../scripts/select-units.py): changed dev units and downstream selection.
- [run-plans.py](../scripts/run-plans.py): per-unit saved plans and ordered apply.
- [Risk detector](../../drift-detector/README.md): rule-based checks before plan.

## Git change selection

- PR: compare the PR base commit with the checked-out revision.
- Manual: compare main with `base_ref` (default `HEAD^`); choose an earlier commit to cover multiple commits.
- Select changed Terraform/Terragrunt units and their downstream dependents.
- Changes to shared `env.hcl`, `region.hcl`, `account.hcl`, or `root.hcl` select affected dev units. Local module changes conservatively select all dev units.
- Documentation-only changes do not deploy. Prod changes are outside this dev workflow.
- Removed/moved units stop the pipeline for explicit state migration/destroy handling.
- Dependencies must already have usable state outputs. Upstream replacements may require applying upstream first, then generating new downstream plans; a batch of saved plans is not one atomic Terraform plan.

## Why this approach

- Follows GitOps principles: Git holds the desired infrastructure configuration.
- PRs provide review and change history; approval controls deployment.
- This pipeline does not continuously reconcile AWS with Git.

## GitHub OIDC

- OIDC provides temporary AWS credentials; no static access keys.
- Authentication: `GitHub OIDC -> GitHubActionsRole -> TerraformDeploymentRole`.

## AWS setup

1. Add the IAM OIDC provider `https://token.actions.githubusercontent.com`, audience `sts.amazonaws.com`.
2. Create `GitHubActionsRole` with OIDC trust restricted to these subjects:

   ```text
   repo:minfeng-chan/htx-lab-assignment:environment:dev-plan
   repo:minfeng-chan/htx-lab-assignment:environment:dev-apply
   ```

3. Allow that role to assume only `TerraformDeploymentRole`; configure matching trust on the deployment role.
4. Give the deployment role permissions for the selected dev resources (VPC, endpoints, EKS, RDS, S3, IAM, and Direct Connect as applicable), plus state and lockfiles. Scope permissions to the selected resource types and dev resources; include required IAM role/policy management and scoped PassRole where needed.
5. Create a private, encrypted, versioned state bucket in `ap-southeast-1`. S3 native locking is used.

## GitHub setup

Create `dev-plan` and `dev-apply` environments with matching target settings:

| Variable | Value |
| --- | --- |
| `AWS_ACCOUNT_ID` | Target account ID |
| `AWS_OIDC_ROLE_ARN` | GitHubActionsRole ARN |
| `TF_DEPLOY_ROLE_NAME` | TerraformDeploymentRole |
| `TF_STATE_BUCKET` | State bucket name |

- Configure required reviewers and prevent self-review on `dev-apply`; disable approval bypass.
- Allow the intended PR refs and manual main runs in environment deployment rules.
- Use trusted PR contributors: plan also receives the deployment role's permissions.
- Saved plans expire after three days. Retry the whole workflow for a fresh plan.
- AWS/GitHub setup is required before live deployment; no live deployment has been performed.

## Multiple environments (extension)

- Only dev is wired today. For staging/prod, use small per-environment pipelines calling one reusable workflow; the reusable workflow is not implemented yet.
- Give each environment its own approvers, fixed Terragrunt path, and state settings.
- Isolate environments through separate AWS roles/accounts, exact OIDC trust, and scoped permissions.
- Dev roles must not access production resources or state.
