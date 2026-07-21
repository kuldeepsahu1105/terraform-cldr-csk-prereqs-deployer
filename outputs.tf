########################################
# VPC
########################################

output "vpc_id" {
  value       = aws_vpc.csk.id
  description = "VPC ID"
}

output "vpc_cidr" {
  value       = aws_vpc.csk.cidr_block
  description = "VPC CIDR block"
}

########################################
# Availability Zones
########################################

output "availability_zones" {
  value       = data.aws_availability_zones.csk.names
  description = "AWS Availability Zones"
}

########################################
# Public Subnets
########################################

output "public_subnets" {
  value = [
    for s in values(aws_subnet.csk_public) : {
      id   = s.id
      name = s.tags["Name"]
    }
  ]
  description = "Public subnet IDs and names"
}

/*
output "public_subnet_ids" {
  value       = [for s in values(aws_subnet.csk_public) : s.id]
  description = "Public subnet IDs"
}
*/

########################################
# Private Subnets
########################################

output "private_subnets" {
  value = [
    for s in values(aws_subnet.csk_private) : {
      id   = s.id
      name = s.tags["Name"]
    }
  ]
  description = "Private subnet IDs and names"
}

/*
output "private_subnet_ids" {
  value       = [for s in values(aws_subnet.csk_private) : s.id]
  description = "Private subnet IDs"
}
*/

########################################
# Security Group
########################################

/*
output "intra_cluster_security_group_name" {
  value       = aws_security_group.csk.name
  description = "Intra-cluster security group name"
}

output "intra_cluster_security_group_id" {
  value       = aws_security_group.csk.id
  description = "Intra-cluster security group ID"
}
*/

########################################
# Bastion
########################################

output "bastion_ip" {
  value = var.create_bastion ? (
    aws_instance.bastion[0].public_ip != "" ?
    aws_instance.bastion[0].public_ip :
    aws_instance.bastion[0].private_ip
  ) : ""

  description = "Bastion Server IP address"
}

/*
output "bastion_public_ip" {
  value       = var.create_bastion ? aws_instance.bastion[0].public_ip : ""
  description = "Bastion public IP"
}

output "bastion_private_ip" {
  value       = var.create_bastion ? aws_instance.bastion[0].private_ip : ""
  description = "Bastion private IP"
}
*/

output "bastion_keypair_name" {
  value       = var.create_bastion ? aws_key_pair.bastion[0].key_name : ""
  description = "Bastion key pair name"
}

########################################
# EFS
########################################

output "efs_id" {
  value       = var.create_efs ? aws_efs_file_system.ccf_awc[0].id : ""
  description = "EFS File System ID"
}

########################################
# S3
########################################

output "s3_bucket_name" {
  value       = var.create_s3_bucket && local.s3_bucket_full_name != "" ? aws_s3_bucket.csk[0].bucket : ""
  description = "S3 bucket name"
}

output "s3_bucket_arn" {
  value       = var.create_s3_bucket && local.s3_bucket_full_name != "" ? aws_s3_bucket.csk[0].arn : ""
  description = "S3 bucket ARN"
}

########################################
# IAM
########################################

output "iam_user_name" {
  value       = var.create_iam_user ? aws_iam_user.restricted[0].name : ""
  description = "Restricted IAM user"
}

########################################
# Route53 Public Hosted Zone
########################################

output "route53_public_zone" {
  value = var.create_public_hosted_zone ? {
    id   = aws_route53_zone.public[0].zone_id
    name = aws_route53_zone.public[0].name
  } : null

  description = "Public Route53 hosted zone"
}

########################################
# Route53 Private Hosted Zone
########################################

output "route53_private_zone" {
  value = var.create_private_hosted_zone ? {
    id   = aws_route53_zone.private[0].zone_id
    name = aws_route53_zone.private[0].name
  } : null

  description = "Private Route53 hosted zone"
}

########################################
# IAM Policies
########################################

output "iam_policy_names" {
  value = var.create_iam_policies ? {
    ccf      = aws_iam_policy.ccf[0].name
    route53  = aws_iam_policy.route53[0].name
    s3_backup = aws_iam_policy.s3[0].name
  } : {}

  description = "Names of the IAM policies created"
}
