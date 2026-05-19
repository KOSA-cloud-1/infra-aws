locals {
  name_prefix = substr("${var.project_name}-${var.environment}", 0, 20)

  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  })

  vpn_security_group_name = coalesce(var.vpn_security_group_name, "${var.project_name}-vpn-sg")

  vpn_aws_cidrs = length(var.vpn_aws_cidrs) > 0 ? var.vpn_aws_cidrs : [data.aws_vpc.this.cidr_block]

  legacy_vpn_instances = {
    vpn-a = {
      subnet_key       = var.vpn_subnet_key
      instance_type    = var.vpn_instance_type
      private_ip       = null
      root_volume_size = var.vpn_root_volume_size
      priority         = 100
    }
  }

  selected_vpn_instances = length(var.vpn_instances) > 0 ? var.vpn_instances : local.legacy_vpn_instances

  vpn_instance_settings = {
    for instance_key, instance in local.selected_vpn_instances :
    instance_key => {
      subnet_key       = instance.subnet_key
      instance_type    = coalesce(instance.instance_type, var.vpn_instance_type)
      private_ip       = instance.private_ip
      root_volume_size = coalesce(instance.root_volume_size, var.vpn_root_volume_size)
      priority         = coalesce(instance.priority, 100)
    }
  }

  vpn_active_instance_key = coalesce(var.vpn_active_instance_key, try(sort(keys(local.vpn_instance_settings))[0], null))
  vpn_enabled_instances   = var.enable_vpn_server ? local.vpn_instance_settings : {}
  vpn_failover_enabled    = var.enable_vpn_server && var.enable_vpn_failover && length(local.vpn_enabled_instances) > 1

  vpn_route_entry_maps = [
    for route_table_key, route_table_name in var.vpn_route_table_names : {
      for cidr in var.vpn_onprem_cidrs :
      "${route_table_key}-${replace(replace(cidr, ".", "-"), "/", "-")}" => {
        route_table_key = route_table_key
        cidr            = cidr
      }
    }
  ]

  vpn_route_entries = var.enable_vpn_server ? merge({}, local.vpn_route_entry_maps...) : {}
}

data "aws_ami" "ubuntu" {
  count = var.ami_id == null ? 1 : 0

  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
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

data "aws_route_table" "vpn" {
  for_each = var.enable_vpn_server ? var.vpn_route_table_names : {}

  vpc_id = data.aws_vpc.this.id

  filter {
    name   = "tag:Name"
    values = [each.value]
  }
}

data "archive_file" "vpn_failover" {
  count = local.vpn_failover_enabled ? 1 : 0

  type        = "zip"
  output_path = "${path.root}/.terraform/vpn-failover.zip"

  source {
    content  = file("${path.module}/templates/vpn-failover.py")
    filename = "vpn_failover.py"
  }
}

resource "aws_security_group" "vpn" {
  count = var.enable_vpn_server ? 1 : 0

  name        = local.vpn_security_group_name
  description = "Allow ER605 IPsec traffic to StrongSwan VPN servers"
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
    Name = local.vpn_security_group_name
    Role = "vpn"
  })
}

resource "aws_eip" "vpn_service" {
  count = var.enable_vpn_server ? 1 : 0

  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpn-service-eip"
    Role = "vpn"
  })
}

