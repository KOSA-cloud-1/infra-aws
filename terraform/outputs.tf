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

output "private_subnet_ids" {
  description = "Private Subnet ID 목록"
  value = {
    for k, subnet in data.aws_subnet.private :
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

output "security_group_ids" {
  description = "Security Group ID 목록"
  value = {
    nlb     = aws_security_group.nlb.id
    haproxy = aws_security_group.haproxy.id
  }
}
