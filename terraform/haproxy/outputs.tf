output "vpc_id" {
  description = "사용 중인 기존 VPC ID"
  value       = data.aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "Public Subnet ID 목록"
  value = {
    for k, subnet in data.aws_subnet.public :
    k => subnet.id
  }
}

output "nlb_dns_name" {
  description = "AWS NLB DNS 이름"
  value       = aws_lb.haproxy.dns_name
}

output "nlb_arn" {
  description = "AWS NLB ARN"
  value       = aws_lb.haproxy.arn
}

output "haproxy_instance_ids" {
  description = "HAProxy EC2 Instance ID 목록"
  value = {
    for k, instance in aws_instance.haproxy :
    k => instance.id
  }
}

output "haproxy_private_ips" {
  description = "HAProxy EC2 Private IP 목록"
  value = {
    for k, instance in aws_instance.haproxy :
    k => instance.private_ip
  }
}

output "haproxy_public_ips" {
  description = "HAProxy EC2 Public IP 목록"
  value = {
    for k, instance in aws_instance.haproxy :
    k => instance.public_ip
  }
}

output "haproxy_backends" {
  description = "AWS HAProxy가 전달하는 backend 목록"
  value = {
    for k, backend in var.haproxy_backends :
    k => {
      address   = backend.address
      http_port = backend.http_port
      check     = backend.check
    }
  }
}

output "nlb_security_group_id" {
  description = "NLB Security Group ID"
  value       = aws_security_group.nlb.id
}

output "haproxy_security_group_id" {
  description = "HAProxy Security Group ID"
  value       = aws_security_group.haproxy.id
}

output "nlb_record_fqdns" {
  description = "생성된 Route53 NLB alias 레코드 FQDN 목록"
  value       = [for r in aws_route53_record.nlb : r.fqdn]
}