resource "aws_instance" "vpn" {
  for_each = local.vpn_enabled_instances

  ami                         = var.ami_id != null ? var.ami_id : data.aws_ami.ubuntu[0].id
  instance_type               = each.value.instance_type
  subnet_id                   = data.aws_subnet.public[each.value.subnet_key].id
  private_ip                  = each.value.private_ip
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.vpn[0].id]
  key_name                    = var.ssh_key_name
  source_dest_check           = false
  user_data_replace_on_change = true

  user_data = templatefile("${path.module}/templates/vpn-cloud-init.yml.tftpl", {
    hostname = each.key
    ipsec_config = templatefile("${path.module}/templates/ipsec.conf.tftpl", {
      aws_cidrs    = local.vpn_aws_cidrs
      esp_proposal = var.vpn_esp_proposal
      ike_proposal = var.vpn_ike_proposal
      left_id      = aws_eip.vpn_service[0].public_ip
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
    volume_size           = each.value.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = merge(local.common_tags, {
    Name     = "${local.name_prefix}-${each.key}"
    Role     = "vpn"
    Priority = tostring(each.value.priority)
  })

  lifecycle {
    precondition {
      condition     = contains(keys(var.public_subnets), each.value.subnet_key)
      error_message = "vpn_instances의 subnet_key는 public_subnets에 정의된 key여야 합니다."
    }

    precondition {
      condition     = contains(keys(local.vpn_instance_settings), local.vpn_active_instance_key)
      error_message = "vpn_active_instance_key는 vpn_instances에 정의된 key여야 합니다."
    }

    precondition {
      condition     = var.vpn_preshared_key != null && var.vpn_preshared_key != "CHANGE_ME_STRONG_PSK"
      error_message = "enable_vpn_server=true로 사용하려면 vpn_preshared_key를 실제 PSK 값으로 변경해야 합니다."
    }
  }
}

resource "aws_eip_association" "vpn_service" {
  count = var.enable_vpn_server ? 1 : 0

  allocation_id        = aws_eip.vpn_service[0].id
  network_interface_id = aws_instance.vpn[local.vpn_active_instance_key].primary_network_interface_id
  allow_reassociation  = true
}

resource "aws_route" "vpn_onprem" {
  for_each = local.vpn_route_entries

  route_table_id         = data.aws_route_table.vpn[each.value.route_table_key].id
  destination_cidr_block = each.value.cidr
  network_interface_id   = aws_instance.vpn[local.vpn_active_instance_key].primary_network_interface_id
}

resource "aws_iam_role" "vpn_failover" {
  count = local.vpn_failover_enabled ? 1 : 0

  name = "${local.name_prefix}-vpn-failover-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpn-failover-role"
    Role = "vpn-failover"
  })
}

resource "aws_iam_role_policy_attachment" "vpn_failover_basic" {
  count = local.vpn_failover_enabled ? 1 : 0

  role       = aws_iam_role.vpn_failover[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "vpn_failover" {
  count = local.vpn_failover_enabled ? 1 : 0

  name = "${local.name_prefix}-vpn-failover-policy"
  role = aws_iam_role.vpn_failover[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:AssociateAddress",
          "ec2:CreateRoute",
          "ec2:DescribeAddresses",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeInstances",
          "ec2:DescribeRouteTables",
          "ec2:ReplaceRoute"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_function" "vpn_failover" {
  count = local.vpn_failover_enabled ? 1 : 0

  function_name    = "${local.name_prefix}-vpn-failover"
  description      = "Moves VPN service EIP and on-prem routes to the healthiest StrongSwan EC2"
  role             = aws_iam_role.vpn_failover[0].arn
  handler          = "vpn_failover.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.vpn_failover[0].output_path
  source_code_hash = data.archive_file.vpn_failover[0].output_base64sha256
  timeout          = 30

  environment {
    variables = {
      DESTINATION_CIDRS_JSON = jsonencode(var.vpn_onprem_cidrs)
      EIP_ALLOCATION_ID      = aws_eip.vpn_service[0].id
      INSTANCE_CONFIG_JSON = jsonencode({
        for instance_key, instance in aws_instance.vpn :
        instance_key => {
          instance_id          = instance.id
          network_interface_id = instance.primary_network_interface_id
          priority             = local.vpn_instance_settings[instance_key].priority
        }
      })
      ROUTE_TABLE_IDS_JSON = jsonencode([for route_table in data.aws_route_table.vpn : route_table.id])
    }
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpn-failover"
    Role = "vpn-failover"
  })

  depends_on = [
    aws_iam_role_policy.vpn_failover,
    aws_iam_role_policy_attachment.vpn_failover_basic
  ]
}

resource "aws_cloudwatch_event_rule" "vpn_failover" {
  count = local.vpn_failover_enabled ? 1 : 0

  name                = "${local.name_prefix}-vpn-failover"
  description         = "Periodic StrongSwan VPN failover check"
  schedule_expression = var.vpn_failover_schedule_expression

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpn-failover"
    Role = "vpn-failover"
  })
}

resource "aws_cloudwatch_event_target" "vpn_failover" {
  count = local.vpn_failover_enabled ? 1 : 0

  rule      = aws_cloudwatch_event_rule.vpn_failover[0].name
  target_id = "vpn-failover"
  arn       = aws_lambda_function.vpn_failover[0].arn
}

resource "aws_lambda_permission" "vpn_failover" {
  count = local.vpn_failover_enabled ? 1 : 0

  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.vpn_failover[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.vpn_failover[0].arn
}
