locals {
  name_prefix = substr("${var.project_name}-${var.environment}", 0, 20)

  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

data "aws_vpc" "this" {
  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}

data "aws_subnet" "public" {
  for_each = var.public_subnets

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.this.id]
  }

  filter {
    name   = "tag:Name"
    values = [each.value.name]
  }
}

data "aws_subnet" "private" {
  for_each = var.private_subnets

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.this.id]
  }

  filter {
    name   = "tag:Name"
    values = [each.value.name]
  }
}

# =========================================================
# Shared SSH Key Pair
# =========================================================

resource "aws_key_pair" "haproxy" {
  count = var.ssh_public_key == null ? 0 : 1

  key_name   = "${local.name_prefix}-haproxy"
  public_key = var.ssh_public_key

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-haproxy-key"
  })
}

# =========================================================
# Workload Modules
# =========================================================

module "haproxy" {
  source = "./haproxy"

  ami_id                      = var.ami_id
  associate_public_ip_address = var.associate_public_ip_address
  client_allowed_cidrs        = var.client_allowed_cidrs
  environment                 = var.environment
  haproxy_backends            = var.haproxy_backends
  haproxy_balance_algorithm   = var.haproxy_balance_algorithm
  haproxy_instances           = var.haproxy_instances
  haproxy_maxconn             = var.haproxy_maxconn
  haproxy_security_group_name = var.haproxy_security_group_name
  nlb_tls_certificate_arn     = var.nlb_tls_certificate_arn
  nlb_tls_ssl_policy          = var.nlb_tls_ssl_policy
  nlb_security_group_name     = var.nlb_security_group_name
  project_name                = var.project_name
  public_subnets              = var.public_subnets
  ssh_allowed_cidrs           = var.ssh_allowed_cidrs
  ssh_key_name                = var.ssh_public_key == null ? null : aws_key_pair.haproxy[0].key_name
  tags                        = var.tags
  vpc_name                    = var.vpc_name
}

module "vpn" {
  source = "./vpn"

  ami_id              = var.ami_id
  enable_vpn_failover = var.enable_vpn_failover
  enable_vpn_server   = var.enable_vpn_server
  environment         = var.environment
  project_name        = var.project_name
  public_subnets      = var.public_subnets
  ssh_allowed_cidrs   = var.ssh_allowed_cidrs
  ssh_key_name        = var.ssh_public_key == null ? null : aws_key_pair.haproxy[0].key_name
  tags                = var.tags
  vpc_name            = var.vpc_name

  vpn_active_instance_key          = var.vpn_active_instance_key
  vpn_auto                         = var.vpn_auto
  vpn_aws_cidrs                    = var.vpn_aws_cidrs
  vpn_esp_proposal                 = var.vpn_esp_proposal
  vpn_failover_schedule_expression = var.vpn_failover_schedule_expression
  vpn_icmp_allowed_cidrs           = var.vpn_icmp_allowed_cidrs
  vpn_ike_proposal                 = var.vpn_ike_proposal
  vpn_instance_type                = var.vpn_instance_type
  vpn_instances                    = var.vpn_instances
  vpn_onprem_cidrs                 = var.vpn_onprem_cidrs
  vpn_peer_allowed_cidrs           = var.vpn_peer_allowed_cidrs
  vpn_preshared_key                = var.vpn_preshared_key
  vpn_right_id                     = var.vpn_right_id
  vpn_root_volume_size             = var.vpn_root_volume_size
  vpn_route_table_names            = var.vpn_route_table_names
  vpn_security_group_name          = var.vpn_security_group_name
  vpn_subnet_key                   = var.vpn_subnet_key
}
