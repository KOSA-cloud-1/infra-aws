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
  value       = module.haproxy.nlb_dns_name
}

output "nlb_arn" {
  description = "AWS NLB ARN"
  value       = module.haproxy.nlb_arn
}

output "haproxy_instance_ids" {
  description = "HAProxy EC2 Instance ID 목록"
  value       = module.haproxy.haproxy_instance_ids
}

output "haproxy_private_ips" {
  description = "HAProxy EC2 Private IP 목록"
  value       = module.haproxy.haproxy_private_ips
}

output "haproxy_public_ips" {
  description = "HAProxy EC2 Public IP 목록"
  value       = module.haproxy.haproxy_public_ips
}

output "security_group_ids" {
  description = "Security Group ID 목록"
  value = {
    nlb     = module.haproxy.nlb_security_group_id
    haproxy = module.haproxy.haproxy_security_group_id
    vpn     = module.vpn.vpn_security_group_id
  }
}

output "vpn_server_instance_id" {
  description = "VPN Server EC2 Instance ID"
  value       = module.vpn.vpn_server_instance_id
}

output "vpn_server_public_ip" {
  description = "ER605 Remote Gateway로 사용할 VPN Server Elastic IP"
  value       = module.vpn.vpn_server_public_ip
}

output "vpn_server_private_ip" {
  description = "VPN Server EC2 Private IP"
  value       = module.vpn.vpn_server_private_ip
}
