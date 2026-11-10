#!/bin/bash

set -uo pipefail

source "$(dirname "$(realpath "$0")")/DISREGARD_common/network_common.sh"

TITLE="Network Config"
TARGET_FILE="$NETPLAN_DIR/01-netcfg.yaml"

# The generated config contains the Wi-Fi password, so keep it in a file only readable by the user
FILENAME=$(mktemp)
trap 'rm -f "$FILENAME"' EXIT

yesno() {
  whiptail --title "$TITLE" --yesno "$1" 0 0
}

input_box() {
  local prompt="$1"
  local default_value="${2:-}"

  local tmp
  local ret_val=0
  tmp=$(whiptail --title "$TITLE" --inputbox "$prompt" 0 0 "$default_value" 3>&1 1>&2 2>&3) || ret_val=$?

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

# We don't need to wait for interfaces without a route to the internet when booting
is_optional_interface() {
  local int="$1"
  [ "${CFG_DHCP4[$int]}" = "no" ] && [ "${CFG_GATEWAY_TO_INTERNET[$int]}" = "no" ]
}

# Renames all netplan configs except the new one to *.yaml.bak.
# Other configs would be merged with the new one and could override it, for example the renderer from a NetworkManager config.
disable_other_netplan_configs() {
  local file

  for file in "$NETPLAN_DIR"/*.yaml; do
    [ -e "$file" ] || continue
    [ "$file" = "$TARGET_FILE" ] && continue

    disable_netplan_config "$file"
  done
}

# Prints the configured settings of an interface from netplan as key=value lines
read_netplan_config() {
  local int="$1"
  local section="ethernets"

  if is_wifi_interface "$int"; then
    section="wifis"
  fi

  # netplan get prints the config normalized, with top level keys at the start of the line
  sudo netplan get "network.$section.$int" 2>/dev/null | awk '
    function unquote(s) {
      gsub(/^[[:space:]]*"?|"?[[:space:]]*$/, "", s)
      return s
    }

    function print_default_route() {
      if ((route_to == "default" || route_to == "0.0.0.0/0") && route_via != "" && !has_gateway) {
        print "gateway=" route_via
        print "metric=" route_metric
        has_gateway = 1
      }
      route_to = route_via = route_metric = ""
    }

    $0 == "null" { exit }
    NR == 1 { print "enabled=yes" }

    /^[^ -]/ {
      if (block == "routes") print_default_route()
      block = $1
      sub(/:$/, "", block)
    }

    block == "dhcp4" { print "dhcp4=" ($2 == "true" ? "yes" : "no") }
    block == "gateway4" && !has_gateway { print "gateway=" unquote($2); has_gateway = 1 }
    block == "addresses" && /^- / && !has_address { print "address=" unquote($2); has_address = 1 }

    block == "routes" {
      line = $0
      if (sub(/^- /, "", line)) print_default_route()
      split(line, kv, ":")
      key = unquote(kv[1])
      value = unquote(substr(line, index(line, ":") + 1))
      if (key == "to") route_to = value
      if (key == "via") route_via = value
      if (key == "metric") route_metric = value
    }

    block == "nameservers" && /^  [a-z]/ { nameservers_key = $1 }
    block == "nameservers" && nameservers_key == "addresses:" && /^  - / && !has_dns { print "dns=" unquote($2); has_dns = 1 }

    block == "access-points" && /^  [^ ]/ && !has_ssid { ssid = $0; sub(/:[[:space:]]*$/, "", ssid); print "ssid=" unquote(ssid); has_ssid = 1 }
    block == "access-points" && /^ +password:/ && !has_password { print "password=" unquote(substr($0, index($0, ":") + 1)); has_password = 1 }

    END { if (block == "routes") print_default_route() }
  '
}

# Prints the configured settings of an interface from NetworkManager as key=value lines
read_network_manager_config() {
  local int="$1"
  local uuid
  local candidate

  # The active connection, or the first one bound to the interface, for example when the cable is unplugged
  uuid=$(nmcli -g GENERAL.CON-UUID device show "$int" 2>/dev/null)

  if [ -z "$uuid" ]; then
    while read -r candidate; do
      if [ "$(nmcli -g connection.interface-name connection show "$candidate" 2>/dev/null)" = "$int" ]; then
        uuid="$candidate"
        break
      fi
    done < <(nmcli -g UUID connection show 2>/dev/null)
  fi

  [ -n "$uuid" ] || return 0

  local method address gateway metric dns
  {
    read -r method
    read -r address
    read -r gateway
    read -r metric
    read -r dns
  } < <(nmcli -g ipv4.method,ipv4.addresses,ipv4.gateway,ipv4.route-metric,ipv4.dns connection show "$uuid")

  case "$method" in
  auto) echo "dhcp4=yes" ;;
  manual) echo "dhcp4=no" ;;
  *) return 0 ;;
  esac

  echo "enabled=yes"
  echo "address=${address%%,*}"
  echo "dns=${dns%%,*}"

  if [ -n "$gateway" ]; then
    echo "gateway=$gateway"
    [ "$metric" = "-1" ] || echo "metric=$metric"
  fi

  if is_wifi_interface "$int"; then
    echo "ssid=$(nmcli -g 802-11-wireless.ssid connection show "$uuid")"
    echo "password=$(sudo nmcli -s -g 802-11-wireless-security.psk connection show "$uuid" 2>/dev/null)"
  fi
}

# Prints "up" if the interface has a cable plugged in or is connected to a Wi-Fi network, "down" otherwise
get_link_state() {
  local int="$1"

  if [ "$(cat "/sys/class/net/$int/operstate" 2>/dev/null)" = "up" ]; then
    echo "up"
  else
    echo "down"
  fi
}

# Prints the address the interface currently has from DHCP, if any
get_dhcp_address() {
  local int="$1"

  ip -o -4 address show dev "$int" scope global dynamic 2>/dev/null | awk 'NR == 1 { print $4 }'
}

init_interface_defaults() {
  local int="$1"
  local key value

  local enabled="no" dhcp4="yes" address="" gateway="" metric="" dns="" ssid="" password=""

  # The current config, not the current addresses, because an interface without a cable has no address whether it uses DHCP or not
  while IFS="=" read -r key value; do
    case "$key" in
    enabled) enabled="$value" ;;
    dhcp4) dhcp4="$value" ;;
    address) address="$value" ;;
    gateway) gateway="$value" ;;
    metric) metric="$value" ;;
    dns) dns="$value" ;;
    ssid) ssid="$value" ;;
    password) password="$value" ;;
    esac
  done < <(
    if [ "$CURRENT_RENDERER" = "NetworkManager" ]; then
      read_network_manager_config "$int"
    else
      read_netplan_config "$int"
    fi
  )

  CFG_ENABLED["$int"]="$enabled"
  CFG_DHCP4["$int"]="$dhcp4"

  if [[ "$address" == */* ]]; then
    CFG_ADDRESS["$int"]="${address%/*}"
    CFG_PREFIX["$int"]="${address#*/}"
  else
    CFG_ADDRESS["$int"]="$(get_default_ip_for_interface "$int")"
    CFG_PREFIX["$int"]="24"
  fi

  if [ -n "$gateway" ]; then
    CFG_GATEWAY_TO_INTERNET["$int"]="yes"
    CFG_GATEWAY["$int"]="$gateway"
  else
    CFG_GATEWAY_TO_INTERNET["$int"]="no"
    CFG_GATEWAY["$int"]="$(get_default_gateway_for_interface "$int")"
  fi

  CFG_METRIC["$int"]="${metric:-$(get_metric_for_interface "$int")}"
  CFG_DNS["$int"]="${dns:-8.8.8.8}"

  if is_wifi_interface "$int"; then
    CFG_TYPE["$int"]="wifi"
    CFG_SSID["$int"]="${ssid:-$(get_default_ssid)}"
    CFG_PASSWORD["$int"]="${password:-$(get_default_wifi_password)}"
  else
    CFG_TYPE["$int"]="ethernet"
    CFG_SSID["$int"]=""
    CFG_PASSWORD["$int"]=""
  fi
}

