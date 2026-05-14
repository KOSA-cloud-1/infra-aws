locals {
  vpn_aws_cidrs = length(var.vpn_aws_cidrs) > 0 ? var.vpn_aws_cidrs : [data.aws_vpc.this.cidr_block]

  vpn_route_entries = var.enable_vpn_server ? merge([
    for route_table_key, route_table_name in var.vpn_route_table_names : {
      for cidr in var.vpn_onprem_cidrs :
      "${route_table_key}-${replace(replace(cidr, ".", "-"), "/", "-")}" => {
        route_table_key = route_table_key
        cidr            = cidr
      }
    }
  ]...) : {}
}

data "aws_route_table" "vpn" {
  for_each = var.enable_vpn_server ? var.vpn_route_table_names : {}

  vpc_id = data.aws_vpc.this.id

  filter {
    name   = "tag:Name"
    values = [each.value]
  }
}

resource "aws_security_group" "vpn" {
  count = var.enable_vpn_server ? 1 : 0

  name        = "${local.name_prefix}-vpn-sg"
  description = "Allow ER605 IPsec traffic to StrongSwan VPN server"
  vpc_id      = data.aws_vpc.this.id

  ingress {
    description = "IKE from ER605"
    from_port   = 500
    to_port     = 500
    protocol    = "udp"
    cidr_blocks = var.vpn_peer_allowed_cidrs
  }

  ingress {
    description = "NAT-T from ER605"
    from_port   = 4500
    to_port     = 4500
    protocol    = "udp"
    cidr_blocks = var.vpn_peer_allowed_cidrs
  }

  ingress {
    description = "ESP from ER605"
    from_port   = 0
    to_port     = 0
    protocol    = "50"
    cidr_blocks = var.vpn_peer_allowed_cidrs
  }

  ingress {
    description = "Forwarded traffic from VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [data.aws_vpc.this.cidr_block]
  }

  ingress {
    description = "Decrypted traffic from On-Prem"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.vpn_onprem_cidrs
  }

  dynamic "ingress" {
    for_each = length(var.ssh_allowed_cidrs) > 0 ? [1] : []

    content {
      description = "SSH from allowed CIDRs"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.ssh_allowed_cidrs
    }
  }

  egress {
    description = "Outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpn-sg"
    Role = "vpn"
  })
}

resource "aws_eip" "vpn" {
  count = var.enable_vpn_server ? 1 : 0

  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpn-eip"
    Role = "vpn"
  })
}

resource "aws_instance" "vpn" {
  count = var.enable_vpn_server ? 1 : 0

  ami                         = var.ami_id != null ? var.ami_id : data.aws_ami.ubuntu[0].id
  instance_type               = var.vpn_instance_type
  subnet_id                   = data.aws_subnet.public[var.vpn_subnet_key].id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.vpn[0].id]
  key_name                    = var.ssh_public_key == null ? null : aws_key_pair.haproxy[0].key_name
  source_dest_check           = false
  user_data_replace_on_change = true

  user_data = templatefile("${path.module}/templates/vpn-cloud-init.yml.tftpl", {
    ipsec_config = templatefile("${path.module}/templates/ipsec.conf.tftpl", {
      aws_cidrs    = local.vpn_aws_cidrs
      esp_proposal = var.vpn_esp_proposal
      ike_proposal = var.vpn_ike_proposal
      left_id      = aws_eip.vpn[0].public_ip
      onprem_cidrs = var.vpn_onprem_cidrs
      right_id     = var.vpn_right_id
    })
    preshared_key = var.vpn_preshared_key
  })

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_size           = var.vpn_root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpn-server"
    Role = "vpn"
  })

  lifecycle {
    precondition {
      condition     = contains(keys(var.public_subnets), var.vpn_subnet_key)
      error_message = "vpn_subnet_key는 public_subnets에 정의된 key여야 합니다."
    }

    precondition {
      condition     = var.vpn_preshared_key != null && var.vpn_preshared_key != "CHANGE_ME_STRONG_PSK"
      error_message = "enable_vpn_server=true로 사용하려면 vpn_preshared_key를 실제 PSK 값으로 변경해야 합니다."
    }
  }
}

resource "aws_eip_association" "vpn" {
  count = var.enable_vpn_server ? 1 : 0

  allocation_id = aws_eip.vpn[0].id
  instance_id   = aws_instance.vpn[0].id
}

resource "aws_route" "vpn_onprem" {
  for_each = local.vpn_route_entries

  route_table_id         = data.aws_route_table.vpn[each.value.route_table_key].id
  destination_cidr_block = each.value.cidr
  network_interface_id   = aws_instance.vpn[0].primary_network_interface_id
}
