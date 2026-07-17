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

output "intra_cluster_security_group" {
  value       = aws_security_group.csk
  description = "Intra-cluster traffic Security Group"
}

output "bastion_ip" {
  value       = var.create_bastion ? (aws_instance.bastion[0].public_ip != "" ? aws_instance.bastion[0].public_ip : aws_instance.bastion[0].private_ip) : ""
  description = "Routable IP of the bastion (public if the subnet auto-assigned one, otherwise private). Empty when create_bastion = false."
}

