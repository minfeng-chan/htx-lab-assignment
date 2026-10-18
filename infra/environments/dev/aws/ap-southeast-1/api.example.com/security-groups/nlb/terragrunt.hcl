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

inputs = {
  name        = "${local.env.name_prefix}-nlb"
  description = "Internal NLB: HTTPS from the on-premises adapter"
  vpc_id      = dependency.vpc.outputs.vpc_id
  ingress_rules = {
    adapter_https = {
      from_port   = 443
      to_port     = 443
      ip_protocol = "tcp"
      cidr_ipv4   = local.env.adapter_cidr
    }
  }
  egress_rules = {
    app_az1 = {
      from_port   = 443
      to_port     = 443
      ip_protocol = "tcp"
      cidr_ipv4   = local.env.private_subnets[0]
    }
    app_az2 = {
      from_port   = 443
      to_port     = 443
      ip_protocol = "tcp"
      cidr_ipv4   = local.env.private_subnets[1]
    }
  }
  tags = local.env.tags
}
