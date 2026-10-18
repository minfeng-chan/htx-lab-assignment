include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_parent_terragrunt_dir("root")}/../modules/direct-connect"
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
}

dependency "vpc" {
  config_path = "../vpc"
}

inputs = {
  name             = "${local.env.name_prefix}-private-vif"
  connection_id    = local.env.dx_connection_id
  vgw_id           = dependency.vpc.outputs.vgw_id
  vlan             = local.env.dx_vlan
  customer_asn     = local.env.dx_customer_asn
  customer_address = local.env.dx_customer_peer_cidr
  amazon_address   = local.env.dx_amazon_peer_cidr
  bgp_auth_key     = local.env.dx_bgp_auth_key
}
