# Infrastructure as Code

## Overview

- Private AWS infrastructure for the hybrid API and nightly CSV ingestion service.
- Includes VPC, EKS, PostgreSQL RDS, S3, private endpoints, security groups, and IAM roles.
- Uses pinned [terraform-aws-modules from GitHub](https://github.com/terraform-aws-modules), downloaded through the Terraform Registry.
- [Direct Connect](modules/direct-connect/main.tf) is a self-written module: creates a private VIF on an existing circuit and connects it to the VPC gateway.
- Dev resource units are implemented; prod contains account/region/environment templates only. No AWS resources have been applied.
- Local HCL checks and Terraform validation of the S3 and Direct Connect modules have passed; full infrastructure plan/apply remains unverified.

## Why Terragrunt

- **State management:** Separate state per environment, region, application, and resource; encrypted S3 backend with locking.
- **DRY:** Reuse modules and shared settings across dev, staging, and prod.
- **Dependencies:** Order resource deployments through dependency blocks.
- **Drift detection:** Run plans across units with `terragrunt run --all plan` (older syntax: `terragrunt run-all plan`). Review differences caused by manual changes or code updates.

## Layout

```text
environments/
  root.hcl                         # Shared provider and state configuration
  dev/aws/
    account.hcl                    # Account, deployment role, state bucket
    ap-southeast-1/
      region.hcl                   # AWS region
      api.example.com/
        env.hcl                    # Network and workload settings
        vpc/
        endpoints/
        eks/
        rds/
        direct-connect/
        security-groups/{nlb,rds}/
        s3/batch-bucket/
        iam/{batch-uploader,csv-processor,load-balancer-controller}/
  prod/aws/                        # Matching account/region/env template
```

- Add staging or prod units using the same structure with separate accounts, roles, and state.
- All `get_env` calls have mock defaults. Override `HTX_DEV_*` or `HTX_PROD_*` before deployment, including the dummy BGP key.

## AWS authentication

- Provider and state backend assume `arn:aws:iam::<account-id>:role/<deploy-role-name>`.
- Account ID, role name, and state bucket come from `account.hcl`.
- Initial credentials come from an AWS profile/SSO session or CI federation; no static keys in code.
- Deployment role, trust policy, and state bucket must already exist with provisioning and state/lockfile permissions.

## Security

- **Adapter -> NLB:** HTTPS 443 only from the configured adapter CIDR.
- **NLB outbound:** Port 443 to private application subnets.
- **NLB -> EKS:** EKS module manages cluster/node security groups. Explicit target-port and health-check ingress rules still need configuration.
- **EKS -> RDS:** PostgreSQL 5432 only from the EKS node security group; use NetworkPolicies for workload-level restrictions.
- **Uploader role:** S3 `PutObject` only under `incoming/`.
- **Processor role:** S3 `GetObject`/`DeleteObject` under `incoming/`; `rds-db:connect` only for this DB instance and `csv_processor` user.
- **Controller role:** Separate permissions for load balancer management.
- **IRSA:** Role trust is scoped to designated service accounts; workload manifests must use those accounts and role annotations.
- **Storage:** Private encrypted S3 and RDS; RDS enforces TLS. S3 leftovers expire after seven days.

## RDS role authentication

- IAM database authentication is enabled on RDS.
- After RDS and schema migrations, run [bootstrap-csv-processor.sql](environments/dev/aws/ap-southeast-1/api.example.com/rds/bootstrap-csv-processor.sql) as `htxadmin` against `htx`.
- Bootstrap grants `rds_iam`, schema usage, SELECT/INSERT/UPDATE, and sequence usage in `ingestion`; future grants cover objects created by `htxadmin`.
- Keep `csv_processor_db_username`, bootstrap user, and runtime username aligned.
- Job uses `htx:csv-processor` with its IRSA role and generates an IAM token for each new connection.
- Connect using the actual RDS endpoint and `sslmode=verify-full` with the RDS CA bundle. Tokens expire after 15 minutes; never log them.
- No master-secret access or RDS administrative permissions for the processor. Live authentication is not yet tested.

## CI/CD and risk checks

- [CI/CD README](../.github/workflows/README.md): PR validation/lint and risk checks -> plans -> approval -> apply. Manual runs skip validation/lint but retain risk checks.
- Git changes select dev units and downstream dependents; shared configuration changes select affected units.
- [Detector README](../drift-detector/README.md): local pre-commit checks and CI checks block high-risk changes before plan.
- Directory moves change backend state keys; migrate existing state before applying a new layout.

## Deployment

- Install Terraform >= 1.11.1, Terragrunt, and AWS CLI; review module/provider and regional EKS version compatibility.
- Supply real account, bucket, admin ARN, adapter CIDR, and Direct Connect settings.
- Runner needs AWS API/module access; workload deployment needs private EKS access and reachable container images.
- Apply: `vpc` -> `endpoints` -> `eks` -> `security-groups/rds` -> `rds`.
- Apply S3 before its IAM roles; processor IAM also requires RDS. NLB SG requires VPC; Direct Connect requires an existing circuit.

```sh
cd infra/environments/dev/aws/ap-southeast-1/api.example.com/vpc
terragrunt init
terragrunt plan
# Review the plan before applying.
terragrunt apply
```
