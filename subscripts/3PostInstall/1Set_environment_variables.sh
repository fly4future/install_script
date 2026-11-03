#!/bin/bash

set -euo pipefail

set_env_var () {
  #arg1 - what should we look for in .bashrc
  #arg2 - what is the default value for the parameter
  #arg3 - description of this variable

  bashrc_content=$(grep -m 1 "^export $1=" ~/.bashrc || true)
  var_name=""
  var_value=""

  if [ -z "$bashrc_content" ]
  then
    #variable was not found in bashrc
    var_name=$1;
    var_value=$2;
  else
    #variable is in bashrc, we are now showing its current value
    var_name=$1;
    var_value=${bashrc_content#*=};
  fi
  ret_val=0
  new_value=$(whiptail --inputbox "$3\n $var_name=" 0 0 "$var_value" --title "Bashrc variable setup" --cancel-button "Skip"  3>&1 1>&2 2>&3) || ret_val=$?

  #strip any quotes, they are not necessary
  new_value=$(echo "$new_value" | sed "s/[\"\']//g")

  if [ $ret_val -eq 255 ]; then
    exit 1
  fi
  if [ $ret_val -eq 1 ]; then
    return 0
  else
    if [ -z "$bashrc_content" ]
    then
      #variable was not found in bashrc
      echo -e "export $1=$new_value" >> ~/.bashrc
    else
      #variable is in bashrc, we are editing it
      sed -i "/^export $1=/c\export $1=$new_value" ~/.bashrc
    fi
  fi
  clear
}

set_env_var "UAV_NAME" "uav1" "name of this UAV (will be used as a namespace for ROS nodes/topics)\n example: uav1, uav2, uav35 ..."
set_env_var "UAV_TYPE" "x500" "What is the UAV frame that we are using?\n values: x500, f450, t650 ...\n See https://github.com/ctu-mrs/mrs_uav_deployment/tree/HEAD/config/mrs_uav_system for all available types"
set_env_var "UAV_MASS" "20.0" "What is the mass of the UAV in kg?\n values: 1.5, 3.5, ...\n If you don't know yet leave it at 20kg, which is too much for any UAV. This will make the system complain and thus remind you to correct it"

exit 0
