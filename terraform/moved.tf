moved {
  from = aws_security_group.nlb
  to   = module.haproxy.aws_security_group.nlb
}

moved {
  from = aws_security_group.haproxy
  to   = module.haproxy.aws_security_group.haproxy
}

moved {
  from = aws_instance.haproxy
  to   = module.haproxy.aws_instance.haproxy
}

moved {
  from = aws_lb.haproxy
  to   = module.haproxy.aws_lb.haproxy
}

moved {
  from = aws_lb_target_group.haproxy
  to   = module.haproxy.aws_lb_target_group.haproxy
}

moved {
  from = aws_lb_listener.haproxy
  to   = module.haproxy.aws_lb_listener.haproxy
}

moved {
  from = aws_lb_target_group_attachment.haproxy
  to   = module.haproxy.aws_lb_target_group_attachment.haproxy
}

moved {
  from = aws_security_group.vpn
  to   = module.vpn.aws_security_group.vpn
}

moved {
  from = aws_eip.vpn
  to   = module.vpn.aws_eip.vpn
}

moved {
  from = aws_instance.vpn
  to   = module.vpn.aws_instance.vpn
}

moved {
  from = aws_eip_association.vpn
  to   = module.vpn.aws_eip_association.vpn
}

moved {
  from = aws_route.vpn_onprem
  to   = module.vpn.aws_route.vpn_onprem
}
