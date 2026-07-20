# Copyright 2025 Cloudera, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

output "vpc_id" {
  value       = aws_vpc.csk.id
  description = "VPC ID"
}

output "vpc_cidr" {
  value       = aws_vpc.csk.cidr_block
  description = "VPC CIDR block"
}

output "availability_zones" {
  value       = data.aws_availability_zones.csk
  description = "AWS Availability Zones"
}

output "public_subnets" {
  value       = values(aws_subnet.csk_public)
  description = "Cluster public subnets (empty when create_public_subnet = false)"
}

output "private_subnets" {
  value       = values(aws_subnet.csk_private)
  description = "Cluster private subnets (tagged with kubernetes.io/role/internal-elb=1)"
}

output "public_subnet_ids" {
  value       = [for s in values(aws_subnet.csk_public) : s.id]
  description = "Public subnet IDs (empty when create_public_subnet = false)"
}

output "private_subnet_ids" {
  value       = [for s in values(aws_subnet.csk_private) : s.id]
  description = "Private subnet IDs"
}

output "intra_cluster_security_group" {
  value       = aws_security_group.csk
  description = "Intra-cluster traffic Security Group"
}

output "intra_cluster_security_group_id" {
  value       = aws_security_group.csk.id
  description = "ID of the intra-cluster security group"
}

output "bastion_ip" {
  value       = var.create_bastion ? (aws_instance.bastion[0].public_ip != "" ? aws_instance.bastion[0].public_ip : aws_instance.bastion[0].private_ip) : ""
  description = "Routable IP of the bastion (public if the subnet auto-assigned one, otherwise private). Empty when create_bastion = false."
}

output "bastion_public_ip" {
  value       = var.create_bastion ? aws_instance.bastion[0].public_ip : ""
  description = "Public IP of bastion (empty if not assigned or bastion disabled)"
}

output "bastion_private_ip" {
  value       = var.create_bastion ? aws_instance.bastion[0].private_ip : ""
  description = "Private IP of bastion (empty when create_bastion = false)"
}

output "bastion_keypair_name" {
  value       = var.create_bastion ? aws_key_pair.bastion[0].key_name : ""
  description = "AWS key pair name used by bastion (empty when create_bastion = false)"
}

output "efs_id" {
  value       = var.create_efs ? aws_efs_file_system.ccf_awc[0].id : ""
  description = "EFS file system ID (empty when create_efs = false)"
}

output "s3_bucket_name" {
  value       = var.create_s3_bucket && local.s3_bucket_full_name != "" ? aws_s3_bucket.csk[0].bucket : ""
  description = "S3 bucket name (empty when create_s3_bucket = false)"
}

output "iam_user_name" {
  value       = var.create_iam_user ? aws_iam_user.restricted[0].name : ""
  description = "IAM user name created for restricted access (empty when create_iam_user = false)"
}

output "route53_public_zone_id" {
  value       = var.create_public_hosted_zone ? aws_route53_zone.public[0].zone_id : ""
  description = "Public Route53 hosted zone ID (empty when create_public_hosted_zone = false)"
}

output "route53_private_zone_id" {
  value       = var.create_private_hosted_zone ? aws_route53_zone.private[0].zone_id : ""
  description = "Private Route53 hosted zone ID (empty when create_private_hosted_zone = false)"
}
