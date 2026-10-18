# Mock defaults support local configuration review. Override HTX_* variables before deployment.
# Production units are intentionally not present yet. Supply production network
# ranges before copying dev units into this region. Account details live in ../../account.hcl.
locals {
  environment = "prod"

  name_prefix      = "htx-prod"
  vpc_cidr         = get_env("HTX_PROD_VPC_CIDR", "10.1.0.0/16")
  private_subnets  = [get_env("HTX_PROD_APP_SUBNET_A_CIDR", "10.1.0.0/24"), get_env("HTX_PROD_APP_SUBNET_B_CIDR", "10.1.3.0/24")]
  database_subnets = [get_env("HTX_PROD_DB_SUBNET_A_CIDR", "10.1.1.0/24"), get_env("HTX_PROD_DB_SUBNET_B_CIDR", "10.1.2.0/24")]
  onprem_cidr      = get_env("HTX_PROD_ONPREM_CIDR", "172.16.0.0/16")
  adapter_cidr     = get_env("HTX_PROD_ADAPTER_CIDR", "172.16.20.10/32")
  eks_admin_arn    = get_env("HTX_PROD_EKS_ADMIN_PRINCIPAL_ARN", "arn:aws:iam::444455556666:role/MockEksAdminRole")

  dx_connection_id      = get_env("HTX_PROD_DX_CONNECTION_ID", "dxcon-mockprd0")
  dx_customer_peer_cidr = get_env("HTX_PROD_DX_CUSTOMER_PEER_CIDR", "169.254.101.1/30")
  dx_amazon_peer_cidr   = get_env("HTX_PROD_DX_AMAZON_PEER_CIDR", "169.254.101.2/30")
  dx_bgp_auth_key       = get_env("HTX_PROD_DX_BGP_AUTH_KEY", "MOCK-ONLY-NOT-A-REAL-BGP-KEY")
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

  tags = { Environment = "prod", Project = "htx" }
}
