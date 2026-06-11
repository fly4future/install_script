#!/bin/bash

# Check if we're running on an NVIDIA Jetson device.
# In that case we have to also install the NVIDIA Container Toolkit, 
# which comprises of a few additional steps compared to a normal docker installation (https://docs.docker.com/engine/install/ubuntu/)
# See https://docs.nvidia.com/jetson/agx-thor-devkit/user-guide/latest/setup_docker.html
grep -q "NVIDIA Jetson" /proc/device-tree/model > /dev/null 2>&1
is_jetson=$?

sudo apt-get update
sudo apt-get install -y ca-certificates curl

if [ "$is_jetson" -eq 0 ]; then
    sudo apt-get install -y nvidia-container jq
fi

# Add Docker's official GPG key:
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker "$USER"

sudo systemctl enable --now docker

if [ "$is_jetson" -eq 0 ]; then
    sudo nvidia-ctk runtime configure --runtime=docker
    sudo systemctl daemon-reload 
    sudo systemctl restart docker

    sudo jq '. + {"default-runtime": "nvidia"}' /etc/docker/daemon.json | \
    sudo tee /etc/docker/daemon.json.tmp && \
    sudo mv /etc/docker/daemon.json.tmp /etc/docker/daemon.json
fi

echo
echo "Docker installation complete. Please log out and log back in to apply the changes to your user group and be able to use the docker command without sudo."
echo

exit 0
