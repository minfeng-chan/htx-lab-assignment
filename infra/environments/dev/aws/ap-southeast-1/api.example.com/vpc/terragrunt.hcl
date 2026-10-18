include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "tfr:///terraform-aws-modules/vpc/aws?version=6.7.3"
}

locals {
  env    = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  region = read_terragrunt_config(find_in_parent_folders("region.hcl")).locals
}

inputs = {
  name                               = local.env.name_prefix
  cidr                               = local.env.vpc_cidr
  azs                                = ["${local.region.aws_region}a", "${local.region.aws_region}b"]
  private_subnets                    = local.env.private_subnets
  database_subnets                   = local.env.database_subnets
  create_database_subnet_group       = false
  create_database_subnet_route_table = true
  enable_dns_support                 = true
  enable_dns_hostnames               = true
  enable_nat_gateway                 = false
  create_igw                         = false
  enable_vpn_gateway                 = true
  propagate_private_route_tables_vgw = true
  amazon_side_asn                    = local.env.aws_side_asn
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
  tags = local.env.tags
}
