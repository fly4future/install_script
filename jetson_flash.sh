#!/bin/bash

#
# This script is used to flash a NVIDIA Jetson device
# The script will:
#  - download the driver package (BSP) and sample root file system from NVIDIA
#  - prepare prepare binaries needed to flash the device
#  - prepare the filesystem with a user and autologin enabled
#  - flash the device with the prepared filesystem and binaries
#
# After this script completes you can continue configuration on the device itself with the setup_utility.sh script
#

set -euo pipefail

# Change these URLs to point to the version you want to install. Available versions: https://developer.nvidia.com/embedded/jetson-linux-archive
# Prompt for the Jetson Linux version and derive the URLs from it.
default_jetson_linux_version="39.2.0"   # Confirmed working versions: 36.5.0, 39.2.0
default_user="uav"
default_password="f4f"
default_hostname="uav1"

function cleanup_tmp_root_dir {
    if ! $keep_tmp_root_dir; then
        echo "Cleaning up temporary files..."
        sudo rm -rf "$TMP_ROOT_DIR"
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

trap 'cleanup_tmp_root_dir' EXIT

# Prompt for each setting; accept the default by pressing Enter
read -r -p "Jetson Linux version. List of available versions here: https://developer.nvidia.com/embedded/jetson-linux-archive [${default_jetson_linux_version}]: " input
jetson_linux_version=${input:-$default_jetson_linux_version}

if ! [[ "$jetson_linux_version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    echo "Invalid Jetson Linux version format: $jetson_linux_version (expected major.minor.patch)" >&2
    exit 1
fi
version_major="${BASH_REMATCH[1]}"
version_minor="${BASH_REMATCH[2]}"
version_patch="${BASH_REMATCH[3]}"

read -r -p "Username [${default_user}]: " input
user=${input:-$default_user}

read -r -s -p "Password [${default_password}]: " input
echo ""
password=${input:-$default_password}

read -r -p "Hostname [${default_hostname}]: " input
hostname=${input:-$default_hostname}

tmp_dir="$HOME/jetson_flash_tmp_${version_major}_${version_minor}_${version_patch}"   # Where the downloaded and extracted files will be stored on the host machine
read -r -p "Keep temporary files in $tmp_dir after flashing? Keep them in case you need to flash multiple times. (Y/n): " input
input=${input:-y}
if [[ "$input" == "y" ]] || [[ "$input" == "Y" ]]; then
    keep_tmp_root_dir=true
else
    keep_tmp_root_dir=false
fi

# Nvidia is not consistent with their file naming, sometimes they use capital letters, sometimes not
download_base_url="https://developer.nvidia.com/downloads/embedded/l4t/r${version_major}_release_v${version_minor}.${version_patch}/release"
driver_package_url="${download_base_url}/Jetson_Linux_r${version_major}.${version_minor}.${version_patch}_aarch64.tbz2"
driver_package_url_fallback="${download_base_url}/jetson_linux_r${version_major}.${version_minor}.${version_patch}_aarch64.tbz2"
sample_root_fs_url="${download_base_url}/Tegra_Linux_Sample-Root-Filesystem_r${version_major}.${version_minor}.${version_patch}_aarch64.tbz2"
sample_root_fs_url_fallback="${download_base_url}/tegra_linux_sample-root-filesystem_r${version_major}.${version_minor}.${version_patch}_aarch64.tbz2"

# Download BSP and root file system
echo "Downloading Jetson Linux $jetson_linux_version files to $tmp_dir..."
mkdir -p "$tmp_dir"
cd "$tmp_dir"

if [ -f jetson_linux.tbz2 ]; then
    read -r -p "A driver package archive already downloaded, do you want to re-download it? (y/N): " answer
    answer=${answer:-n}
    if [[ "$answer" == "y" ]] || [[ "$answer" == "Y" ]]; then
        download_with_fallback jetson_linux.tbz2 "$driver_package_url" "$driver_package_url_fallback"
    fi
else
    download_with_fallback jetson_linux.tbz2 "$driver_package_url" "$driver_package_url_fallback"
fi

if [ -f sample_rootfs.tbz2 ]; then
    read -r -p "A root filesystem archive already downloaded, do you want to re-download it? (y/N): " answer
    answer=${answer:-n}
    if [[ "$answer" == "y" ]] || [[ "$answer" == "Y" ]]; then
        download_with_fallback sample_rootfs.tbz2 "$sample_root_fs_url" "$sample_root_fs_url_fallback"
    fi
else
    download_with_fallback sample_rootfs.tbz2 "$sample_root_fs_url" "$sample_root_fs_url_fallback"
fi

if [ -d Linux_for_Tegra ]; then
    echo "Linux_for_Tegra directory already exists, re-using it"
else
    # Extract BSP and root file system
    echo "Extracting Jetson Linux files. This might take a few minutes..."
    tar -xf jetson_linux.tbz2
    cd "$tmp_dir/Linux_for_Tegra/rootfs/"
    echo "Extracting filesystem. This might take a few minutes..."
    sudo tar -jxpf ../../sample_rootfs.tbz2

    # Apply binaries
    echo "Preparing environment..."
    cd "$tmp_dir/Linux_for_Tegra"
    sudo ./tools/l4t_flash_prerequisites.sh
    sudo ./apply_binaries.sh
fi

# Create a user
echo "Setting hostname $hostname and user $user with password $password. Autologin enabled."
cd "$tmp_dir/Linux_for_Tegra/"
sudo ./tools/l4t_create_default_user.sh --username "$user" --password "$password" --autologin --hostname "$hostname" --accept-license


# Tell user to put device in recovery mode. Print instructions, do not let pass until device is in recovery mode
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
echo "The script will continue automatically once a device in Force Recovery Mode is detected"

# Run lsusb until an entry like "ID 0955:7523 NVIDIA Corp. APX" is detected (exact ID might vary)
while true; do
    if lsusb | grep -q "NVIDIA Corp. APX"; then
        echo "Device in Force Recovery Mode detected!"
        break
    fi
    sleep 1
done

# Flash bootloader to QSPI and rootfs to NVMe.
# Parameter explanation:
# --external-device nvme0n1p1: on which partition of the Jetson device to flash the root file system (first partition of the NVMe drive)
# -c ./tools/kernel_flash/flash_l4t_t234_nvme.xml: path to the partition layout configuration file. There are a few other options in that directory with support for encryption, flashing to other devices (for example SD cards), etc.
# -p "-c ./bootloader/generic/cfg/flash_t234_qspi.xml": path to the partition layout configuration file for the bootloader. There are a few other options in that directory
# --network usb0: Flash through Ethernet protocol through the USB connection
# jetson-orin-nano-devkit: board type, see https://docs.nvidia.com/jetson/archives/r39.2/DeveloperGuide/IN/QuickStart.html#in-quickstart-jetsonmodulesandconfigurations
# external: boot from external device (NVMe)
#
# For more information see Linux_for_Tegra/tools/kernel_flash/README_initrd_flash.txt. 
# It includes some parameter explanations as well as examples of flashing for different purposes (encryption, bulk, different storage layouts, ...)
# You can look at the online docs: https://docs.nvidia.com/jetson/archives/r39.2/DeveloperGuide/SD/FlashingSupport.html#using-initrd-flash-with-orin-nx-and-nano,
# but make sure you are looking for the right version, since the parameters sometimes change
echo "Flashing device..."
sudo ./tools/kernel_flash/l4t_initrd_flash.sh \
    --external-device nvme0n1p1 \
    -c ./tools/kernel_flash/flash_l4t_t234_nvme.xml \
    -p "-c ./bootloader/generic/cfg/flash_t234_qspi.xml" \
    --showlogs \
    --network usb0 \
    jetson-orin-nano-devkit \
    external

echo ""
echo "OS flashing complete. Now you can connect to the Jetson and continue configuration there."
echo ""
