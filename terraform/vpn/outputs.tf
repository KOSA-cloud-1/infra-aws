output "vpn_security_group_id" {
  description = "VPN Server Security Group ID"
  value       = try(aws_security_group.vpn[0].id, null)
}

output "vpn_active_instance_key" {
  description = "현재 Terraform 기준 Active VPN instance key"
  value       = var.enable_vpn_server ? local.vpn_active_instance_key : null
}

output "vpn_server_instance_id" {
  description = "Active VPN Server EC2 Instance ID"
  value       = try(aws_instance.vpn[local.vpn_active_instance_key].id, null)
}

output "vpn_server_instance_ids" {
  description = "VPN Server EC2 Instance ID 목록"
  value = {
    for k, instance in aws_instance.vpn :
    k => instance.id
  }
}

output "vpn_server_public_ip" {
  description = "ER605 Remote Gateway로 사용할 VPN Service Elastic IP"
  value       = try(aws_eip.vpn_service[0].public_ip, null)
}

output "vpn_server_private_ip" {
  description = "Active VPN Server EC2 Private IP"
  value       = try(aws_instance.vpn[local.vpn_active_instance_key].private_ip, null)
}

output "vpn_server_private_ips" {
  description = "VPN Server EC2 Private IP 목록"
  value = {
    for k, instance in aws_instance.vpn :
    k => instance.private_ip
  }
}

output "vpn_failover_function_name" {
  description = "VPN failover Lambda 함수 이름"
  value       = try(aws_lambda_function.vpn_failover[0].function_name, null)
}
