include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "tfr:///terraform-aws-modules/s3-bucket/aws?version=5.15.4"
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
}

inputs = {
  bucket_prefix                         = "${local.env.name_prefix}-batch-"
  force_destroy                         = false
  attach_deny_insecure_transport_policy = true
  attach_require_latest_tls_policy      = true
  versioning                            = { enabled = false }
  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = { sse_algorithm = "AES256" }
    }
  }
  lifecycle_rule = [
    {
      id         = "expire-unprocessed-csv"
      enabled    = true
      filter     = { prefix = "" }
      expiration = { days = 7 }
    }
  ]
  tags = local.env.tags
}
