include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "tfr:///terraform-aws-modules/security-group/aws?version=6.0.0"
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
}

dependency "vpc" {
  config_path = "../../vpc"
}

dependency "eks" {
  config_path = "../../eks"
}

inputs = {
  name        = "${local.env.name_prefix}-postgres"
  description = "PostgreSQL from private EKS nodes only"
  vpc_id      = dependency.vpc.outputs.vpc_id
  ingress_rules = {
    postgres = {
      from_port                    = 5432
      to_port                      = 5432
      ip_protocol                  = "tcp"
      referenced_security_group_id = dependency.eks.outputs.node_security_group_id
    }
  }
  egress_rules = {}
  tags         = local.env.tags
}
