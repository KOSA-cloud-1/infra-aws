locals {
  name_prefix = substr("${var.project_name}-${var.environment}", 0, 20)

  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  })

  haproxy_security_group_name = coalesce(var.haproxy_security_group_name, "${var.project_name}-sg-haproxy")
  nlb_security_group_name     = coalesce(var.nlb_security_group_name, "${local.name_prefix}-nlb-sg")

  listener_configs = {
    http = {
      port       = 80
      protocol   = "TCP"
      target_key = "http"
    }
    https = {
      port       = 443
      protocol   = "TLS"
      target_key = "https"
    }
  }

  target_group_configs = {
    http = {
      port     = 80
      protocol = "TCP"
    }
    https = {
      port     = 8080
      protocol = "TCP"
    }
  }

  target_attachments = {
    for pair in setproduct(keys(local.target_group_configs), keys(var.haproxy_instances)) :
    "${pair[0]}-${pair[1]}" => {
      target_group = pair[0]
      instance     = pair[1]
    }
  }
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

resource "aws_security_group" "nlb" {
  name        = local.nlb_security_group_name
  description = "Allow public service traffic to AWS NLB"
  vpc_id      = data.aws_vpc.this.id

  ingress {
    description = "HTTP from clients"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.client_allowed_cidrs
  }

  ingress {
    description = "HTTPS from clients"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.client_allowed_cidrs
  }

  egress {
    description = "Outbound to HAProxy targets"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = local.nlb_security_group_name
  })
}

resource "aws_security_group" "haproxy" {
  name        = local.haproxy_security_group_name
  description = "Allow NLB traffic to HAProxy EC2"
  vpc_id      = data.aws_vpc.this.id

  ingress {
    description     = "HTTP redirect traffic from NLB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.nlb.id]
  }

  ingress {
    description     = "HTTP app traffic after NLB TLS termination"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.nlb.id]
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
    description = "Outbound to on-prem or internet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = local.haproxy_security_group_name
  })
}

resource "aws_instance" "haproxy" {
  for_each = var.haproxy_instances

  ami                         = var.ami_id != null ? var.ami_id : data.aws_ami.ubuntu[0].id
  instance_type               = each.value.instance_type
  subnet_id                   = data.aws_subnet.public[each.value.subnet_key].id
  private_ip                  = each.value.private_ip
  associate_public_ip_address = var.associate_public_ip_address
  vpc_security_group_ids      = [aws_security_group.haproxy.id]
  key_name                    = var.ssh_key_name
  user_data_replace_on_change = true

  user_data = templatefile("${path.module}/templates/cloud-init.yml.tftpl", {
    haproxy_config = templatefile("${path.module}/templates/haproxy.cfg.tftpl", {
      backends          = var.haproxy_backends
      balance_algorithm = var.haproxy_balance_algorithm
      maxconn           = var.haproxy_maxconn
    })
    hostname = each.key
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
    Name = "${local.name_prefix}-${each.key}"
    Role = "haproxy"
  })

  lifecycle {
    precondition {
      condition     = contains(keys(var.public_subnets), each.value.subnet_key)
      error_message = "haproxy_instances의 subnet_key는 public_subnets에 정의된 key여야 합니다."
    }
  }
}

resource "aws_lb" "haproxy" {
  name                             = "${local.name_prefix}-haproxy-nlb"
  load_balancer_type               = "network"
  internal                         = false
  subnets                          = [for subnet in data.aws_subnet.public : subnet.id]
  security_groups                  = [aws_security_group.nlb.id]
  enable_cross_zone_load_balancing = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-haproxy-nlb"
  })
}

resource "aws_lb_target_group" "haproxy" {
  for_each = local.target_group_configs

  name        = "${local.name_prefix}-${each.key}-tg"
  port        = each.value.port
  protocol    = each.value.protocol
  target_type = "instance"
  vpc_id      = data.aws_vpc.this.id

  health_check {
    enabled             = true
    protocol            = "TCP"
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 30
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-${each.key}-tg"
  })
}

resource "aws_lb_listener" "haproxy" {
  for_each = local.listener_configs

  load_balancer_arn = aws_lb.haproxy.arn
  port              = each.value.port
  protocol          = each.value.protocol
  certificate_arn   = each.value.protocol == "TLS" ? var.nlb_tls_certificate_arn : null
  ssl_policy        = each.value.protocol == "TLS" ? var.nlb_tls_ssl_policy : null

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.haproxy[each.value.target_key].arn
  }
}

resource "aws_lb_target_group_attachment" "haproxy" {
  for_each = local.target_attachments

  target_group_arn = aws_lb_target_group.haproxy[each.value.target_group].arn
  target_id        = aws_instance.haproxy[each.value.instance].id
  port             = local.target_group_configs[each.value.target_group].port
}
