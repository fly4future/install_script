#!/bin/bash

# Define the repository URL and the target directory
REPO_URL="https://github.com/lakinduakash/linux-wifi-hotspot"
TARGET_DIR="/tmp/linux-wifi-hotspot"

# Update package list and install necessary dependencies
echo "Updating package list and installing dependencies..."
sudo apt-get update
sudo apt-get install -y libgtk-3-dev build-essential gcc g++ pkg-config make hostapd libqrencode-dev libpng-dev haveged python3-pip

# Determine the system architecture
ARCH=$(uname -m)

# Install yq based on the architecture
if [[ "$ARCH" == "x86_64" ]]; then
    # For x86_64 architecture
    echo "Detected x86_64 architecture. Installing yq for x86_64..."
    sudo wget https://github.com/mikefarah/yq/releases/download/v4.30.8/yq_linux_amd64 -O /usr/local/bin/yq
elif [[ "$ARCH" == "aarch64" ]]; then
    # For ARM64 architecture
    echo "Detected ARM architecture. Installing yq for ARM..."
    sudo wget https://github.com/mikefarah/yq/releases/download/v4.30.8/yq_linux_arm64 -O /usr/local/bin/yq
else
    echo "Unknown architecture ($ARCH). Exiting..."
    exit 1
fi

# Make yq executable
sudo chmod +x /usr/local/bin/yq

# Install haveged to avoid low entropy issues (will be started only when needed)
if ! systemctl is-active --quiet haveged; then
    echo "Enabling haveged to improve system entropy..."
    sudo systemctl enable haveged
fi

# Clone the repository and install the tool
if [ -d "$TARGET_DIR" ]; then
    echo "Removing existing target directory..."
    sudo rm -rf "$TARGET_DIR"
fi

echo "Cloning repository from $REPO_URL..."
sudo git clone "$REPO_URL" "$TARGET_DIR"

# Build and install CLI-only version
cd "$TARGET_DIR"
echo "Building and installing CLI-only version of the tool..."
sudo make && sudo make install-cli-only

# Clean up target directory if installation succeeds
echo "Cleaning up target directory..."
sudo rm -rf "$TARGET_DIR"

echo "Installation complete."
exit 0

