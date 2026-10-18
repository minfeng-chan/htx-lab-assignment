# Mock defaults support local configuration review. Override HTX_* variables before deployment.
# Account-wide settings. Keep credentials outside the repository.
locals {
  account_name     = "htx-prod"
  aws_account_id   = get_env("HTX_PROD_AWS_ACCOUNT_ID", "444455556666")
  deploy_role_name = get_env("HTX_PROD_DEPLOY_ROLE_NAME", "TerraformDeploymentRole")
  state_bucket     = get_env("HTX_PROD_STATE_BUCKET", "htx-mock-prod-444455556666-ap-southeast-1-tfstate")
}
