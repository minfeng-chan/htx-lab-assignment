locals {
  account  = read_terragrunt_config(find_in_parent_folders("account.hcl")).locals
  region   = read_terragrunt_config(find_in_parent_folders("region.hcl")).locals
  role_arn = "arn:aws:iam::${local.account.aws_account_id}:role/${local.account.deploy_role_name}"
}

remote_state {
  backend = "s3"
  generate = {
    path      = "backend.generated.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket              = local.account.state_bucket
    key                 = "htx/${path_relative_to_include()}/terraform.tfstate"
    region              = local.region.aws_region
    encrypt             = true
    use_lockfile        = true
    allowed_account_ids = [local.account.aws_account_id]
    assume_role = {
      role_arn = local.role_arn
    }
  }
}

generate "provider" {
  path      = "provider.generated.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_version = ">= 1.11.1"
}

provider "aws" {
  region              = "${local.region.aws_region}"
  allowed_account_ids = ["${local.account.aws_account_id}"]

  assume_role {
    role_arn = "${local.role_arn}"
  }
}
EOF
}
