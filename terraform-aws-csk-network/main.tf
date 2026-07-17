# Copyright 2025 Cloudera, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

data "aws_availability_zones" "csk" {
  state = "available"
}

locals {
  vpc_name        = var.vpc_name != "" ? var.vpc_name : "${var.prefix}-csk-vpc"
  nat_name        = var.nat_gateway_name != "" ? var.nat_gateway_name : "${var.prefix}-csk-nat"
  rt_public_name  = var.public_route_table_name != "" ? var.public_route_table_name : "${var.prefix}-csk-public"
  rt_private_name = var.private_route_table_name != "" ? var.private_route_table_name : "${var.prefix}-csk-private"
  sg_intra_name   = var.security_group_intra_name != "" ? var.security_group_intra_name : "${var.prefix}-csk-intra"

  public_subnet_name = var.public_subnet_name != "" ? var.public_subnet_name : "${var.prefix}-csk-public"
  public_subnets = length(var.public_subnets) > 0 ? var.public_subnets : tolist([{
    name = "${local.public_subnet_name}-01"
    cidr = cidrsubnet(var.vpc_cidr, 8, 0)
    az   = data.aws_availability_zones.csk.names[0]
    tags = {}
  }])

  private_subnet_name = var.private_subnet_name != "" ? var.private_subnet_name : "${var.prefix}-csk-private"
  private_subnets = length(var.private_subnets) > 0 ? var.private_subnets : tolist([{
    name = "${local.private_subnet_name}-01"
    cidr = cidrsubnet(var.vpc_cidr, 8, 1)
    az   = data.aws_availability_zones.csk.names[0]
    tags = {}
  }])

  s3_bucket_full_name = var.s3_bucket_name != "" ? lower("${var.prefix}-${var.s3_bucket_name}") : ""
  iam_user_name       = "${var.prefix}-csk-ccf-awc-restricted"
  efs_name            = "${var.prefix}-ccf-awc-efs"
}

# ------- VPC -------

resource "aws_vpc" "csk" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = local.vpc_name }
}

# ------- AWS Public Network infrastructure -------
# Only created when create_public_subnet = true (i.e. no VPN/DirectConnect).
# Provides: Internet Gateway, public subnets, and NAT Gateways for private
# subnet outbound internet access. Bastion nodes can also be placed here.

resource "aws_internet_gateway" "csk" {
  count = var.create_public_subnet ? 1 : 0

  vpc_id = aws_vpc.csk.id

  tags = { Name = "${var.prefix}-csk-igw" }
}

# Public Subnets
resource "aws_subnet" "csk_public" {
  for_each = var.create_public_subnet ? { for idx, subnet in local.public_subnets : idx => subnet } : {}

  vpc_id                  = aws_vpc.csk.id
  cidr_block              = each.value.cidr
  map_public_ip_on_launch = true
  availability_zone       = each.value.az

  tags = merge(each.value.tags, { Name = each.value.name })
}

resource "aws_route_table" "csk_public" {
  for_each = var.create_public_subnet ? { for idx, subnet in local.public_subnets : idx => subnet } : {}

  vpc_id = aws_vpc.csk.id

  tags = { Name = format("%s-%02d", local.rt_public_name, index(local.public_subnets, each.value) + 1) }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.csk[0].id
  }
}

# Public Route Table Associations
resource "aws_route_table_association" "csk_public" {
  for_each = { for idx, subnet in aws_subnet.csk_public : idx => subnet }

  subnet_id      = each.value.id
  route_table_id = aws_route_table.csk_public[each.key].id
}

# ------- AWS Private Networking infrastructure -------

# Network Gateways (NAT)
# One NAT Gateway per public subnet, used by private subnets for outbound
# internet access (e.g. pulling container images from public registries).
resource "aws_eip" "csk" {
  for_each = var.create_public_subnet ? { for idx, subnet in local.public_subnets : idx => subnet } : {}

  domain = "vpc"

  tags = { Name = format("%s-%02d", local.nat_name, index(local.public_subnets, each.value) + 1) }
}

resource "aws_nat_gateway" "csk" {
  for_each = var.create_public_subnet ? { for idx, subnet in aws_subnet.csk_public : idx => subnet } : {}

  subnet_id         = each.value.id
  allocation_id     = aws_eip.csk[each.key].id
  connectivity_type = "public"

  tags = { Name = format("%s-%02d", local.nat_name, tonumber(each.key) + 1) }

  depends_on = [aws_internet_gateway.csk]
}

# Private Subnets
# Tagged with kubernetes.io/role/internal-elb=1 as required by the AWS
# Load Balancer Controller for internal load balancer placement.
resource "aws_subnet" "csk_private" {
  for_each = { for idx, subnet in local.private_subnets : idx => subnet }

  vpc_id                  = aws_vpc.csk.id
  cidr_block              = each.value.cidr
  map_public_ip_on_launch = false
  availability_zone       = each.value.az

  tags = merge(
    each.value.tags,
    {
      Name                              = each.value.name
      "kubernetes.io/role/internal-elb" = "1"
    }
  )
}

