#!/bin/bash

set -euo pipefail

source "$(dirname "$(realpath "$0")")/DISREGARD_common/network_common.sh"

NETCFG_FILE="$NETPLAN_DIR/01-netcfg.yaml"
NM_FILE="$NETPLAN_DIR/01-network-manager-all.yaml"

ret_val=0
whiptail --title "Reenable Network Manager" --yesno "This script will reenable Network Manager and disable systemd-networkd.\n\nThe current netplan configs will be renamed to *.yaml.bak. The config created by the network configuration script ($NETCFG_FILE) is kept and handed over to Network Manager.\n\nIf you are connected through SSH, you might lose connection.\n\n                        Proceed?" --yes-button "No" --no-button "Yes" 20 70 || ret_val=$?

if [ $ret_val -eq 255 ]; then
  exit 1
elif [ $ret_val -eq 1 ]; then

  sudo systemctl unmask NetworkManager NetworkManager-wait-online NetworkManager-dispatcher
  sudo systemctl enable --now NetworkManager NetworkManager-wait-online NetworkManager-dispatcher

  sudo systemctl disable --now systemd-networkd.socket systemd-networkd
  sudo systemctl mask systemd-networkd.socket systemd-networkd
  sudo systemctl unmask systemd-resolved
  sudo systemctl enable --now systemd-resolved

  netcfg=$(sudo cat "$NETCFG_FILE" 2>/dev/null || true)

  for file in "$NETPLAN_DIR"/*.yaml; do
    [ -e "$file" ] || continue
    disable_netplan_config "$file"
  done

  # Keep the interfaces configured, so that the device stays connected (for example to Wi-Fi) after the switch
  if [ -n "$netcfg" ]; then
    echo "Handing over $NETCFG_FILE to Network Manager"
    echo "$netcfg" | sed -E 's/^([[:space:]]*renderer:[[:space:]]*)networkd[[:space:]]*$/\1NetworkManager/' | sudo tee "$NETCFG_FILE" >/dev/null
    sudo chmod 600 "$NETCFG_FILE"
  fi

  printf 'network:\n  version: 2\n  renderer: NetworkManager\n' | sudo tee "$NM_FILE" >/dev/null
  sudo chmod 600 "$NM_FILE"

  sudo netplan generate
  sudo netplan apply

  # netplan does not clean up after the networkd config. The leftover udev rules mark the interfaces as unmanaged by NetworkManager
  # and the netplan wpa_supplicant keeps running, so remove them and let NetworkManager pick up the interfaces.
  sudo rm -f /run/udev/rules.d/90-netplan.rules
  sudo systemctl stop 'netplan-wpa-*.service'
  sudo udevadm control --reload
  sudo udevadm trigger --action=change --subsystem-match=net
  sudo udevadm settle
  sudo systemctl restart NetworkManager

  echo "Network manager enabled"
  exit 0
else
  exit 1
fi

