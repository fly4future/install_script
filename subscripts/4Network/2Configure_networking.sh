#!/bin/bash

yesno_def_no() {
  whiptail --title "Network Config" --yesno "$1" --yes-button "No" --no-button "Yes" 0 0
  ret_val=$?

  if [ $ret_val -eq 255 ]; then
    exit 1
  elif [ $ret_val -eq 1 ]; then
    # echo "User hit Yes"
    return 1
  elif [ $ret_val -eq 0 ]; then
    # echo "User hit No"
    return 0
  else
    echo "Error state"
  fi
}

yesno_def_yes() {
  whiptail --title "Network Config" --yesno "$1" 0 0
  ret_val=$?

  if [ $ret_val -eq 255 ]; then
    exit 1
  elif [ $ret_val -eq 0 ]; then
    # echo "User hit Yes"
    return 1
  elif [ $ret_val -eq 1 ]; then
    # echo "User hit No"
    return 0
  else
    echo "Error state"
  fi
}

input_box() {
  tmp=$(whiptail --inputbox "$1" 0 0 "$2" 3>&1 1>&2 2>&3)
  ret_val=$?

  if [ $ret_val -eq 255 ]; then
    # User hit Escape
    exit 1
  elif [ $ret_val -eq 1 ]; then
    # User hit Cancel
    exit 1
  elif [ $ret_val -eq 0 ]; then
    # valid input
    echo $tmp #this will output the string that is user input, and we can capture it into a variable - e.g. foo=$(input_box)
    return 0
  else
    echo "Error state"
    exit 0
  fi
}

error_msg() {
  whiptail --title "Network config" --msgbox "$1" 0 0
}

enable_systemd_networkd() {
  sudo systemctl unmask systemd-networkd systemd-resolved
  sudo systemctl enable --now systemd-networkd systemd-resolved
}

disable_network_manager() {
  sudo systemctl disable --now NetworkManager NetworkManager-wait-online NetworkManager-dispatcher
  sudo systemctl mask NetworkManager NetworkManager-wait-online NetworkManager-dispatcher
}

# If netplan is not installed, install it
if ! command -v netplan &>/dev/null; then
  echo "Netplan not found, installing..."
  sudo apt update && sudo apt install -y netplan.io
fi

yesno_def_yes "This script will configure networking on the device. Systemd-networkd will be used as the backend for netplan and NetworkManager will be disabled. If you're connected via SSH you may lose connection when applying. Do you want to continue?"
ret_val=$?

if [ $ret_val -eq 1 ]; then
  echo "Continuing with network config..."
elif [ $ret_val -eq 0 ]; then
  echo "Aborting network config..."
  exit 0
fi

yesno_def_yes "Delete all previous netplan configs? (Recommended)"
ret_val=$?

