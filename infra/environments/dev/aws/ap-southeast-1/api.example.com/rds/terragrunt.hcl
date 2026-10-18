include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "tfr:///terraform-aws-modules/rds/aws?version=7.2.1"
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
}

dependency "vpc" {
  config_path = "../vpc"
}

dependency "rds_sg" {
  config_path = "../security-groups/rds"
}

inputs = {
  identifier                          = "${local.env.name_prefix}-postgres"
  engine                              = "postgres"
  engine_version                      = "17"
  family                              = "postgres17"
  instance_class                      = local.env.rds_instance_class
  allocated_storage                   = local.env.rds_allocated_storage
  max_allocated_storage               = local.env.rds_max_allocated_storage
  storage_type                        = "gp3"
  storage_encrypted                   = true
  db_name                             = "htx"
  username                            = "htxadmin"
  manage_master_user_password         = true
  iam_database_authentication_enabled = true
  create_db_subnet_group              = true
  subnet_ids                          = dependency.vpc.outputs.database_subnets
  vpc_security_group_ids              = [dependency.rds_sg.outputs.id]
  publicly_accessible                 = false
  multi_az                            = local.env.rds_multi_az
  backup_retention_period             = local.env.rds_backup_retention_days
  deletion_protection                 = true
  skip_final_snapshot                 = false
  create_db_option_group              = false
  parameters                          = [{ name = "rds.force_ssl", value = "1" }]
  tags                                = local.env.tags
}
