variable "name" { type = string }
variable "connection_id" { type = string }
variable "vgw_id" { type = string }
variable "vlan" { type = number }
variable "customer_asn" { type = number }
variable "customer_address" { type = string }
variable "amazon_address" { type = string }
variable "bgp_auth_key" {
  type      = string
  sensitive = true
}

resource "aws_dx_private_virtual_interface" "this" {
  connection_id    = var.connection_id
  name             = var.name
  vlan             = var.vlan
  address_family   = "ipv4"
  bgp_asn          = var.customer_asn
  bgp_auth_key     = var.bgp_auth_key
  customer_address = var.customer_address
  amazon_address   = var.amazon_address
  vpn_gateway_id   = var.vgw_id
  tags             = { Name = var.name }
}

output "virtual_interface_id" { value = aws_dx_private_virtual_interface.this.id }
