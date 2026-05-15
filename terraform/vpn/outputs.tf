output "vpn_security_group_id" {
  description = "VPN Server Security Group ID"
  value       = try(aws_security_group.vpn[0].id, null)
}

output "vpn_server_instance_id" {
  description = "VPN Server EC2 Instance ID"
  value       = try(aws_instance.vpn[0].id, null)
}

output "vpn_server_public_ip" {
  description = "ER605 Remote Gateway로 사용할 VPN Server Elastic IP"
  value       = try(aws_eip.vpn[0].public_ip, null)
}

output "vpn_server_private_ip" {
  description = "VPN Server EC2 Private IP"
  value       = try(aws_instance.vpn[0].private_ip, null)
}
