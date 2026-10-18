# Mock defaults support local configuration review. Override HTX_* variables before deployment.
# Account-wide settings. Keep credentials outside the repository.
locals {
  account_name     = "htx-dev"
  aws_account_id   = get_env("HTX_DEV_AWS_ACCOUNT_ID", "111122223333")
  deploy_role_name = get_env("HTX_DEV_DEPLOY_ROLE_NAME", "TerraformDeploymentRole")
  state_bucket     = get_env("HTX_DEV_STATE_BUCKET", "htx-mock-dev-111122223333-ap-southeast-1-tfstate")
}
