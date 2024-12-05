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
AP_PASSWORD="${UAV_NAME}f4f"

# Check if this script is being triggered on boot or by the user
if [ "$1" == "boot" ]; then
    echo "System boot detected. Starting Access Point..."

    # Start the access point with a retry mechanism
    echo "Starting Access Point with 5GHz channel first..."
    sudo create_ap --no-virt -n --freq-band "$FREQUENCY_BAND" -c "$CHANNEL" --redirect-to-localhost wlan0 "${UAV_NAME}_WIFI" "$AP_PASSWORD"

    # Check if create_ap failed
    if [ $? -ne 0 ]; then
        echo "Failed to start Access Point on 5GHz channel. Falling back to 2.4GHz..."

        # Fallback to 2.4GHz
        FREQUENCY_BAND="2.4"
        CHANNEL="1"  # Default to channel 1 for 2.4GHz

        # Retry to start the access point using 2.4GHz band
        sudo create_ap --no-virt -n --freq-band "$FREQUENCY_BAND" -c "$CHANNEL" --redirect-to-localhost wlan0 "${UAV_NAME}_WIFI" "$AP_PASSWORD"

        # Check if the fallback also fails
        if [ $? -ne 0 ]; then
            echo "Error: Failed to start Access Point with 2.4GHz fallback as well. Exiting..."
            exit 1
        else
            echo "Successfully started Access Point on 2.4GHz channel."
        fi
    else
        echo "Successfully started Access Point on 5GHz channel."
    fi
    exit 0
fi

# Normal scenario: User triggers AP setup (e.g., via power button, via directly calling setup_ap.sh)

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

# Start the access point with a retry mechanism
echo "Starting Access Point with 5GHz channel first..."
sudo create_ap --no-virt -n --freq-band "$FREQUENCY_BAND" -c "$CHANNEL" --redirect-to-localhost wlan0 "${UAV_NAME}_WIFI" "$AP_PASSWORD" --daemon

# Check if create_ap failed
if [ $? -ne 0 ]; then
    echo "Failed to start Access Point on 5GHz channel. Falling back to 2.4GHz..."

    # Fallback to 2.4GHz
    FREQUENCY_BAND="2.4"
    CHANNEL="1"  # Default to channel 1 for 2.4GHz

    # Retry to start the access point using 2.4GHz band
    sudo create_ap --no-virt -n --freq-band "$FREQUENCY_BAND" -c "$CHANNEL" --redirect-to-localhost wlan0 "${UAV_NAME}_WIFI" "$AP_PASSWORD" --daemon

    # Check if the fallback also fails
    if [ $? -ne 0 ]; then
        echo "Error: Failed to start Access Point with 2.4GHz fallback as well. Exiting..."
        exit 1
    else
        echo "Successfully started Access Point on 2.4GHz channel."
    fi
else
    echo "Successfully started Access Point on 5GHz channel."
fi
