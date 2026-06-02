#!/bin/bash

show_menu() {
  whiptail --title "$1" --menu "$2" 0 0 0 "${OPTIONS[@]}" 3>&1 1>&2 2>&3
}

ask_yesno() {
  local prompt="$1"
  local default="$2" # "yes" or "no"

  if [ "$default" = "no" ]; then
    whiptail --title "Udev Config" --yesno "$prompt" 0 0 --defaultno
  else
    whiptail --title "Udev Config" --yesno "$prompt" 0 0
  fi

  ret_val=$?
  if [ $ret_val -eq 255 ]; then
    exit 1
  elif [ $ret_val -eq 0 ]; then
    return 0
  elif [ $ret_val -eq 1 ]; then
    return 1
  else
    echo "Error state"
    exit 1
  fi
}

yesno_def_no() {
  ask_yesno "$1" "no"
}

yesno_def_yes() {
  ask_yesno "$1" "yes"
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

msg_box() {
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
    msg_box "$empty_message"
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

list_existing_udev_rules_file() {
  list_files_from_dir "/etc/udev/rules.d" "Udev config" "Select which udev rules file you want to use:" "No files found in /etc/udev/rules.d."
}
