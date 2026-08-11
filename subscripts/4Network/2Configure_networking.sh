#!/bin/bash

set -uo pipefail

TITLE="Network Config"
FILENAME="/tmp/01-netcfg.yaml"

yesno() {
  whiptail --title "$TITLE" --yesno "$1" 0 0
}

input_box() {
  local prompt="$1"
  local default_value="${2:-}"

  local tmp=$(whiptail --title "$TITLE" --inputbox "$prompt" 0 0 "$default_value" 3>&1 1>&2 2>&3)

  local ret_val=$?

  if [ "$ret_val" -eq 255 ]; then
    exit 1
  elif [ "$ret_val" -eq 1 ]; then
    return 1
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

get_metric_for_interface() {
  local int="$1"

  if is_wifi_interface "$int"; then
    echo "100"
  else
    echo "200"
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
  if yesno "Are you sure you want to delete all *.yaml files in /etc/netplan/?"; then
    sudo rm -f /etc/netplan/*.yaml
    msgbox "Deleted all *.yaml files in /etc/netplan"
  fi
}

get_current_interface_enabled() {
  local int="$1"

  if [[ -r "/sys/class/net/$int/flags" ]]; then
    local flags
    flags=$(<"/sys/class/net/$int/flags")

    if ((flags & 0x1)); then
      echo "yes"
    else
      echo "no"
    fi
  else
    echo "no"
  fi
}

get_current_dhcp4() {
  local int="$1"
  local address_flags

  # Addresses obtained by DHCP are normally marked "dynamic" by the kernel.
  address_flags=$(ip -o -4 address show dev "$int" scope global 2>/dev/null || true)

  if [[ "$address_flags" == *" dynamic "* ]]; then
    echo "yes"
  elif [[ -n "$address_flags" ]]; then
    echo "no"
  else
    # Preserve original behavior when no current information exists.
    echo "yes"
  fi
}

get_current_address_and_prefix() {
  local int="$1"
  local address_with_prefix

  address_with_prefix=$(
    ip -o -4 address show dev "$int" scope global 2>/dev/null |
      awk 'NR == 1 { print $4 }'
  )

  printf '%s\n' "$address_with_prefix"
}

get_current_gateway() {
  local int="$1"

  ip -4 route show default dev "$int" 2>/dev/null |
    awk '
      NR == 1 {
        for (i = 1; i <= NF; i++) {
          if ($i == "via" && (i + 1) <= NF) {
            print $(i + 1)
            exit
          }
        }
      }
    '
}

get_current_metric() {
  local int="$1"

  ip -4 route show default dev "$int" 2>/dev/null |
    awk '
      NR == 1 {
        for (i = 1; i <= NF; i++) {
          if ($i == "metric" && (i + 1) <= NF) {
            print $(i + 1)
            exit
          }
        }
      }
    '
}

get_current_dns() {
  local int="$1"
  local dns=""

  if command -v resolvectl >/dev/null 2>&1; then
    dns=$(
      resolvectl dns "$int" 2>/dev/null |
        awk -F: '
          NR == 1 {
            sub(/^[[:space:]]+/, "", $2)
            split($2, addresses, /[[:space:]]+/)
            print addresses[1]
          }
        '
    )
  fi

  printf '%s\n' "$dns"
}

get_current_ssid() {
  local int="$1"
  local ssid=""

  if command -v iwgetid >/dev/null 2>&1; then
    ssid=$(iwgetid "$int" --raw 2>/dev/null || true)
  fi

  if [[ -z "$ssid" ]] && command -v iw >/dev/null 2>&1; then
    ssid=$(
      iw dev "$int" link 2>/dev/null |
        sed -n 's/^[[:space:]]*SSID: //p' |
        head -n 1
    )
  fi

  printf '%s\n' "$ssid"
}

init_interface_defaults() {
  local int="$1"
  local current_address_with_prefix=""
  local current_address=""
  local current_prefix=""
  local current_gateway=""
  local current_metric=""
  local current_dns=""
  local current_ssid=""
  local current_password=""

  # Initialize enabled state and DHCP settings using existing helpers
  CFG_ENABLED["$int"]="$(get_current_interface_enabled "$int")"
  CFG_DHCP4["$int"]="$(get_current_dhcp4 "$int")"

  # Retrieve current IP and prefix
  current_address_with_prefix="$(get_current_address_and_prefix "$int")"

  if [[ "$current_address_with_prefix" == */* ]]; then
    current_address="${current_address_with_prefix%/*}"
    current_prefix="${current_address_with_prefix#*/}"
  fi

  current_gateway="$(get_current_gateway "$int")"
  current_metric="$(get_current_metric "$int")"
  current_dns="$(get_current_dns "$int")"

  CFG_ADDRESS["$int"]="${current_address:-$(get_default_ip_for_interface "$int")}"
  CFG_PREFIX["$int"]="${current_prefix:-24}"

  if [[ -n "$current_gateway" ]]; then
    CFG_GATEWAY_TO_INTERNET["$int"]="yes"
    CFG_GATEWAY["$int"]="$current_gateway"
  else
    CFG_GATEWAY_TO_INTERNET["$int"]="no"
    CFG_GATEWAY["$int"]="$(get_default_gateway_for_interface "$int")"
  fi

  CFG_METRIC["$int"]="${current_metric:-$(get_metric_for_interface "$int")}"
  CFG_DNS["$int"]="${current_dns:-8.8.8.8}"

  if is_wifi_interface "$int"; then
    CFG_TYPE["$int"]="wifi"

    current_ssid="$(get_current_ssid "$int")"
    CFG_SSID["$int"]="${current_ssid:-$(get_default_ssid)}"

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
      echo "static ${CFG_ADDRESS[$int]}/${CFG_PREFIX[$int]} metric ${CFG_METRIC[$int]}"
    else
      echo "static ${CFG_ADDRESS[$int]}/${CFG_PREFIX[$int]}"
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
          menu_items+=("Default gateway" "${CFG_GATEWAY[$int]}")
          menu_items+=("Metric" "${CFG_METRIC[$int]}")
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
    local ret_val=$?

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
      if yesno "Enable interface $int?"; then
        CFG_ENABLED["$int"]="yes"
      else
        CFG_ENABLED["$int"]="no"
      fi
      ;;

    "DHCP IPv4")
      if yesno "Use DHCP IPv4 on $int?"; then
        CFG_DHCP4["$int"]="yes"
      else
        CFG_DHCP4["$int"]="no"
      fi
      ;;

    "Static address")
      local tmp=$(input_box "Enter static IP address for $int:" "${CFG_ADDRESS[$int]}") || continue
      CFG_ADDRESS["$int"]="$tmp"
      ;;

    "CIDR prefix")
      local tmp=$(input_box "Enter CIDR prefix for $int, for example 24:" "${CFG_PREFIX[$int]}") || continue
      CFG_PREFIX["$int"]="$tmp"
      ;;

    "Gateway to internet")
      if yesno "Should $int be a gateway to the internet?"; then
        CFG_GATEWAY_TO_INTERNET["$int"]="yes"
      else
        CFG_GATEWAY_TO_INTERNET["$int"]="no"
      fi
      ;;

    "Default gateway")
      local tmp=$(input_box "Enter default gateway for $int:" "${CFG_GATEWAY[$int]}") || continue
      CFG_GATEWAY["$int"]="$tmp"
      ;;

    "Metric")
      local tmp=$(input_box "Enter metric for $int. Only the active gateway with the lowest metric will be used for internet access:" "${CFG_METRIC[$int]}") || continue
      CFG_METRIC["$int"]="$tmp"
      ;;

    "DNS server")
      local tmp=$(input_box "Enter DNS server address for $int:" "${CFG_DNS[$int]}") || continue
      CFG_DNS["$int"]="$tmp"
      ;;

    "Wi-Fi SSID")
      local tmp=$(input_box "Enter Wi-Fi SSID for $int:" "${CFG_SSID[$int]}") || continue
      CFG_SSID["$int"]="$tmp"
      ;;

    "Wi-Fi password")
      local tmp=$(input_box "Enter Wi-Fi password for $int:" "${CFG_PASSWORD[$int]}") || continue
      CFG_PASSWORD["$int"]="$tmp"
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

    local ret_val=$?

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
    1 | 255)
      exit 0
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
            echo "          metric: ${CFG_METRIC[$int]}"
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
            echo "          metric: ${CFG_METRIC[$int]}"
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

      if [ "${CFG_GATEWAY_TO_INTERNET[$int]}" = "yes" ] && [ -z "${CFG_METRIC[$int]}" ]; then
        errors="${errors}\n$int: missing metric"
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
    sudo apt-get update && sudo apt-get install -y netplan.io
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
  declare -gA CFG_GATEWAY_TO_INTERNET
  declare -gA CFG_GATEWAY
  declare -gA CFG_METRIC
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

    if yesno "The following netplan was generated:

$netplan_preview

Save to /etc/netplan/01-netcfg.yaml and apply?"; then
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
