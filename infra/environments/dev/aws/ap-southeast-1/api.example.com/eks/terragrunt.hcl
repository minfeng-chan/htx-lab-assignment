include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "tfr:///terraform-aws-modules/eks/aws?version=21.26.0"
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
}

dependency "vpc" {
  config_path = "../vpc"
}

dependency "endpoints" {
  config_path = "../endpoints"
}

inputs = {
  name                    = local.env.name_prefix
  kubernetes_version      = "1.36"
  vpc_id                  = dependency.vpc.outputs.vpc_id
  subnet_ids              = dependency.vpc.outputs.private_subnets
  endpoint_private_access = true
  endpoint_public_access  = false
  authentication_mode     = "API"
  enable_irsa             = true

  access_entries = {
    admin = {
      principal_arn = local.env.eks_admin_arn
      policy_associations = {
        cluster_admin = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }

  addons = {
    vpc-cni                = {}
    kube-proxy             = {}
    coredns                = {}
    eks-pod-identity-agent = {}
  }

  eks_managed_node_groups = {
    private = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = local.env.eks_node_instance_types
      min_size       = local.env.eks_node_min_size
      desired_size   = local.env.eks_node_desired_size
      max_size       = local.env.eks_node_max_size
      disk_size      = local.env.eks_node_disk_size
    }
  }

  cloudwatch_log_group_retention_in_days = local.env.eks_log_retention_days
  tags                                   = local.env.tags
}
