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

# ------- Required -------

variable "prefix" {
  type        = string
  description = "Deployment prefix for all cloud-provider assets"
  validation {
    condition     = length(var.prefix) >= 4 && length(var.prefix) <= 10
    error_message = "Valid length for prefix is between 4-7 characters."
  }
}

variable "aws_region" {
  type        = string
  description = "AWS region to deploy resources into"
}

variable "owner" {
  type        = string
  description = "Owner tag for all resources"
  default     = "coe-pse-apac"
}
# ------- VPC -------

variable "vpc_name" {
  type        = string
  description = "VPC name"
  default     = ""
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block"
  default     = "10.0.0.0/16"
}

# ------- Private Network infrastructure -------

variable "private_subnet_name" {
  type        = string
  description = "Private Subnet name prefix"
  default     = ""
}

variable "private_subnets" {
  type = list(object({
    name = string
    cidr = string
    az   = string
    tags = map(string)
  }))
  description = "List of Private Subnet details (name, CIDR, AZ, add'l tags). Defaults to a single /24 subnet in the first available AZ."
  default     = []
}

variable "private_route_table_name" {
  type        = string
  description = "Private Route Table name prefix"
  default     = ""
}

# ------- Public Network infrastructure (optional) -------
# Required when no VPN or AWS DirectConnect connectivity is available.
# Enables bastion host placement and NAT Gateway for private subnet
# outbound internet access (e.g. pulling container images).

variable "create_public_subnet" {
  type        = bool
  description = "Create a public subnet with Internet Gateway and NAT Gateway. Set to true when no VPN or DirectConnect connectivity is available."
  default     = false
}

variable "public_subnet_name" {
  type        = string
  description = "Public Subnet name prefix"
  default     = ""
}

variable "public_subnets" {
  type = list(object({
    name = string
    cidr = string
    az   = string
    tags = map(string)
  }))
  description = "List of Public Subnet details (name, CIDR, AZ, add'l tags). Defaults to a single /24 subnet in the first available AZ."
  default     = []
}

variable "public_route_table_name" {
  type        = string
  description = "Public Route Table name prefix"
  default     = ""
}

variable "nat_gateway_name" {
  type        = string
  description = "NAT Gateway name prefix"
  default     = ""
}

# ------- Security Groups -------

variable "security_group_intra_name" {
  type        = string
  description = "Security Group name for intra-cluster communication"
  default     = ""
}

# ------- Bastion Host (optional) -------
variable "create_bastion" {
  type        = bool
  description = "Create a bastion (SSH jump host) in the first public subnet. Requires create_public_subnet = true."
  default     = false
}

variable "bastion_instance_type" {
  type        = string
  description = "EC2 instance type for the bastion host"
  default     = "t3.medium"
}

variable "bastion_image_name" {
  type        = string
  description = "AMI name pattern (supports wildcards) used to look up the most recent matching image owned by bastion_image_owner"
  default     = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
}

variable "bastion_image_owner" {
  type        = string
  description = "AWS account ID that owns the bastion AMI (default: Canonical)"
  default     = "099720109477"
}

variable "bastion_ssh_private_key_file" {
  type        = string
  description = "Path to an existing SSH private key file to use for the bastion. Set to null to auto-generate a new RSA key pair and save the private key locally."
  default     = null
}

variable "bastion_ssh_allowed_cidrs" {
  type        = list(string)
  description = "CIDR blocks allowed to reach the bastion on port 22. An empty list creates no inbound SSH rules."
  default     = []
}

# ------- S3 bucket (optional) -------
variable "create_s3_bucket" {
  description = "Flag to determine if an S3 bucket should be created"
  type        = bool
  default     = false
}

variable "s3_bucket_name" {
  description = "The name of the S3 bucket to be created. Leave empty if no bucket is required."
  type        = string
  default     = ""
}

variable "create_iam_user" {
  description = "Flag to determine if an IAM user should be created"
  type        = bool
  default     = false
}

variable "create_iam_policies" {
  description = "Flag to determine if IAM policies should be created"
  type        = bool
  default     = false
}

variable "create_efs" {
  description = "Flag to determine if EFS should be created"
  type        = bool
  default     = false
}
#--------Hosted Zone---------------

variable "parent_hosted_zone" {
  description = "Existing parent hosted zone"
  type        = string
  default     = "clouderapartners.click"
}

variable "create_public_hosted_zone" {
  type    = bool
  default = true
}

variable "create_private_hosted_zone" {
  type    = bool
  default = true
}