#!/bin/bash

# Instructions for installing Docker: https://docs.docker.com/engine/install/ubuntu
# Instructions for installing and configuring Nvidia Container Toolkit: https://docs.nvidia.com/jetson/orin-nano-devkit/user-guide/latest/setup_docker.html
# Note that the instructions for the toolkit are wrong. The correct package to install is nvidia-container-toolkit, not nvidia-container, see https://github.com/fly4future/install_script/pull/18 for more info.

set -e

sudo apt-get install -y ca-certificates curl

# Check if we're running on an NVIDIA Jetson device.
if grep -q "NVIDIA Jetson" /proc/device-tree/model > /dev/null 2>&1; then
    sudo apt-get install -y nvidia-container-toolkit jq
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
sudo systemctl enable --now docker

if grep -q "NVIDIA Jetson" /proc/device-tree/model > /dev/null 2>&1; then
    echo "Configuring Docker to use NVIDIA Container Toolkit as the default runtime..."
    sudo nvidia-ctk runtime configure --runtime=docker
    sudo systemctl daemon-reload
    sudo systemctl restart docker

    sudo jq '. + {"default-runtime": "nvidia"}' /etc/docker/daemon.json | sudo tee /etc/docker/daemon.json.tmp
    sudo mv /etc/docker/daemon.json.tmp /etc/docker/daemon.json
    sudo systemctl restart docker


# Add current user to docker group if not already a member
if ! groups "$USER" | grep -qw docker; then
    echo "Adding $USER to docker group..."
    sudo usermod -aG docker "$USER"
else
    echo "$USER is already in the docker group."
fi

echo
echo "Installation complete."
echo

if ! groups "$USER" | grep -qw docker; then
    echo "Please log out and log back in for docker group membership to take effect."
fi

exit 0
