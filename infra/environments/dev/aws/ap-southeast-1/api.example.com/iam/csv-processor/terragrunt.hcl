include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "tfr:///terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts?version=6.8.2"
}

locals {
  env     = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  account = read_terragrunt_config(find_in_parent_folders("account.hcl")).locals
  region  = read_terragrunt_config(find_in_parent_folders("region.hcl")).locals
}

dependency "eks" {
  config_path = "../../eks"
}

dependency "batch_bucket" {
  config_path = "../../s3/batch-bucket"
}

dependency "rds" {
  config_path = "../../rds"
}

inputs = {
  name = "${local.env.name_prefix}-csv-processor"
  oidc_providers = {
    eks = {
      provider_arn               = dependency.eks.outputs.oidc_provider_arn
      namespace_service_accounts = ["htx:csv-processor"]
    }
  }
  policy_name = "${local.env.name_prefix}-csv-process"
  permissions = {
    ConnectToIngestionDatabase = {
      actions = ["rds-db:connect"]
      resources = [
        "arn:aws:rds-db:${local.region.aws_region}:${local.account.aws_account_id}:dbuser:${dependency.rds.outputs.db_instance_resource_id}/${local.env.csv_processor_db_username}"
      ]
    }
    ReadAndRemoveCsv = {
      actions   = ["s3:GetObject", "s3:DeleteObject"]
      resources = ["${dependency.batch_bucket.outputs.s3_bucket_arn}/incoming/*"]
    }
  }
  tags = local.env.tags
}
