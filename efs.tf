# ------- EFS (optional) -------

resource "aws_security_group" "efs" {
  count = var.create_efs ? 1 : 0

  name        = "${var.prefix}-ccf-awc-efs-sg"
  description = "EFS NFS access [${var.prefix}]"
  vpc_id      = aws_vpc.csk.id

  tags = {
    Name = "${var.prefix}-ccf-awc-efs-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "efs_vpc" {
  count = var.create_efs ? 1 : 0

  security_group_id = aws_security_group.efs[0].id
  description       = "Allow NFS from VPC CIDR"
  ip_protocol       = "tcp"
  from_port         = 2049
  to_port           = 2049
  cidr_ipv4         = var.vpc_cidr
}

resource "aws_vpc_security_group_ingress_rule" "efs_10" {
  count = var.create_efs ? 1 : 0

  security_group_id = aws_security_group.efs[0].id
  description       = "Allow NFS from 10.0.0.0/8"
  ip_protocol       = "tcp"
  from_port         = 2049
  to_port           = 2049
  cidr_ipv4         = "10.0.0.0/8"
}

resource "aws_vpc_security_group_egress_rule" "efs" {
  count = var.create_efs ? 1 : 0

  security_group_id = aws_security_group.efs[0].id
  description       = "Allow all outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_efs_file_system" "ccf_awc" {
  count = var.create_efs ? 1 : 0

  creation_token = local.efs_name
  encrypted      = true

  tags = {
    Name = local.efs_name
  }
}

resource "aws_efs_mount_target" "ccf_awc" {
  for_each = var.create_efs ? aws_subnet.csk_private : {}

  file_system_id  = aws_efs_file_system.ccf_awc[0].id
  subnet_id       = each.value.id
  security_groups = [aws_security_group.efs[0].id]
}