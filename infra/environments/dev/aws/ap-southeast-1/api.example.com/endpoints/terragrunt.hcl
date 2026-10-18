include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "tfr:///terraform-aws-modules/vpc/aws//modules/vpc-endpoints?version=6.7.3"
}

dependency "vpc" {
  config_path = "../vpc"
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  services = toset([
    "ec2", "ecr.api", "ecr.dkr", "eks", "eks-auth", "elasticloadbalancing",
    "logs", "secretsmanager", "sts"
  ])
}

inputs = {
  vpc_id                = dependency.vpc.outputs.vpc_id
  subnet_ids            = dependency.vpc.outputs.private_subnets
  create_security_group = true
  security_group_name   = "${local.env.name_prefix}-endpoints"
  security_group_rules = {
    app_https = {
      description = "HTTPS from private EKS subnets"
      cidr_blocks = local.env.private_subnets
    }
  }
  endpoints = merge(
    {
      s3 = {
        service         = "s3"
        service_type    = "Gateway"
        route_table_ids = dependency.vpc.outputs.private_route_table_ids
      }
    },
    { for service in local.services : service => {
      service             = service
      private_dns_enabled = true
      }
    }
  )
  tags = local.env.tags
}
