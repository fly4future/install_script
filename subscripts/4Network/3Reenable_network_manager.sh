#!/bin/bash

set -euo pipefail

source "$(dirname "$(realpath "$0")")/DISREGARD_common/network_common.sh"

NETCFG_FILE="$NETPLAN_DIR/01-netcfg.yaml"
NM_FILE="$NETPLAN_DIR/01-network-manager-all.yaml"

ret_val=0
whiptail --title "Reenable Network Manager" --yesno "This script will reenable Network Manager and disable systemd-networkd.\n\nThe current netplan configs will be renamed to *.yaml.bak. The config created by the network configuration script ($NETCFG_FILE) is kept and handed over to Network Manager.\n\nAfter the change, press Enter in this terminal within $((REVERT_TIMEOUT - 10)) seconds to keep it, otherwise the previous configuration is restored. If this terminal loses its connection because of the change, log in again, any new login confirms the configuration.\n\n                        Proceed?" --yes-button "No" --no-button "Yes" 24 70 || ret_val=$?

if [ $ret_val -eq 255 ]; then
  exit 1
elif [ $ret_val -ne 1 ]; then
  exit 1
fi

echo "Backing up current network configuration ..."
prepare_revert

for file in "$NETPLAN_DIR"/*.yaml; do
  [ -e "$file" ] || continue
  disable_netplan_config "$file"
done

# Keep the interfaces configured, so that the device stays connected (for example to Wi-Fi) after the switch
if sudo test -e "$REVERT_DIR/netplan/01-netcfg.yaml"; then
  echo "Handing over $NETCFG_FILE to Network Manager"
  sudo sed -E 's/^([[:space:]]*renderer:[[:space:]]*)networkd[[:space:]]*$/\1NetworkManager/' "$REVERT_DIR/netplan/01-netcfg.yaml" | sudo tee "$NETCFG_FILE" >/dev/null
  sudo chmod 600 "$NETCFG_FILE"
fi

printf 'network:\n  version: 2\n  renderer: NetworkManager\n' | sudo tee "$NM_FILE" >/dev/null
sudo chmod 600 "$NM_FILE"

# Check the config before changing anything that could cut the network connection
if ! sudo netplan generate; then
  echo "The netplan config is not valid, restoring the previous config. Nothing was changed."
  restore_netplan_files
  exit 1
fi

schedule_revert

if ! { use_network_manager && sudo netplan apply && hand_over_to_network_manager; }; then
  echo "Switching to Network Manager failed"
  revert_now
  exit 1
fi

confirm_or_revert || exit 1

echo "Network manager enabled"
exit 0
