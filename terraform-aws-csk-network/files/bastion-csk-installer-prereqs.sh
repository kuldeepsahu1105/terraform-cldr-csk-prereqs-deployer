#!/bin/bash

# Copyright 2025 Cloudera, Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#####################################################
# User Data script to provision CSK installer
# prerequisites on an Ubuntu bastion EC2 instance.
#####################################################

set -euo pipefail
log() { echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] $*"; }

# Install Docker
sudo apt-get update
sudo apt-get -y install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
service docker start
usermod -a -G docker ubuntu

# =============================================================
# 1. System Preparation
# =============================================================
log "=== 1. System Preparation ==="
apt-get update
apt-get install -y python3-pip python3.12-venv ca-certificates curl gnupg unzip git

# =============================================================
# 2. Python Virtual Environment at /opt/csk-venv
# =============================================================
log "=== 2. Python Virtual Environment ==="

PYTHON_BIN=python3
WORKSPACE_GROUP=csk
VENV_DIR=/opt/csk-venv

${PYTHON_BIN} -m venv "${VENV_DIR}"

if getent group "${WORKSPACE_GROUP}" > /dev/null; then
  echo "Group '${WORKSPACE_GROUP}' exists."
else
  addgroup "${WORKSPACE_GROUP}"
fi
chgrp -R "${WORKSPACE_GROUP}" "${VENV_DIR}"
chmod -R 2774 "${VENV_DIR}"

# Add ubuntu user to the shared venv group
usermod -a -G "${WORKSPACE_GROUP}" ubuntu

# =============================================================
# 3. Install Ansible Core
# =============================================================
log "=== 3. Install Ansible Core ==="
"${VENV_DIR}/bin/pip" install "ansible-core==2.17.8"
"${VENV_DIR}/bin/pip" install netaddr

# =============================================================
# 4. Install Ansible Collections
# =============================================================
log "=== 4. Install Ansible Collections ==="
mkdir -p /usr/share/ansible/collections
"${VENV_DIR}/bin/ansible-galaxy" collection install -p /usr/share/ansible/collections ansible.posix
"${VENV_DIR}/bin/ansible-galaxy" collection install -p /usr/share/ansible/collections ansible.utils
"${VENV_DIR}/bin/ansible-galaxy" collection install -p /usr/share/ansible/collections ansible.netcommon
"${VENV_DIR}/bin/ansible-galaxy" collection install -p /usr/share/ansible/collections community.general
"${VENV_DIR}/bin/ansible-galaxy" collection install -p /usr/share/ansible/collections kubernetes.core
"${VENV_DIR}/bin/ansible-galaxy" collection install -p /usr/share/ansible/collections community.kubernetes

# =============================================================
# 5. Install OpenTofu
# =============================================================
log "=== 5. Install OpenTofu ==="
TOFU_VERSION="1.6.2"
TOFU_ARCH="$(dpkg --print-architecture)"
wget -q "https://github.com/opentofu/opentofu/releases/download/v${TOFU_VERSION}/tofu_${TOFU_VERSION}_linux_${TOFU_ARCH}.zip" -O /tmp/tofu.zip
unzip -q /tmp/tofu.zip -d /tmp/tofu-bin
mv /tmp/tofu-bin/tofu /usr/local/bin/tofu
chmod +x /usr/local/bin/tofu
rm -rf /tmp/tofu.zip /tmp/tofu-bin
tofu version

# =============================================================
# 6. Install ORAS CLI
# =============================================================
log "=== 6. Install ORAS CLI ==="
ORAS_VERSION="1.2.0"
ORAS_ARCH="$(dpkg --print-architecture)"
wget -q "https://github.com/oras-project/oras/releases/download/v${ORAS_VERSION}/oras_${ORAS_VERSION}_linux_${ORAS_ARCH}.tar.gz" -O /tmp/oras.tar.gz
tar -xzf /tmp/oras.tar.gz -C /tmp oras
mv /tmp/oras /usr/local/bin/oras
chmod +x /usr/local/bin/oras
rm /tmp/oras.tar.gz
oras version

# =============================================================
# 7. Install Flux CLI
# =============================================================
log "=== 7. Install Flux CLI ==="
curl -s https://fluxcd.io/install.sh | bash
flux --version

# =============================================================
# 8. Install kubectl
# =============================================================
log "=== 8. Install kubectl ==="
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" \
  | tee /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubectl
kubectl version --client

# =============================================================
# 9. Install k9s
# =============================================================
log "=== 9. Install k9s ==="
wget -q https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_amd64.tar.gz -O /tmp/k9s.tar.gz
tar -xzf /tmp/k9s.tar.gz -C /tmp k9s
chmod +x /tmp/k9s
mv /tmp/k9s /usr/local/bin/k9s
rm -f /tmp/k9s.tar.gz
k9s version

# =============================================================
# 10. Auto-activate venv on login for ubuntu user
# =============================================================
log "=== 9. Configure venv auto-activation for ubuntu user ==="

BASHRC="/home/ubuntu/.bashrc"
ACTIVATE_LINE="source ${VENV_DIR}/bin/activate"

if ! grep -qF "${ACTIVATE_LINE}" "${BASHRC}" 2>/dev/null; then
  cat >> "${BASHRC}" <<EOF

# Activate CSK Python virtual environment
${ACTIVATE_LINE}
EOF
fi

log "=== Provisioning complete ==="