# For example "DHCP 192.168.12.120/24", "DHCP, no cable" or "static 10.10.20.101/24, not connected"
interface_summary() {
  local int="$1"
  local summary

  if [ "${CFG_ENABLED[$int]}" != "yes" ]; then
    echo "disabled"
    return
  fi

  if [ "${CFG_DHCP4[$int]}" = "yes" ]; then
    local dhcp_address
    dhcp_address=$(get_dhcp_address "$int")
    summary="DHCP${dhcp_address:+ $dhcp_address}"
  else
    summary="static ${CFG_ADDRESS[$int]}/${CFG_PREFIX[$int]}"
    if [ "${CFG_GATEWAY_TO_INTERNET[$int]}" = "yes" ]; then
      summary="$summary via ${CFG_GATEWAY[$int]}"
    fi
  fi

  if [ "$(get_link_state "$int")" = "down" ]; then
    if [ "${CFG_TYPE[$int]}" = "wifi" ]; then
      summary="$summary, not connected"
    else
      summary="$summary, no cable"
    fi
  elif [ "${CFG_DHCP4[$int]}" = "yes" ] && [ -z "$dhcp_address" ]; then
    summary="$summary, waiting for address"
  fi

  echo "$summary"
}

edit_interface_menu() {
  local int="$1"
  local choice="Enabled"

  while true; do
    local type="${CFG_TYPE[$int]}"
    local menu_text

    menu_text="Interface: $int

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

    # Keep the cursor on the last edited option
    choice=$(whiptail --title "$TITLE - $int" --ok-button "Edit" --cancel-button "Back" --default-item "$choice" --menu "$menu_text" \
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
      local tmp
      tmp=$(input_box "Enter static IP address for $int:" "${CFG_ADDRESS[$int]}") || continue
      CFG_ADDRESS["$int"]="$tmp"
      ;;

    "CIDR prefix")
      local tmp
      tmp=$(input_box "Enter CIDR prefix for $int, for example 24:" "${CFG_PREFIX[$int]}") || continue
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
      local tmp
      tmp=$(input_box "Enter default gateway for $int:" "${CFG_GATEWAY[$int]}") || continue
      CFG_GATEWAY["$int"]="$tmp"
      ;;

    "Metric")
      local tmp
      tmp=$(input_box "Enter metric for $int. Only the active gateway with the lowest metric will be used for internet access:" "${CFG_METRIC[$int]}") || continue
      CFG_METRIC["$int"]="$tmp"
      ;;

    "DNS server")
      local tmp
      tmp=$(input_box "Enter DNS server address for $int:" "${CFG_DNS[$int]}") || continue
      CFG_DNS["$int"]="$tmp"
      ;;

    "Wi-Fi SSID")
      local tmp
      tmp=$(input_box "Enter Wi-Fi SSID for $int:" "${CFG_SSID[$int]}") || continue
      CFG_SSID["$int"]="$tmp"
      ;;

    "Wi-Fi password")
      local tmp
      tmp=$(input_box "Enter Wi-Fi password for $int:" "${CFG_PASSWORD[$int]}") || continue
      CFG_PASSWORD["$int"]="$tmp"
      ;;
    esac
  done
}