if [ $ret_val -eq 1 ]; then
  sudo rm -f /etc/netplan/*.yaml
fi

FILENAME=/tmp/01-netcfg.yaml
rm -f -- "$FILENAME"
touch $FILENAME
echo "network:" >>/tmp/01-netcfg.yaml
echo "  version: 2" >>/tmp/01-netcfg.yaml
echo "  renderer: networkd" >>/tmp/01-netcfg.yaml

interfaces=$(ls /sys/class/net)
eths=$(echo $interfaces | grep -o "\w*eth\w*")
wlans=$(echo $interfaces | grep -o "\w*wlan\w*")

if [ -z "${eths}" ]; then
  error_msg "No Ethernet interfaces found! (looking for eth0, eth1 ...).\nYour Ethernet interfaces may have different names, run the Network Interface Names Fix first.\n\n\n Continuing with Wi-Fi config. "
else
  echo "  ethernets:" >>/tmp/01-netcfg.yaml

  for int in ${eths}; do
    echo "    $int:" >>/tmp/01-netcfg.yaml

    yesno_def_no "Do you want to use DHCP on $int?"
    ret_val=$?

    if [ $ret_val -eq 1 ]; then
      echo "      dhcp4: yes" >>/tmp/01-netcfg.yaml
      echo "      dhcp6: no" >>/tmp/01-netcfg.yaml
    elif [ $ret_val -eq 0 ]; then
      echo "      dhcp4: no" >>/tmp/01-netcfg.yaml
      echo "      dhcp6: no" >>/tmp/01-netcfg.yaml

      address=$(input_box "Enter your static IP address for $int:" "10.10.20.101")
      echo "      addresses: [$address/24]" >>/tmp/01-netcfg.yaml

      gateway=$(input_box "Enter your default gateway address for $int:" "10.10.20.1")
      echo "      routes:" >>/tmp/01-netcfg.yaml
      echo "        - to: default" >>/tmp/01-netcfg.yaml
      echo "          via: $gateway" >>/tmp/01-netcfg.yaml
    fi
  done
fi

if [ -z "${wlans}" ]; then
  error_msg "No Wlan interfaces found! (looking for wlan0, wlan1 ...).\nYour Wlan interfaces may have different names, run the Network Interface Names Fix first.\n\n\n"
else
  echo "  wifis:" >>/tmp/01-netcfg.yaml

  for int in ${wlans}; do
    echo "    $int:" >>/tmp/01-netcfg.yaml

    yesno_def_no "Do you want to use DHCP on $int?"
    dhcp=$?

    if [ $dhcp -eq 1 ]; then
      echo "      dhcp4: yes" >>/tmp/01-netcfg.yaml
      echo "      dhcp6: no" >>/tmp/01-netcfg.yaml
    elif [ $dhcp -eq 0 ]; then
      echo "      dhcp4: no" >>/tmp/01-netcfg.yaml
      echo "      dhcp6: no" >>/tmp/01-netcfg.yaml

      address=""
      if [[ "$1" == "f4f" ]]; then
        address=$(input_box "Enter your static IP address for $int:" "192.168.12.101")
      else
        address=$(input_box "Enter your static IP address for $int:" "192.168.69.101")
      fi
      echo "      addresses: [$address/24]" >>/tmp/01-netcfg.yaml

      gateway=""
      if [[ "$1" == "f4f" ]]; then
        gateway=$(input_box "Enter your default gateway address:" "192.168.12.1")
      else
        gateway=$(input_box "Enter your default gateway address:" "192.168.69.1")
      fi
      echo "      routes:" >>/tmp/01-netcfg.yaml
      echo "        - to: default" >>/tmp/01-netcfg.yaml
      echo "          via: $gateway" >>/tmp/01-netcfg.yaml

    fi

    ap_name=""
    if [[ "$1" == "f4f" ]]; then
      ap_name=$(input_box "Enter your WiFi name (SSID):" "f4f_robot")
    else
      ap_name=$(input_box "Enter your WiFi name (SSID):" "mrs_ctu")
    fi

    echo "      access-points:" >>/tmp/01-netcfg.yaml
    echo "        \"$ap_name\":" >>/tmp/01-netcfg.yaml

    password=$(input_box "Enter your WiFi password:" "mikrokopter")
    echo "          password: \"$password\"" >>/tmp/01-netcfg.yaml

    if [ $dhcp -eq 0 ]; then
      dns=$(input_box "Enter your DNS server address:" "8.8.8.8")
      echo "      nameservers:" >>/tmp/01-netcfg.yaml
      echo "        addresses: [$dns]" >>/tmp/01-netcfg.yaml
    fi

  done
fi

netplan=$(cat /tmp/01-netcfg.yaml)
yesno_def_yes "The following netplan was generated: \n\n $netplan \n\n Copy to /etc/netplan and Apply?"
ret_val=$?

if [ $ret_val -eq 1 ]; then

  # First ensure systemd-networkd is enabled and running
  echo "Enabling systemd-networkd ..."
  enable_systemd_networkd

  # Then apply the netplan config
  echo "Copying netplan ..."
  sudo cp /tmp/01-netcfg.yaml /etc/netplan
  echo "Applying netplan ..."
  sudo netplan generate
  sudo netplan apply

  # Finally, disable network manager
  echo "Disabling NetworkManager ..."
  disable_network_manager

  echo "Done"
  exit 0
fi
exit 1
