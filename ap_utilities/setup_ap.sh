#!/bin/bash

# Define constants and paths
AP_FLAG_FILE="/var/run/ap_enabled"
CURRENT_NETPLAN_FILE="/etc/netplan/01-netcfg.yaml"
BACKUP_NETPLAN_FILE="/etc/netplan/01-netcfg.yaml.bak"
SERVICE_NAME="ap_startup.service"

# Detect available frequency band and suitable channel
echo "Detecting available frequency bands and suitable channels..."

FREQUENCY_BAND=""
CHANNEL=""

# Extract available 5GHz channels without "no IR" and without "radar detection"
iw list | awk '/Band 2:/,/Band [^2]/' | grep -E "^\s*\*.*MHz" | grep -v "no IR" | grep -v "radar detection" > /tmp/available_5ghz_channels.txt

if [ -s /tmp/available_5ghz_channels.txt ]; then
    # If there are available 5GHz channels, pick the first one
    while read -r line; do
        # Extract the channel number from the frequency line
        CHANNEL=$(echo "$line" | awk -F'[][]' '{print $2}')
        FREQUENCY_BAND="5"
        echo "Using 5GHz channel: $CHANNEL"
        break
    done < /tmp/available_5ghz_channels.txt
fi

# Cleanup temporary file
rm -f /tmp/available_5ghz_channels.txt

# If no suitable 5GHz channel is available, fallback to 2.4GHz band
if [ -z "$CHANNEL" ]; then
    echo "No suitable 5GHz channel found. Falling back to 2.4GHz band."
    FREQUENCY_BAND="2.4"
    CHANNEL="1"  # Default to channel 1 for 2.4GHz
fi

# Get UAV_NAME from /etc/hosts associated with 127.0.1.1
UAV_NAME=$(grep -w '127.0.1.1' /etc/hosts | awk '{print $2}')
if [ -z "$UAV_NAME" ]; then
    UAV_NAME="uav00"
fi

# Define the AP password
AP_PASSWORD="${UAV_NAME}@F4F2024"

# Check if this script is being triggered on boot or by the user
if [ "$1" == "boot" ]; then
    echo "System boot detected. Managing AP state..."

    if [ -f "$AP_FLAG_FILE" ]; then
        echo "AP was previously enabled. Starting AP on boot..."
        # Start the access point using create_ap
        echo "Starting Access Point..."
        sudo create_ap --no-virt -n -c "$CHANNEL" --freq-band "$FREQUENCY_BAND" --redirect-to-localhost wlan0 "${UAV_NAME}_WIFI" "$AP_PASSWORD"
    else
        # Restore the original netplan configuration if AP was not enabled
        if [ -f "$BACKUP_NETPLAN_FILE" ]; then
            echo "Restoring original netplan configuration..."
            if ! sudo cp "$BACKUP_NETPLAN_FILE" "$CURRENT_NETPLAN_FILE"; then
                echo "Error: Failed to restore netplan configuration."
                exit 1
            fi
            sudo netplan apply
        else
            echo "Backup netplan configuration not found. Cannot restore network settings."
        fi
    fi

    exit 0
fi

# Normal scenario: User triggers AP setup (e.g., via power button)

# Check if the ap0 interface is already up
if ip a show ap0 up > /dev/null 2>&1; then
    echo "Access point ap0 is already running."
    exit 0
fi

# Start haveged service to avoid low entropy issues
if ! systemctl is-active --quiet haveged; then
    echo "Starting haveged service to avoid low entropy issues..."
    sudo systemctl start haveged
fi

# Backup netplan configuration if not already backed up
if [ ! -f "$BACKUP_NETPLAN_FILE" ]; then
    echo "Backing up netplan configuration..."
    if ! sudo cp "$CURRENT_NETPLAN_FILE" "$BACKUP_NETPLAN_FILE"; then
        echo "Error: Failed to back up netplan configuration file."
        exit 1
    fi
else
    echo "Netplan configuration backup already exists."
fi

# Add warning comment to the netplan configuration file
echo "Adding warning comment to netplan configuration..."
if ! sudo sed -i '1i# WARNING: Do not modify this file directly unless the AP has been disabled by running kill_ap.sh or configure a new netplan config file properly by running configure_netplan_and_kill_ap.sh' "$CURRENT_NETPLAN_FILE"; then
    echo "Error: Failed to add warning to netplan configuration."
    exit 1
fi

# Remove the 'wifis' section from the netplan configuration using yq
echo "Removing the 'wifis' section using yq..."
if ! sudo yq e 'del(.network.wifis)' -i "$CURRENT_NETPLAN_FILE"; then
    echo "Error: Failed to remove wifis section from netplan configuration."
    exit 1
fi

# Apply netplan changes
echo "Applying modified netplan configuration..."
if ! sudo netplan apply; then
    echo "Error: Failed to apply netplan changes."
    exit 1
fi

# Create the flag file to indicate AP is enabled
echo "Creating AP enabled flag file..."
sudo touch "$AP_FLAG_FILE"

# Enable and start the AP service to ensure it runs on boot in the future
echo "Enabling AP startup service for future boots..."
sudo systemctl enable "$SERVICE_NAME"

# Start the AP service to ensure it's running in the current session
echo "Starting AP startup service..."
sudo systemctl start "$SERVICE_NAME"

# Start the access point using create_ap
echo "Starting Access Point..."
sudo create_ap --no-virt -n -c "$CHANNEL" --freq-band "$FREQUENCY_BAND" --redirect-to-localhost wlan0 "${UAV_NAME}_WIFI" "$AP_PASSWORD"