# Private Route Tables
# When NAT Gateways exist (create_public_subnet = true), a default route
# via NAT is added. When private-only (VPN/DirectConnect), no default
# route is added; routing is handled externally via the VPN/DC gateway.
resource "aws_route_table" "csk_private" {
  for_each = { for idx, subnet in local.private_subnets : idx => subnet }

  vpc_id = aws_vpc.csk.id

  tags = { Name = format("%s-%02d", local.rt_private_name, index(local.private_subnets, each.value) + 1) }

  dynamic "route" {
    for_each = length(aws_nat_gateway.csk) > 0 ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.csk[tostring(index(local.private_subnets, each.value) % length(aws_nat_gateway.csk))].id
    }
  }
}

# Private Route Table Associations
resource "aws_route_table_association" "csk_private" {
  for_each = { for idx, subnet in aws_subnet.csk_private : idx => subnet }

  subnet_id      = each.value.id
  route_table_id = aws_route_table.csk_private[each.key].id
}

# ------- Security Groups -------

# Intra-cluster traffic
resource "aws_security_group" "csk" {
  vpc_id      = aws_vpc.csk.id
  name        = local.sg_intra_name
  description = "Intra-cluster traffic [${var.prefix}]"

  tags = { Name = local.sg_intra_name }
}

resource "aws_vpc_security_group_ingress_rule" "csk" {
  security_group_id            = aws_security_group.csk.id
  description                  = "Self-reference ingress rule"
  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.csk.id

  tags = { Name = "${var.prefix}-csk-intra" }
}

resource "aws_vpc_security_group_egress_rule" "csk" {
  security_group_id = aws_security_group.csk.id
  description       = "Allow all outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"

  tags = { Name = "${var.prefix}-csk-egress" }
}

# ------- S3 Bucket (optional) -------

resource "aws_s3_bucket" "csk" {
  count = var.create_s3_bucket && local.s3_bucket_full_name != "" ? 1 : 0

  bucket = local.s3_bucket_full_name

  tags = {
    Name = local.s3_bucket_full_name
  }
}

# ------- IAM User + Policies (optional) -------

resource "aws_iam_user" "restricted" {
  count = var.create_iam_user ? 1 : 0

  name = local.iam_user_name
  path = "/"

  tags = {
    Name = local.iam_user_name
  }
}

data "aws_iam_policy_document" "s3" {
  statement {
    sid    = "S3Access"
    effect = "Allow"
    actions = [
      "s3:ListAllMyBuckets",
      "s3:GetBucketLocation",
      "s3:ListBucket",
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = concat(
      ["arn:aws:s3:::*"],
      local.s3_bucket_full_name != "" ? ["arn:aws:s3:::${local.s3_bucket_full_name}", "arn:aws:s3:::${local.s3_bucket_full_name}/*"] : []
    )
  }
}

resource "aws_iam_policy" "s3" {
  count = var.create_iam_policies ? 1 : 0

  name   = "${var.prefix}-s3-policy"
  policy = data.aws_iam_policy_document.s3.json
}

data "aws_iam_policy_document" "route53" {
  statement {
    sid    = "Route53Restricted"
    effect = "Allow"
    actions = [
      "route53:ListHostedZones",
      "route53:ListResourceRecordSets",
      "route53:ChangeResourceRecordSets",
      "route53:GetHostedZone"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "route53" {
  count = var.create_iam_policies ? 1 : 0

  name   = "${var.prefix}-route53-policy"
  policy = data.aws_iam_policy_document.route53.json
}

data "aws_iam_policy_document" "ccf" {
  statement {
    sid    = "CCFReadOnly"
    effect = "Allow"
    actions = [
      "ec2:Describe*",
      "elasticloadbalancing:Describe*",
      "autoscaling:Describe*",
      "iam:Get*",
      "iam:List*",
      "eks:Describe*",
      "eks:List*",
      "logs:Describe*",
      "logs:Get*",
      "cloudwatch:Describe*",
      "cloudwatch:Get*"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "ccf" {
  count = var.create_iam_policies ? 1 : 0

  name   = "${var.prefix}-ccf-policy"
  policy = data.aws_iam_policy_document.ccf.json
}

resource "aws_iam_user_policy_attachment" "s3" {
  count = var.create_iam_user && var.create_iam_policies ? 1 : 0

  user       = aws_iam_user.restricted[0].name
  policy_arn = aws_iam_policy.s3[0].arn
}

resource "aws_iam_user_policy_attachment" "route53" {
  count = var.create_iam_user && var.create_iam_policies ? 1 : 0

  user       = aws_iam_user.restricted[0].name
  policy_arn = aws_iam_policy.route53[0].arn
}

resource "aws_iam_user_policy_attachment" "ccf" {
  count = var.create_iam_user && var.create_iam_policies ? 1 : 0

  user       = aws_iam_user.restricted[0].name
  policy_arn = aws_iam_policy.ccf[0].arn
}

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
