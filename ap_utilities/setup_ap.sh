#!/bin/bash

CURRENT_NETPLAN_FILE="/etc/netplan/01-netcfg.yaml"
BACKUP_NETPLAN_FILE="/etc/netplan/01-netcfg.yaml.bak"
SERVICE_NAME="ap_startup.service"

# 1. Check if NetworkManager is running
if systemctl is-active --quiet NetworkManager; then
    echo "NetworkManager is running. Please stop it or uninstall it if you want to use netplan + create_ap."
    exit 1
fi

# 2. Check if create_ap is already running
if [ -n "$(sudo create_ap --list-running)" ]; then
    echo "Access Point is already running. Exiting..."
    exit 0
fi

# 3. Ensure the AP systemd service is enabled (so next boot can trigger this automatically)
if ! systemctl is-enabled --quiet "$SERVICE_NAME"; then
    echo "Enabling $SERVICE_NAME so AP starts automatically if desired..."
    sudo systemctl enable "$SERVICE_NAME"
else
    echo "$SERVICE_NAME is already enabled."
fi

# 4. Start haveged (to avoid WPA errors due to low entropy)
if ! systemctl is-active --quiet haveged; then
    echo "Starting haveged service..."
    sudo systemctl start haveged
fi

# 5. If no netplan backup, make one and remove any Wi-Fi stanzas
if [ ! -f "$BACKUP_NETPLAN_FILE" ]; then
    echo "Creating netplan backup and removing Wi-Fi config..."

    if ! sudo cp "$CURRENT_NETPLAN_FILE" "$BACKUP_NETPLAN_FILE"; then
        echo "Error: Failed to create netplan backup. Exiting..."
        exit 1
    fi

    # Insert a warning comment at the top
    if ! sudo sed -i '1i# WARNING: This file was automatically modified for AP mode. Do not manually edit unless AP is disabled.' "$CURRENT_NETPLAN_FILE"; then
        echo "Error: Failed to add warning to netplan configuration."
        exit 1
    fi

    # Remove any existing 'wifis' block from netplan (using yq)
    if ! sudo yq e 'del(.network.wifis)' -i "$CURRENT_NETPLAN_FILE"; then
        echo "Error: Failed to remove wifis section from netplan configuration."
        exit 1
    fi

    # Apply netplan changes so it stops managing wlan0 as a client
    if ! sudo netplan apply; then
        echo "Error: Failed to apply netplan changes."
        exit 1
    fi
else
    echo "Netplan backup already exists. Skipping backup & Wi-Fi removal."
fi

# 6. Detect an available 5GHz channel
echo "Detecting 5 GHz channels..."
CHANNEL=""
iw list | awk '/Band 2:/,/Band [^2]/' \
  | grep -E "^\s*\*.*MHz" \
  | grep -v "no IR" \
  | grep -v "radar detection" \
  | grep -v "disabled" \
  > /tmp/available_5ghz_channels.txt

if [ -s /tmp/available_5ghz_channels.txt ]; then
    while read -r line; do
        CHANNEL=$(echo "$line" | awk -F'[][]' '{print $2}')
        # First valid channel is enough
        break
    done < /tmp/available_5ghz_channels.txt
fi
rm -f /tmp/available_5ghz_channels.txt

# If we didn't find a valid 5GHz channel, fallback to 2.4 GHz channel 1
if [ -z "$CHANNEL" ]; then
    echo "No suitable 5 GHz channel found. Falling back to 2.4 GHz channel 1."
    CHANNEL="1"
    FREQUENCY_BAND="2.4"
else
    FREQUENCY_BAND="5"
fi

# 7. Derive UAV name and AP password
UAV_NAME=$(grep -w '127.0.1.1' /etc/hosts | awk '{print $2}')
if [ -z "$UAV_NAME" ]; then
    UAV_NAME="uav00"
fi
AP_PASSWORD="${UAV_NAME}@f4f"

# 8. Start create_ap (non-virtual, bridging not used, etc.)
echo "Starting Access Point on $FREQUENCY_BAND GHz channel: $CHANNEL"
sudo create_ap --no-virt -n -c "$CHANNEL" --redirect-to-localhost \
     wlan0 "${UAV_NAME}_WIFI" "$AP_PASSWORD"

# Give it a few seconds to come up
sleep 5

# 9. Check if AP actually started
if ! sudo create_ap --list-running | grep -q "wlan0"; then
    # If 5 GHz was attempted, fallback to 2.4
    if [ "$FREQUENCY_BAND" = "5" ]; then
        echo "Failed to start AP on 5 GHz. Retrying on 2.4 GHz..."
        sudo create_ap --stop wlan0 2>/dev/null

        sudo create_ap --no-virt -n --redirect-to-localhost \
             wlan0 "${UAV_NAME}_WIFI" "$AP_PASSWORD"
        sleep 5

        if ! sudo create_ap --list-running | grep -q "wlan0"; then
            echo "Error: Failed to start AP on 2.4 GHz fallback. Exiting..."
            exit 1
        else
            echo "AP successfully started on 2.4 GHz fallback."
        fi
    else
        echo "Error: Failed to start AP even on 2.4 GHz. Exiting..."
        exit 1
    fi
else
    echo "AP successfully started on $FREQUENCY_BAND GHz channel $CHANNEL."
fi

exit 0
