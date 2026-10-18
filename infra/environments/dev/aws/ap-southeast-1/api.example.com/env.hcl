# Mock defaults support local configuration review. Override HTX_* variables before deployment.
locals {
  environment = "dev"

  name_prefix      = "htx-dev"
  vpc_cidr         = "10.0.0.0/16"
  private_subnets  = ["10.0.0.0/24", "10.0.3.0/24"]
  database_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  onprem_cidr      = "172.16.0.0/16"
  adapter_cidr     = get_env("HTX_DEV_ADAPTER_CIDR", "172.16.10.10/32")
  eks_admin_arn    = get_env("HTX_DEV_EKS_ADMIN_PRINCIPAL_ARN", "arn:aws:iam::111122223333:role/MockEksAdminRole")

  dx_connection_id      = get_env("HTX_DEV_DX_CONNECTION_ID", "dxcon-mockdev0")
  dx_customer_peer_cidr = get_env("HTX_DEV_DX_CUSTOMER_PEER_CIDR", "169.254.100.1/30")
  dx_amazon_peer_cidr   = get_env("HTX_DEV_DX_AMAZON_PEER_CIDR", "169.254.100.2/30")
  dx_bgp_auth_key       = get_env("HTX_DEV_DX_BGP_AUTH_KEY", "MOCK-ONLY-NOT-A-REAL-BGP-KEY")
  dx_vlan               = 101
  dx_customer_asn       = 65000
  aws_side_asn          = "64512"

  eks_node_instance_types = ["m6i.large"]
  eks_node_min_size       = 2
  eks_node_desired_size   = 2
  eks_node_max_size       = 4
  eks_node_disk_size      = 50
  eks_log_retention_days  = 30

  csv_processor_db_username = "csv_processor"

  rds_instance_class        = "db.t4g.micro"
  rds_allocated_storage     = 20
  rds_max_allocated_storage = 100
  rds_multi_az              = false
  rds_backup_retention_days = 7

  tags = { Environment = "dev", Project = "htx" }
}
