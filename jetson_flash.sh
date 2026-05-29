#!/bin/bash

#
# This script is used to flash a NVIDIA Jetson device
# The script will:
#  - download the driver package (BSP) and sample root file system from NVIDIA
#  - prepare prepare binaries needed to flash the device
#  - prepare the filesystem with a headless user and autologin enabled
#  - flash the device with the prepared filesystem and binaries
#
# After this script completes you can continue configuration on the device itself with the setup_utility_F4F.sh or setup_utility_MRS.sh scripts
#

set -euo pipefail

# Change these URLs to point to the version you want to install. Available versions: https://developer.nvidia.com/embedded/jetson-linux-archive
# Prompt for the Jetson Linux version and derive the URLs from it.
DEFAULT_JETSON_LINUX_VERSION="36.5.0"
DEFAULT_HEADLESS_USER="uav"
DEFAULT_HEADLESS_PASSWORD="f4f"
DEFAULT_HOSTNAME="uav1"


# Prompt for each setting; accept the default by pressing Enter
read -r -p "Jetson Linux version [${DEFAULT_JETSON_LINUX_VERSION}]:" input
JETSON_LINUX_VERSION=${input:-$DEFAULT_JETSON_LINUX_VERSION}

if ! [[ "$JETSON_LINUX_VERSION" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    echo "Invalid Jetson Linux version: $JETSON_LINUX_VERSION (expected major.minor.patch)" >&2
    exit 1
fi

VERSION_MAJOR="${BASH_REMATCH[1]}"
VERSION_MINOR="${BASH_REMATCH[2]}"
VERSION_PATCH="${BASH_REMATCH[3]}"

DOWNLOAD_BASE_URL="https://developer.nvidia.com/downloads/embedded/l4t/r${VERSION_MAJOR}_release_v${VERSION_MINOR}.${VERSION_PATCH}/release"

# Nvidia is not consistent with their file naming, sometimes they use capital letters, sometimes not
DRIVER_PACKAGE_URL="${DOWNLOAD_BASE_URL}/Jetson_Linux_r${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}_aarch64.tbz2"
DRIVER_PACKAGE_URL_FALLBACK="${DOWNLOAD_BASE_URL}/jetson_linux_r${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}_aarch64.tbz2"
SAMPLE_ROOT_FS_URL="${DOWNLOAD_BASE_URL}/Tegra_Linux_Sample-Root-Filesystem_r${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}_aarch64.tbz2"
SAMPLE_ROOT_FS_URL_FALLBACK="${DOWNLOAD_BASE_URL}/tegra_linux_sample-root-filesystem_r${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}_aarch64.tbz2"

read -r -p "Username [${DEFAULT_HEADLESS_USER}]:" input
HEADLESS_USER=${input:-$DEFAULT_HEADLESS_USER}

read -r -s -p "Password [${DEFAULT_HEADLESS_PASSWORD}]:" input
echo ""
HEADLESS_PASSWORD=${input:-$DEFAULT_HEADLESS_PASSWORD}

read -r -p "Hostname [${DEFAULT_HOSTNAME}]:" input
HOSTNAME=${input:-$DEFAULT_HOSTNAME}

read -r -p "Keep temporary files in $HOME/jetson_configure_tmp after flashing? Keep them in case you need to flash multiple times. (Y/n)" input
input=${input:-y}
if [[ "$input" == "y" ]] || [[ "$input" == "Y" ]]; then
    KEEP_TMP_DIR=true
else
    KEEP_TMP_DIR=false
fi

TMP_DIR_NAME="jetson_configure_tmp"
TMP_DIR_ROOT="$HOME"


function cleanup_tmp_dir {
    if ! $KEEP_TMP_DIR; then
        echo "Cleaning up temporary files..."
        sudo rm -rf "$tmp_dir"
    fi
}

function download_with_fallback {
    local output_file="$1"
    shift

    local url
    for url in "$@"; do
        if wget "$url" -O "$output_file"; then
            return 0
        fi
    done

    echo "Unable to download ${output_file}" >&2
    exit 1
}

trap 'cleanup_tmp_dir' EXIT

# Download BSP and root file system
tmp_dir="$TMP_DIR_ROOT/$TMP_DIR_NAME"
mkdir -p "$tmp_dir"
cd "$tmp_dir"

if [ -f jetson_linux.tbz2 ]; then
    read -r -p "A driver package archive already downloaded, do you want to re-download it? (y/N):" answer
    answer=${answer:-n}
    if [[ "$answer" == "y" ]] || [[ "$answer" == "Y" ]]; then
        download_with_fallback jetson_linux.tbz2 "$DRIVER_PACKAGE_URL" "$DRIVER_PACKAGE_URL_FALLBACK"
    fi
else
    download_with_fallback jetson_linux.tbz2 "$DRIVER_PACKAGE_URL" "$DRIVER_PACKAGE_URL_FALLBACK"
fi

if [ -f sample_rootfs.tbz2 ]; then
    read -r -p "A root filesystem archive already downloaded, do you want to re-download it? (y/N):" answer
    answer=${answer:-n}
    if [[ "$answer" == "y" ]] || [[ "$answer" == "Y" ]]; then
        download_with_fallback sample_rootfs.tbz2 "$SAMPLE_ROOT_FS_URL" "$SAMPLE_ROOT_FS_URL_FALLBACK"
    fi
else
    download_with_fallback sample_rootfs.tbz2 "$SAMPLE_ROOT_FS_URL" "$SAMPLE_ROOT_FS_URL_FALLBACK"
fi

if [ -d Linux_for_Tegra ]; then
    echo "Linux_for_Tegra directory already exists, re-using it"
else

    # Extract BSP and root file system
    echo "Extracting downloaded files..."
    tar -xvf jetson_linux.tbz2
    cd "$tmp_dir/Linux_for_Tegra/rootfs/"
    echo "Extracting filesystem..."
    sudo tar -jxpf ../../sample_rootfs.tbz2

    # Apply binaries
    echo "Preparing environment..."
    cd "$tmp_dir/Linux_for_Tegra"  # Go back to Linux_for_Tegra directory
    sudo ./tools/l4t_flash_prerequisites.sh
    sudo ./apply_binaries.sh
fi

# Create a headless user
echo "Setting hostname $HOSTNAME and user $HEADLESS_USER with password $HEADLESS_PASSWORD. Autologin enabled."
cd "$tmp_dir/Linux_for_Tegra/"
sudo ./tools/l4t_create_default_user.sh --username "$HEADLESS_USER" --password "$HEADLESS_PASSWORD" --autologin --hostname "$HOSTNAME" --accept-license


# Tell user to put device in recovery mode. Print instructions, do not let pass until device is in recovery mode)
echo ""
echo "Connect the Jetson device to your computer with the USB cable and put it in Force Recovery Mode following these steps:"
echo "Devices with buttons:"
echo "1. Power off the device."
echo "2. Press and hold down the Force Recovery button."
echo "3. Press, then release the Power button."
echo "4. Release the Force Recovery button."
echo ""
echo "Devices without buttons:"
echo "1. Turn off the device and disconnect it from power."
echo "2. Enable Force Recovery Mode by placing a jumper wire across pins 9 and 10 (FC REC and GND), located on the edge of the carrier board under the Jetson module."
echo "3. Connect power to the device while the jumper is in place. Jetson should automatically boot into Force Recovery Mode."
echo "4. Remove the jumper wire after the device is powered on."
echo ""
echo "The script will continue automatically once the device in Force Recovery Mode is detected"

# Run lsusb until an entry like "ID 0955:7523 NVIDIA Corp. APX" is detected
while true; do
    if lsusb | grep -q "NVIDIA Corp. APX"; then
        echo "Device in Force Recovery Mode detected!"
        break
    fi
    sleep 1
done

# Flash bootloader to QSPI and rootfs to NVMe. Look at README_initrd_flash.txt for more info about other ways of flashing in case you need it
echo "Flashing device..."
sudo ./tools/kernel_flash/l4t_initrd_flash.sh --external-device nvme0n1p1 \
  -c tools/kernel_flash/flash_l4t_external.xml -p "-c bootloader/t186ref/cfg/flash_t234_qspi.xml" \
  --showlogs --network usb0 jetson-orin-nano-devkit internal


echo ""
echo "OS flashing complete. Now you can connect to the Jetson and continue configuration there."
echo ""
