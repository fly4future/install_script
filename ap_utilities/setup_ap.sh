#!/bin/bash

# Define constants and paths
CURRENT_NETPLAN_FILE="/etc/netplan/01-netcfg.yaml"
BACKUP_NETPLAN_FILE="/etc/netplan/01-netcfg.yaml.bak"
SERVICE_NAME="ap_startup.service"

# Check if Network Manager is running
if systemctl is-active --quiet NetworkManager; then
    echo "NetworkManager is running. Please stop NetworkManager and use Netplan instead."
    exit 1
fi

# Check if any create_ap process is already running
if [ -n "$(sudo create_ap --list-running)" ]; then
    echo "Access Point is already running. Exiting..."
    exit 0
fi

if ! systemctl is-enabled --quiet "$SERVICE_NAME"; then
    echo "AP service is not enabled. Enabling it..."
    sudo systemctl enable "$SERVICE_NAME"
else
    echo "AP service is already enabled."
fi

# Start haveged service to avoid low entropy issues
if ! systemctl is-active --quiet haveged; then
    echo "Starting haveged service to avoid low entropy issues..."
    sudo systemctl start haveged
fi

# Detect available frequency band and suitable channel
echo "Detecting available frequency bands and suitable channels..."

FREQUENCY_BAND=""
CHANNEL=""

# Extract available 5GHz channels without "no IR", "radar detection", or "disabled"
iw list | awk '/Band 2:/,/Band [^2]/' | grep -E "^\s*\*.*MHz" | grep -v "no IR" | grep -v "radar detection" | grep -v "disabled" > /tmp/available_5ghz_channels.txt

if [ -s /tmp/available_5ghz_channels.txt ]; then
    while read -r line; do
        CHANNEL=$(echo "$line" | awk -F'[][]' '{print $2}')
        FREQUENCY_BAND="5"
        echo "Using 5GHz channel: $CHANNEL"
        break
    done < /tmp/available_5ghz_channels.txt
fi

rm -f /tmp/available_5ghz_channels.txt

if [ -z "$CHANNEL" ]; then
    echo "No suitable 5GHz channel found. Falling back to 2.4GHz band."
    FREQUENCY_BAND="2.4"
    CHANNEL="1"  # Default to channel 1 for 2.4GHz
fi

UAV_NAME=$(grep -w '127.0.1.1' /etc/hosts | awk '{print $2}')
if [ -z "$UAV_NAME" ]; then
    UAV_NAME="uav00"
fi

AP_PASSWORD="${UAV_NAME}@f4f"

# Check if this script is being triggered on boot or by the user
if [ "$1" == "boot" ]; then
    echo "System boot detected. Starting Access Point..."

    echo "Starting Access Point with 5GHz channel first..."
    sudo create_ap --no-virt -n -c "$CHANNEL" --redirect-to-localhost wlan0 "${UAV_NAME}_WIFI" "$AP_PASSWORD" --daemon

    sleep 5
    if ! sudo create_ap --list-running | grep -q "wlan0"; then
        echo "Failed to start Access Point on 5GHz channel. Cleaning up and retrying on 2.4GHz..."
        sudo create_ap --stop wlan0

        sudo create_ap --no-virt -n --redirect-to-localhost wlan0 "${UAV_NAME}_WIFI" "$AP_PASSWORD" --daemon

        sleep 5
        if ! sudo create_ap --list-running | grep -q "wlan0"; then
            echo "Error: Failed to start Access Point on 2.4GHz fallback. Exiting..."
            exit 1
        else
            echo "Successfully started Access Point on 2.4GHz channel."
        fi
    else
        echo "Successfully started Access Point on 5GHz channel."
    fi
    exit 0
fi

# Normal scenario: User triggers AP setup
if [ ! -f "$BACKUP_NETPLAN_FILE" ]; then
    echo "Backing up netplan configuration..."
    if ! sudo cp "$CURRENT_NETPLAN_FILE" "$BACKUP_NETPLAN_FILE"; then
        echo "Error: Failed to back up netplan configuration file."
        exit 1
    fi
else
    echo "Netplan configuration backup already exists."
fi

echo "Adding warning comment to netplan configuration..."
if ! sudo sed -i '1i# WARNING: Do not modify this file directly unless the AP has been disabled.' "$CURRENT_NETPLAN_FILE"; then
    echo "Error: Failed to add warning to netplan configuration."
    exit 1
fi

if ! sudo yq e 'del(.network.wifis)' -i "$CURRENT_NETPLAN_FILE"; then
    echo "Error: Failed to remove wifis section from netplan configuration."
    exit 1
fi

if ! sudo netplan apply; then
    echo "Error: Failed to apply netplan changes."
    exit 1
fi

echo "Starting Access Point with 5GHz channel first..."
sudo create_ap --no-virt -n -c "$CHANNEL" --redirect-to-localhost wlan0 "${UAV_NAME}_WIFI" "$AP_PASSWORD" --daemon

sleep 5
if ! sudo create_ap --list-running | grep -q "wlan0"; then
    echo "Failed to start Access Point on 5GHz channel. Cleaning up and retrying on 2.4GHz..."
    sudo create_ap --stop wlan0

    sudo create_ap --no-virt -n --redirect-to-localhost wlan0 "${UAV_NAME}_WIFI" "$AP_PASSWORD" --daemon

    sleep 5
    if ! sudo create_ap --list-running | grep -q "wlan0"; then
        echo "Error: Failed to start Access Point on 2.4GHz fallback. Exiting..."
        exit 1
    else
        echo "Successfully started Access Point on 2.4GHz channel."
    fi
else
    echo "Successfully started Access Point on 5GHz channel."
fi
