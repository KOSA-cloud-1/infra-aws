moved {
  from = aws_eip.vpn[0]
  to   = aws_eip.vpn_service[0]
}

moved {
  from = aws_instance.vpn[0]
  to   = aws_instance.vpn["vpn-a"]
}

moved {
  from = aws_eip_association.vpn[0]
  to   = aws_eip_association.vpn_service[0]
}
