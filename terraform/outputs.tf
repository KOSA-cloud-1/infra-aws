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

output "nlb_record_fqdns" {
  description = "생성된 Route53 NLB alias 레코드 FQDN 목록"
  value       = module.haproxy.nlb_record_fqdns
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

output "haproxy_backends" {
  description = "AWS HAProxy가 전달하는 backend 목록"
  value       = module.haproxy.haproxy_backends
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
  description = "Active VPN Server EC2 Instance ID"
  value       = module.vpn.vpn_server_instance_id
}

output "vpn_server_instance_ids" {
  description = "VPN Server EC2 Instance ID 목록"
  value       = module.vpn.vpn_server_instance_ids
}

output "vpn_active_instance_key" {
  description = "현재 Terraform 기준 Active VPN instance key"
  value       = module.vpn.vpn_active_instance_key
}

output "vpn_server_public_ip" {
  description = "ER605 Remote Gateway로 사용할 VPN Service Elastic IP"
  value       = module.vpn.vpn_server_public_ip
}

output "vpn_server_private_ip" {
  description = "Active VPN Server EC2 Private IP"
  value       = module.vpn.vpn_server_private_ip
}

output "vpn_server_private_ips" {
  description = "VPN Server EC2 Private IP 목록"
  value       = module.vpn.vpn_server_private_ips
}

output "vpn_failover_function_name" {
  description = "VPN failover Lambda 함수 이름"
  value       = module.vpn.vpn_failover_function_name
}

output "aws_entry_summary" {
  description = "AWS 외부 진입 구간 요약"
  value = {
    total_haproxy_instances = length(var.haproxy_instances)
    total_haproxy_backends  = length(var.haproxy_backends)
    total_vpn_instances     = length(module.vpn.vpn_server_instance_ids)
    vpn_enabled             = var.enable_vpn_server
    vpn_failover_enabled    = var.enable_vpn_server && var.enable_vpn_failover && length(module.vpn.vpn_server_instance_ids) > 1
    nlb_dns_name            = module.haproxy.nlb_dns_name
  }
}
