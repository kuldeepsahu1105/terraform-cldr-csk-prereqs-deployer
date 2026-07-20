# Copyright 2026 Cloudera, Inc.
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

# =============================================
# Variables
# =============================================

# =============================================
# Locals
# =============================================

locals {
  bastion_name           = "${var.prefix}-csk-bastion"
  bastion_sg_name        = "${var.prefix}-csk-bastion-sg"
  bastion_keypair_name   = "${var.prefix}-csk-bastion-keypair"
  bastion_create_keypair = var.bastion_ssh_private_key_file == null ? true : false
}

# =============================================
# Data sources
# =============================================

data "aws_ami" "bastion" {
  count       = var.create_bastion ? 1 : 0
  most_recent = true
  owners      = [var.bastion_image_owner]

  filter {
    name   = "name"
    values = [var.bastion_image_name]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# =============================================
# Key pair
# =============================================

# Generate a new private key if no existing key file is provided
resource "tls_private_key" "bastion" {
  count     = var.create_bastion && local.bastion_create_keypair ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save the generated private key to a local .pem file
resource "local_sensitive_file" "bastion_pem_file" {
  count                = var.create_bastion && local.bastion_create_keypair ? 1 : 0
  filename             = "${path.module}/../${var.prefix}-bastion-ssh-key.pem"
  file_permission      = "600"
  directory_permission = "700"
  content              = tls_private_key.bastion[0].private_key_pem
}

# Load the public key from whichever private key is in use
data "tls_public_key" "bastion" {
  count               = var.create_bastion ? 1 : 0
  private_key_openssh = local.bastion_create_keypair ? tls_private_key.bastion[0].private_key_openssh : file(abspath(pathexpand(var.bastion_ssh_private_key_file)))
}

# Create the AWS EC2 key pair from the selected public key
resource "aws_key_pair" "bastion" {
  count      = var.create_bastion ? 1 : 0
  key_name   = local.bastion_keypair_name
  public_key = trimspace(data.tls_public_key.bastion[0].public_key_openssh)
}

# =============================================
# Security group
# =============================================

resource "aws_security_group" "bastion" {
  count       = var.create_bastion ? 1 : 0
  name        = local.bastion_sg_name
  description = "SSH access to bastion host [${var.prefix}]"
  vpc_id      = aws_vpc.csk.id

  tags = { Name = local.bastion_sg_name }
}

# One ingress rule per allowed CIDR — mirrors the pattern in the cluster-manager module.
resource "aws_vpc_security_group_ingress_rule" "bastion_ssh" {
  for_each = var.create_bastion ? toset(var.bastion_ssh_allowed_cidrs) : toset([])

  security_group_id = aws_security_group.bastion[0].id
  description       = "SSH from ${each.value}"
  cidr_ipv4         = each.value
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22

  tags = { Name = "${local.bastion_sg_name}-ssh" }
}

resource "aws_vpc_security_group_egress_rule" "bastion" {
  count             = var.create_bastion ? 1 : 0
  security_group_id = aws_security_group.bastion[0].id
  description       = "Allow all outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"

  tags = { Name = "${local.bastion_sg_name}-egress" }
}

# =============================================
# Bastion instance
# =============================================

resource "aws_instance" "bastion" {
  count = var.create_bastion ? 1 : 0

  ami           = data.aws_ami.bastion[0].id
  instance_type = var.bastion_instance_type
  user_data     = file("${path.module}/files/bastion-csk-installer-prereqs.sh")

  # Place in the first public subnet (map_public_ip_on_launch = true in main.tf).
  subnet_id = aws_subnet.csk_public["0"].id

  # Attach both the bastion SSH security group and the intra-cluster security group
  # so the bastion can also communicate with private cluster nodes.
  vpc_security_group_ids = [
    aws_security_group.bastion[0].id,
    aws_security_group.csk.id,
  ]

  key_name = aws_key_pair.bastion[0].key_name

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name = local.bastion_name
    Role = "bastion"
  }

  lifecycle {
    precondition {
      condition     = var.create_public_subnet
      error_message = "create_bastion = true requires create_public_subnet = true so that a public subnet exists."
    }
  }
}

# Wait for cloud-init (user data) to complete before declaring the bastion ready.
# Re-runs automatically if the instance is replaced (triggers on instance ID).
resource "null_resource" "bastion_ready" {
  count = var.create_bastion ? 1 : 0

  triggers = {
    instance_id = aws_instance.bastion[0].id
  }

  connection {
    type        = "ssh"
    host        = aws_instance.bastion[0].public_ip != "" ? aws_instance.bastion[0].public_ip : aws_instance.bastion[0].private_ip
    user        = "ubuntu"
    private_key = local.bastion_create_keypair ? tls_private_key.bastion[0].private_key_pem : file(abspath(pathexpand(var.bastion_ssh_private_key_file)))
    timeout     = "15m"
  }

  provisioner "remote-exec" {
    inline = [
      "cloud-init status --wait",
    ]
  }
}
