include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "tfr:///terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts?version=6.8.2"
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
}

dependency "eks" {
  config_path = "../../eks"
}

dependency "batch_bucket" {
  config_path = "../../s3/batch-bucket"
}

inputs = {
  name = "${local.env.name_prefix}-batch-uploader"
  oidc_providers = {
    eks = {
      provider_arn               = dependency.eks.outputs.oidc_provider_arn
      namespace_service_accounts = ["htx:batch-upload-api"]
    }
  }
  policy_name = "${local.env.name_prefix}-batch-upload"
  permissions = {
    PutCsv = {
      actions   = ["s3:PutObject"]
      resources = ["${dependency.batch_bucket.outputs.s3_bucket_arn}/incoming/*"]
    }
  }
  tags = local.env.tags
}
