#!/bin/bash


# Check if the ap0 interface is up
if ip a show ap0 up > /dev/null 2>&1; then
    echo "Access point ap0 is already running."
    exit 0
fi

# Define your sudo password
SUDO_PASSWORD="f4f"

# Define the netplan configuration files
CURRENT_NETPLAN_FILE="/etc/netplan/01-netcfg.yaml"
BACKUP_NETPLAN_FILE="/etc/netplan/01-netcfg.yaml.orig"
AP_NETPLAN_FILE="/etc/netplan/01-netcfg.yaml.ap"

# Check if the current netplan file exists
if [ -f "$CURRENT_NETPLAN_FILE" ]; then
    # Rename the current netplan configuration file
    echo "$SUDO_PASSWORD" | sudo -S mv "$CURRENT_NETPLAN_FILE" "$BACKUP_NETPLAN_FILE"
else
    echo "Current netplan configuration file not found: $CURRENT_NETPLAN_FILE. Continuing..."
fi

# Check if the AP netplan configuration file exists
if [ ! -f "$AP_NETPLAN_FILE" ]; then
    # Create the AP netplan configuration file
    echo "AP netplan configuration file not found: $AP_NETPLAN_FILE"
    echo "Creating AP netplan configuration file..."

    echo "$SUDO_PASSWORD" | sudo -S tee "$AP_NETPLAN_FILE" > /dev/null <<EOL
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: yes
EOL
fi

# Rename the AP netplan configuration file to the current one
echo "$SUDO_PASSWORD" | sudo -S mv "$AP_NETPLAN_FILE" "$CURRENT_NETPLAN_FILE"

# Apply the new netplan configuration
echo "$SUDO_PASSWORD" | sudo -S netplan apply

# Use UAV_NAME environment variable or default to "uav00"
UAV_NAME="${UAV_NAME:-uav00}"

# Create the access point using create_ap
echo "$SUDO_PASSWORD" | sudo -S create_ap -n wlan0 "${UAV_NAME}_WIFI" password