main_interface_menu() {
  local choice="${INTERFACES[0]}"

  while true; do
    local menu_items=()

    for int in "${INTERFACES[@]}"; do
      menu_items+=("$int" "$(interface_summary "$int")")
    done

    # Blank separator line
    menu_items+=(" " " ")

    menu_items+=("Save" "Generate netplan config and continue")

    choice=$(whiptail --title "$TITLE" \
      --ok-button "Select" \
      --default-item "$choice" \
      --cancel-button "Cancel" \
      --menu "Current config ($CURRENT_RENDERER) and link state.\nSelect an interface to configure:" \
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

      if is_optional_interface "$int"; then
        echo "      optional: true" >>"$FILENAME"
      fi

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

      if is_optional_interface "$int"; then
        echo "      optional: true" >>"$FILENAME"
      fi

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
  echo "Backing up current network configuration ..."
  prepare_revert

  echo "Copying netplan ..."
  sudo install -m 600 "$FILENAME" "$TARGET_FILE"

  disable_other_netplan_configs

  # Check the config before changing anything that could cut the network connection
  echo "Generating netplan ..."
  if ! sudo netplan generate; then
    echo "The netplan config is not valid, restoring the previous config. Nothing was changed."
    restore_netplan_files
    return 1
  fi

  if [[ "${NON_INTERACTIVE_MODE:-0}" -ne 1 ]]; then
    schedule_revert
  fi

  echo "Enabling systemd-networkd and disabling NetworkManager ..."
  echo "Applying netplan ..."
  if ! use_systemd_networkd || ! sudo netplan apply; then
    echo "Applying the netplan config failed"
    revert_now
    return 1
  fi

  if [[ "${NON_INTERACTIVE_MODE:-0}" -ne 1 ]]; then
    confirm_or_revert || return 1
  else
    sudo rm -rf "$REVERT_DIR"
  fi

  echo "Done"
}

interactive_mode() {
  detect_interfaces

  CURRENT_RENDERER="systemd-networkd"
  if systemctl is-active --quiet NetworkManager; then
    CURRENT_RENDERER="NetworkManager"
  fi

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

Save to $TARGET_FILE and apply?
Other configs in $NETPLAN_DIR will be renamed to *.yaml.bak.

After the config is applied, press Enter in this terminal within $((REVERT_TIMEOUT - 10)) seconds to keep it, otherwise the previous config is restored. If this terminal loses its connection because of the change, log in again, any new login confirms the config."; then
      # User selected Yes
      break
    else
      # User selected No, go back to interface selection menu
      continue
    fi
  done
}

non_interactive_mode() {
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
  exit $?
}

main "$@"
