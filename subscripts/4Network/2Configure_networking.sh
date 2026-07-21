#!/bin/bash

set -u

TITLE="Network Config"
FILENAME="/tmp/01-netcfg.yaml"

yesno_def_yes() {
  whiptail --title "$TITLE" --yesno "$1" 0 0
  ret_val=$?

  if [ "$ret_val" -eq 255 ]; then
    exit 1
  elif [ "$ret_val" -eq 0 ]; then
    return 1 # user selected Yes
  elif [ "$ret_val" -eq 1 ]; then
    return 0 # user selected No
  else
    echo "Error state"
    exit 1
  fi
}

input_box() {
  local prompt="$1"
  local default_value="${2:-}"

  local tmp
  tmp=$(whiptail --title "$TITLE" --inputbox "$prompt" 0 0 "$default_value" 3>&1 1>&2 2>&3)

  ret_val=$?

  if [ "$ret_val" -eq 255 ]; then
    exit 1
  elif [ "$ret_val" -eq 1 ]; then
    exit 1
  elif [ "$ret_val" -eq 0 ]; then
    printf '%s\n' "$tmp"
    return 0
  else
    echo "Error state"
    exit 1
  fi
}

msgbox() {
  whiptail --title "$TITLE" --msgbox "$1" 0 0
}

enable_systemd_networkd() {
  sudo systemctl unmask systemd-networkd systemd-resolved
  sudo systemctl enable --now systemd-networkd systemd-resolved
}

disable_network_manager() {
  sudo systemctl disable --now NetworkManager NetworkManager-wait-online NetworkManager-dispatcher 2>/dev/null || true
  sudo systemctl mask NetworkManager NetworkManager-wait-online NetworkManager-dispatcher 2>/dev/null || true
}

is_wifi_interface() {
  local int="$1"
  [[ "$int" =~ ^wlan[0-9]+$ ]]
}

is_ethernet_interface() {
  local int="$1"
  [[ "$int" =~ ^eth[0-9]+$ ]]
}

get_default_ip_for_interface() {
  local int="$1"

  if is_wifi_interface "$int"; then
    if [[ "${USE_DEFAULTS_FOR:-}" == "F4F" ]]; then
      echo "192.168.12.101"
    else
      echo "192.168.69.101"
    fi
  else
    echo "10.10.20.101"
  fi
}

get_default_gateway_for_interface() {
  local int="$1"

  if is_wifi_interface "$int"; then
    if [[ "${USE_DEFAULTS_FOR:-}" == "F4F" ]]; then
      echo "192.168.12.1"
    else
      echo "192.168.69.1"
    fi
  else
    echo "10.10.20.1"
  fi
}

get_default_gateway_to_internet_for_interface() {
  local int="$1"

  if is_wifi_interface "$int"; then
    echo "yes"
  else
    echo "no"
  fi
}

get_default_ssid() {
  if [[ "${USE_DEFAULTS_FOR:-}" == "F4F" ]]; then
    echo "f4f_robot"
  else
    echo "mrs_ctu"
  fi
}

get_default_wifi_password() {
  echo "mikrokopter"
}

