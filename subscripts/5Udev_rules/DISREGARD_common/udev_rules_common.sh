#!/bin/bash

show_menu() {
  whiptail --title "$1" --menu "$2" 0 0 0 "${OPTIONS[@]}" 3>&1 1>&2 2>&3
}

yesno_def_no() {
  whiptail --title "Udev Config" --yesno "$1" --yes-button "No" --no-button "Yes" 0 0
  ret_val=$?

  if [ $ret_val -eq 255 ]; then
    exit 1
  elif [ $ret_val -eq 1 ]; then
    return 1
  elif [ $ret_val -eq 0 ]; then
    return 0
  else
    echo "Error state"
  fi
}

yesno_def_yes() {
  whiptail --title "Udev Config" --yesno "$1" 0 0
  ret_val=$?

  if [ $ret_val -eq 255 ]; then
    exit 1
  elif [ $ret_val -eq 0 ]; then
    return 1
  elif [ $ret_val -eq 1 ]; then
    return 0
  else
    echo "Error state"
  fi
}

input_box() {
  local prompt="$1"
  local default_value="$2"
  local tmp
  tmp=$(whiptail --inputbox "$prompt" 0 0 "$default_value" 3>&1 1>&2 2>&3)
  ret_val=$?

  if [ $ret_val -eq 255 ]; then
    exit 1
  elif [ $ret_val -eq 1 ]; then
    exit 1
  elif [ $ret_val -eq 0 ]; then
    printf '%s\n' "$tmp"
    return 0
  else
    echo "Error state"
    exit 0
  fi
}

error_msg() {
  whiptail --title "Udev config" --msgbox "$1" 0 0
}

list_files_from_dir() {
  local folder_path="$1"
  local menu_title="$2"
  local menu_prompt="$3"
  local empty_message="$4"
  local options=()
  local files=()
  local index=1
  local file

  shopt -s nullglob
  for file in "$folder_path"/*; do
    if [[ -d "$file" ]]; then
      continue
    fi

    options+=("$index" "${file##*/}")
    files+=("$file")
    index=$((index + 1))
  done
  shopt -u nullglob

  if [ ${#files[@]} -eq 0 ]; then
    error_msg "$empty_message"
    return 1
  fi

  OPTIONS=("${options[@]}")
  local choice
  choice=$(show_menu "$menu_title" "$menu_prompt")

  if [ $? -ne 0 ]; then
    exit 1
  fi

  printf '%s\n' "${files[$((choice - 1))]}"
}

choose_write_mode() {
  local title="$1"
  local prompt="$2"
  OPTIONS=(
    "1" "Create a new file"
    "2" "Append to existing file"
  )
  local choice
  choice=$(show_menu "$title" "$prompt")

  if [ $? -ne 0 ]; then
    exit 1
  fi

  if [ "$choice" = "1" ]; then
    printf '%s\n' "new"
  else
    printf '%s\n' "append"
  fi
}

list_existing_udev_rules_file() {
  list_files_from_dir "/etc/udev/rules.d" "Udev config" "Select which udev rules file you want to use:" "No files found in /etc/udev/rules.d."
}

choose_template_file() {
  list_files_from_dir "$(dirname "$0")/DISREGARD_udev_rules" "Udev config" "Select which udev rules you want to use:" "No udev rules were found."
}

resolve_rules_target_path() {
  local file_name="$1"

  if [[ "$file_name" == /* ]]; then
    printf '%s\n' "$file_name"
    return
  fi

  if [[ "$file_name" != *.rules ]]; then
    file_name="${file_name}.rules"
  fi

  printf '/etc/udev/rules.d/%s\n' "$file_name"
}

write_text_to_target() {
  local target_file="$1"
  local append_mode="$2"
  local content="$3"

  if [ "$append_mode" = "append" ]; then
    printf '%s\n' "$content" | sudo tee -a "$target_file" >/dev/null
  else
    printf '%s\n' "$content" | sudo tee "$target_file" >/dev/null
  fi
}

get_device_info() {
  local device="$1"
  local device_path="/dev/$device"
  local device_info

  device_info=$(udevadm info "$device_path" | grep "S: serial/by-id/" || true)
  device_info="${device_info}\n$(udevadm info "$device_path" | grep "DEVNAME" || true)"
  device_info="${device_info}\n$(udevadm info "$device_path" | grep "ID_VENDOR_FROM_DATABASE" || true)"
  device_info="${device_info}\n$(udevadm info "$device_path" | grep "ID_MODEL_FROM_DATABASE" || true)"
  device_info="${device_info}\n$(udevadm info "$device_path" | grep "ID_VENDOR_ID" || true)"
  device_info="${device_info}\n$(udevadm info "$device_path" | grep "ID_MODEL_ID" || true)"
  device_info="${device_info}\n$(udevadm info "$device_path" | grep "ID_MODEL=" || true)"
  device_info="${device_info}\n$(udevadm info "$device_path" | grep "ID_SERIAL=" || true)"
  device_info="${device_info}\n$(udevadm info "$device_path" | grep "ID_SERIAL_SHORT" || true)"
  device_info="${device_info}\n$(udevadm info "$device_path" | grep "ID_PCI_CLASS_FROM_DATABASE" || true)"
  device_info="${device_info}\n$(udevadm info "$device_path" | grep "ID_PCI_SUBCLASS_FROM_DATABASE" || true)"

  printf '%b\n' "$device_info"
}

get_udev_value() {
  local device="$1"
  local key="$2"
  udevadm info "/dev/$device" | grep "$key" | head -n 1 | sed -e "s/^.*=//"
}