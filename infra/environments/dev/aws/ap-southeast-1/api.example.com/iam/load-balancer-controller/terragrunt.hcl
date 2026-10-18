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

inputs = {
  name = "${local.env.name_prefix}-load-balancer-controller"
  oidc_providers = {
    eks = {
      provider_arn               = dependency.eks.outputs.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
  attach_load_balancer_controller_policy = true
  tags                                   = local.env.tags
}