delete_old_netplan_configs() {
  sudo rm -f /etc/netplan/*.yaml
  msgbox "Deleted all yaml files in /etc/netplan/"
}

init_interface_defaults() {
  local int="$1"

  CFG_ENABLED["$int"]="yes"
  CFG_DHCP4["$int"]="yes"
  CFG_ADDRESS["$int"]="$(get_default_ip_for_interface "$int")"
  CFG_PREFIX["$int"]="24"
  CFG_GATEWAY["$int"]="$(get_default_gateway_for_interface "$int")"
  CFG_GATEWAY_TO_INTERNET["$int"]="$(get_default_gateway_to_internet_for_interface "$int")"
  CFG_DNS["$int"]="8.8.8.8"

  if is_wifi_interface "$int"; then
    CFG_TYPE["$int"]="wifi"
    CFG_SSID["$int"]="$(get_default_ssid)"
    CFG_PASSWORD["$int"]="$(get_default_wifi_password)"
  else
    CFG_TYPE["$int"]="ethernet"
    CFG_SSID["$int"]=""
    CFG_PASSWORD["$int"]=""
  fi
}

interface_summary() {
  local int="$1"
  local enabled="${CFG_ENABLED[$int]}"
  local dhcp="${CFG_DHCP4[$int]}"

  if [ "$enabled" != "yes" ]; then
    echo "disabled"
    return
  fi

  if [ "$dhcp" = "yes" ]; then
    echo "DHCP"
  else
    if [ "${CFG_GATEWAY_TO_INTERNET[$int]}" = "yes" ]; then
      echo "static ${CFG_ADDRESS[$int]}/${CFG_PREFIX[$int]}, internet gateway"
    else
      echo "static ${CFG_ADDRESS[$int]}/${CFG_PREFIX[$int]}, no internet gateway"
    fi
  fi
}

edit_interface_menu() {
  local int="$1"

  while true; do
    local type="${CFG_TYPE[$int]}"
    local menu_text

    menu_text="Interface: $int

Current summary:
$(interface_summary "$int")

Choose option to edit:"

    local menu_items=(
      "Enabled" "${CFG_ENABLED[$int]}"
    )

    if [ "${CFG_ENABLED[$int]}" = "yes" ]; then
      menu_items+=(
        "DHCP IPv4" "${CFG_DHCP4[$int]}"
      )

      if [ "${CFG_DHCP4[$int]}" = "no" ]; then
        menu_items+=(
          "Static address" "${CFG_ADDRESS[$int]}"
          "CIDR prefix" "${CFG_PREFIX[$int]}"
          "Gateway to internet" "${CFG_GATEWAY_TO_INTERNET[$int]}"
        )

        if [ "${CFG_GATEWAY_TO_INTERNET[$int]}" = "yes" ]; then
          menu_items+=(
            "Default gateway" "${CFG_GATEWAY[$int]}"
          )
        fi

        menu_items+=(
          "DNS server" "${CFG_DNS[$int]}"
        )
      fi

      if [ "$type" = "wifi" ]; then
        menu_items+=(
          "Wi-Fi SSID" "${CFG_SSID[$int]}"
          "Wi-Fi password" "${CFG_PASSWORD[$int]}"
        )
      fi
    fi

    local choice
    choice=$(whiptail --title "$TITLE - $int" --ok-button "Edit" --cancel-button "Back" --menu "$menu_text" \
      22 70 12 "${menu_items[@]}" 3>&1 1>&2 2>&3)
    ret_val=$?

    case "$ret_val" in
    0)
      ;;
    1)
      # User pressed Back
      return
      ;;

    255)
      # Escape
      return
      ;;

    *)
      echo "Error state"
      exit 1
      ;;
    esac

    case "$choice" in
    "Enabled")
      yesno_def_yes "Enable interface $int?"
      if [ "$?" -eq 1 ]; then
        CFG_ENABLED["$int"]="yes"
      else
        CFG_ENABLED["$int"]="no"
      fi
      ;;

    "DHCP IPv4")
      yesno_def_yes "Use DHCP IPv4 on $int?"
      if [ "$?" -eq 1 ]; then
        CFG_DHCP4["$int"]="yes"
      else
        CFG_DHCP4["$int"]="no"
      fi
      ;;

    "Static address")
      CFG_ADDRESS["$int"]=$(input_box "Enter static IP address for $int:" "${CFG_ADDRESS[$int]}")
      CFG_DHCP4["$int"]="no"
      ;;

    "CIDR prefix")
      CFG_PREFIX["$int"]=$(input_box "Enter CIDR prefix for $int, for example 24:" "${CFG_PREFIX[$int]}")
      CFG_DHCP4["$int"]="no"
      ;;

    "Gateway to internet")
      yesno_def_yes "Should $int use a default gateway to the internet?"
      if [ "$?" -eq 1 ]; then
        CFG_GATEWAY_TO_INTERNET["$int"]="yes"
      else
        CFG_GATEWAY_TO_INTERNET["$int"]="no"
      fi
      CFG_DHCP4["$int"]="no"
      ;;

    "Default gateway")
      CFG_GATEWAY["$int"]=$(input_box "Enter default gateway for $int:" "${CFG_GATEWAY[$int]}")
      CFG_DHCP4["$int"]="no"
      ;;

    "DNS server")
      CFG_DNS["$int"]=$(input_box "Enter DNS server address for $int:" "${CFG_DNS[$int]}")
      ;;

    "Wi-Fi SSID")
      CFG_SSID["$int"]=$(input_box "Enter Wi-Fi SSID for $int:" "${CFG_SSID[$int]}")
      ;;

    "Wi-Fi password")
      CFG_PASSWORD["$int"]=$(input_box "Enter Wi-Fi password for $int:" "${CFG_PASSWORD[$int]}")
      ;;
    esac
  done
}

main_interface_menu() {
  while true; do
    local menu_items=()

    for int in "${INTERFACES[@]}"; do
      menu_items+=("$int" "$(interface_summary "$int")")
    done

    # Blank separator line
    menu_items+=(" " " ")

    menu_items+=("Cleanup" "Delete old netplan configs")
    menu_items+=("Save" "Generate netplan config and continue")

    local choice
    choice=$(whiptail --title "$TITLE" \
      --ok-button "Select" \
      --cancel-button "Cancel" \
      --menu "Select an interface to configure:" \
      24 70 14 \
      "${menu_items[@]}" \
      3>&1 1>&2 2>&3)

    ret_val=$?

    case "$ret_val" in
    0)
      case "$choice" in
      "Save")
        generate_netplan
        return
        ;;
      "Cleanup")
        delete_old_netplan_configs
        ;;

      " ")
        # Blank separator line, ignore
        continue
        ;;

      *)
        edit_interface_menu "$choice"
        ;;
      esac
      ;;
    *)
      echo "Error state"
      exit 1
      ;;
    esac
  done
}

generate_netplan() {
  rm -f -- "$FILENAME"

  {
    echo "network:"
    echo "  version: 2"
    echo "  renderer: networkd"
  } >>"$FILENAME"

  local has_ethernet="no"
  local has_wifi="no"

  for int in "${INTERFACES[@]}"; do
    [ "${CFG_ENABLED[$int]}" = "yes" ] || continue

    if [ "${CFG_TYPE[$int]}" = "ethernet" ]; then
      has_ethernet="yes"
    elif [ "${CFG_TYPE[$int]}" = "wifi" ]; then
      has_wifi="yes"
    fi
  done

  if [ "$has_ethernet" = "yes" ]; then
    echo "  ethernets:" >>"$FILENAME"

    for int in "${INTERFACES[@]}"; do
      [ "${CFG_ENABLED[$int]}" = "yes" ] || continue
      [ "${CFG_TYPE[$int]}" = "ethernet" ] || continue

      {
        echo "    $int:"
        echo "      dhcp4: ${CFG_DHCP4[$int]}"
        echo "      dhcp6: no"
      } >>"$FILENAME"

      if [ "${CFG_DHCP4[$int]}" = "no" ]; then
        {
          echo "      addresses:"
          echo "        - ${CFG_ADDRESS[$int]}/${CFG_PREFIX[$int]}"
        } >>"$FILENAME"

        if [ "${CFG_GATEWAY_TO_INTERNET[$int]}" = "yes" ]; then
          {
            echo "      routes:"
            echo "        - to: default"
            echo "          via: ${CFG_GATEWAY[$int]}"
          } >>"$FILENAME"
        fi

        {
          echo "      nameservers:"
          echo "        addresses:"
          echo "          - ${CFG_DNS[$int]}"
        } >>"$FILENAME"
      fi
    done
  fi

  if [ "$has_wifi" = "yes" ]; then
    echo "  wifis:" >>"$FILENAME"

    for int in "${INTERFACES[@]}"; do
      [ "${CFG_ENABLED[$int]}" = "yes" ] || continue
      [ "${CFG_TYPE[$int]}" = "wifi" ] || continue

      {
        echo "    $int:"
        echo "      dhcp4: ${CFG_DHCP4[$int]}"
        echo "      dhcp6: no"
      } >>"$FILENAME"

      if [ "${CFG_DHCP4[$int]}" = "no" ]; then
        {
          echo "      addresses:"
          echo "        - ${CFG_ADDRESS[$int]}/${CFG_PREFIX[$int]}"
        } >>"$FILENAME"

        if [ "${CFG_GATEWAY_TO_INTERNET[$int]}" = "yes" ]; then
          {
            echo "      routes:"
            echo "        - to: default"
            echo "          via: ${CFG_GATEWAY[$int]}"
          } >>"$FILENAME"
        fi

        {
          echo "      nameservers:"
          echo "        addresses:"
          echo "          - ${CFG_DNS[$int]}"
        } >>"$FILENAME"
      fi

      {
        echo "      access-points:"
        echo "        \"${CFG_SSID[$int]}\":"
        echo "          password: \"${CFG_PASSWORD[$int]}\""
      } >>"$FILENAME"
    done
  fi
}

validate_basic_config() {
  local errors=""

  for int in "${INTERFACES[@]}"; do
    [ "${CFG_ENABLED[$int]}" = "yes" ] || continue

    if [ "${CFG_DHCP4[$int]}" = "no" ]; then
      if [ -z "${CFG_ADDRESS[$int]}" ]; then
        errors="${errors}\n$int: missing static IP address"
      fi

      if [ -z "${CFG_PREFIX[$int]}" ]; then
        errors="${errors}\n$int: missing CIDR prefix"
      fi

      if [ "${CFG_GATEWAY_TO_INTERNET[$int]}" = "yes" ] && [ -z "${CFG_GATEWAY[$int]}" ]; then
        errors="${errors}\n$int: missing gateway"
      fi

      if [ -z "${CFG_DNS[$int]}" ]; then
        errors="${errors}\n$int: missing DNS server"
      fi
    fi

    if [ "${CFG_TYPE[$int]}" = "wifi" ]; then
      if [ -z "${CFG_SSID[$int]}" ]; then
        errors="${errors}\n$int: missing Wi-Fi SSID"
      fi

      if [ -z "${CFG_PASSWORD[$int]}" ]; then
        errors="${errors}\n$int: missing Wi-Fi password"
      fi
    fi
  done

  if [ -n "$errors" ]; then
    msgbox "Configuration errors:$errors"
    return 1
  fi

  return 0
}

install_netplan_if_missing() {
  if ! command -v netplan >/dev/null 2>&1; then
    echo "Netplan not found, installing..."
    sudo apt update && sudo apt install -y netplan.io
  fi
}

detect_interfaces() {
  INTERFACES=()

  while IFS= read -r int; do
    if is_ethernet_interface "$int" || is_wifi_interface "$int"; then
      INTERFACES+=("$int")
    fi
  done < <(ls /sys/class/net)

  if [ "${#INTERFACES[@]}" -eq 0 ]; then
    msgbox "No ethX or wlanX network interfaces found.

Your interfaces may have different names, for example:
enp3s0, ens33, wlp2s0

Run the Network Interface Names Fix first and then restart this script."
    exit 1
  fi
}

copy_and_apply_netplan() {
  echo "Enabling systemd-networkd ..."
  enable_systemd_networkd

  echo "Disabling NetworkManager ..."
  disable_network_manager

  echo "Copying netplan ..."
  sudo cp "$FILENAME" /etc/netplan/01-netcfg.yaml
  sudo chmod 600 /etc/netplan/01-netcfg.yaml

  echo "Generating netplan ..."
  sudo netplan generate

  echo "Applying netplan ..."
  sudo netplan apply

  echo "Done"
}

interactive_mode() {
  detect_interfaces

  declare -gA CFG_TYPE
  declare -gA CFG_ENABLED
  declare -gA CFG_DHCP4
  declare -gA CFG_ADDRESS
  declare -gA CFG_PREFIX
  declare -gA CFG_GATEWAY
  declare -gA CFG_GATEWAY_TO_INTERNET
  declare -gA CFG_DNS
  declare -gA CFG_SSID
  declare -gA CFG_PASSWORD

  for int in "${INTERFACES[@]}"; do
    init_interface_defaults "$int"
  done

  while true; do
    main_interface_menu

    if ! validate_basic_config; then
      continue
    fi

    local netplan_preview
    netplan_preview=$(cat "$FILENAME")

    yesno_def_yes "The following netplan was generated:

$netplan_preview

Save to /etc/netplan/01-netcfg.yaml and apply?"

    if [ "$?" -eq 1 ]; then
      # User selected Yes
      break
    else
      # User selected No, go back to interface selection menu
      continue
    fi
  done
}

non_interactive_mode() {
  if [ "${NETWORKING_DELETE_PREVIOUS_NETPLAN_CONFIGS:-}" = "true" ]; then
    echo "Removing previous netplan configs"
    sudo rm -f /etc/netplan/*.yaml
  else
    echo "Keeping previous netplan configs"
  fi

  network_config="${NETWORKING_NETPLAN_CONFIG:-}"

  if [ -z "$network_config" ]; then
    echo "No network config found in profile."
    echo "Please set NETWORKING_NETPLAN_CONFIG to a valid netplan YAML string."
    exit 1
  fi

  echo "$network_config" >"$FILENAME"
}

main() {
  install_netplan_if_missing

  if [[ "${NON_INTERACTIVE_MODE:-0}" -ne 1 ]]; then
    interactive_mode
  else
    non_interactive_mode
  fi

  copy_and_apply_netplan
  exit 0
}

main "$@"