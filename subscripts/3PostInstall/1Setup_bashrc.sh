#!/bin/bash

add_var_to_bashrc () {
  #arg1 - what should we look for in .bashrc
  #arg2 - what is the default value for the parameter
  #arg3 - description of this variable

  bashrc_content=$(grep "export $1=" ~/.bashrc)
  var_name=""
  var_value=""

  if [ -z "$bashrc_content" ]
  then
    #variable was not found in bashrc
    var_name=$1;
    var_value=$2;
  else
    #variable is in bashrc, we are now showing its current value
    IFS='='
    read -a strarr <<< "$bashrc_content"
    var_name=${strarr[0]};
    var_value=${strarr[1]};
  fi
  new_value=$(whiptail --inputbox "$3\n $var_name=" 0 0 "$var_value" --title "Bashrc variable setup" --cancel-button "Skip"  3>&1 1>&2 2>&3)

  ret_val=$?

  #strip any quotes, they are not necessary
  new_value=$(echo "$new_value" | sed "s/[\"\']//g")

  if [ $ret_val -eq 255 ]; then
    exit 1
  fi
  if [ $ret_val -eq 1 ]; then
    return 1
  else
    if [ -z "$bashrc_content" ]
    then
      #variable was not found in bashrc
      echo -e "export $1=$new_value" >> ~/.bashrc
    else
      #variable is in bashrc, we are editing it
      sed -i "/export $1/c\export $1=$new_value" ~/.bashrc
    fi
  fi
  clear
}

add_var_to_bashrc_quotes () {
  #arg1 - what should we look for in .bashrc
  #arg2 - what is the default value for the parameter
  #arg3 - description of this variable

  bashrc_content=$(grep "export $1=" ~/.bashrc)
  var_name=""
  var_value=""

  if [ -z "$bashrc_content" ]
  then
    #variable was not found in bashrc
    var_name=$1;
    var_value=$2;
  else
    #variable is in bashrc, we are now showing its current value
    IFS='='
    read -a strarr <<< "$bashrc_content"
    var_name=${strarr[0]};
    var_value=${strarr[1]};
  fi
  new_value=$(whiptail --inputbox "$3\n $var_name=" 0 0 "$var_value" --title "Bashrc variable setup" --cancel-button "Skip"  3>&1 1>&2 2>&3)

  ret_val=$?

  #strip any quotes, they will be added later
  new_value=$(echo "$new_value" | sed "s/[\"\']//g")

  if [ $ret_val -eq 255 ]; then
    exit 1
  fi
  if [ $ret_val -eq 1 ]; then
    return 1
  else
    if [ -z "$bashrc_content" ]
    then
      #variable was not found in bashrc
      echo -e "export $1=\"$new_value\"" >> ~/.bashrc
    else
      #variable is in bashrc, we are editing it
      sed -i "/export $1/c\export $1=\"$new_value\"" ~/.bashrc
    fi
  fi
  clear
}

add_var_to_bashrc "UAV_NAME" "uav1" "name of this UAV (will be used as a namespace for ROS nodes/topics)\n example: uav1, uav2, uav35 ..."
add_var_to_bashrc "RUN_TYPE" "realworld" "Should the system run as a real UAV or as a simulation?\n values: simulation, realworld"
add_var_to_bashrc "UAV_TYPE" "x500" "What is the UAV frame that we are using?\n values: x500, f450, t650 ..."
add_var_to_bashrc "UAV_MASS" "3.0" "What is the mass of the UAV in kg?\n values: 1.5, 3.5, ..."
add_var_to_bashrc "WORLD_NAME" "kn_yard" "What is the name of the default world that we want to use?\n values: kn_yard, cisar, ..."
add_var_to_bashrc "INITIAL_DISTURBANCE_X" "0.0" "Initial X disturbance in Newtons (usually set to 0.0)\n values: 0.0, 0.2, ..."
add_var_to_bashrc "INITIAL_DISTURBANCE_Y" "0.0" "Initial Y disturbance in Newtons (usually set to 0.0)\n values: 0.0, 0.2, ..."
add_var_to_bashrc_quotes "SENSORS" "pixhawk, garmin_down" "What sensors are equipped on this UAV?\n values: pixhawk, garmin_down, ouster, ..."
add_var_to_bashrc "PIXGARM" "true" "Should we look for Garmin data routed through Pixhawk?\n values: true, false"
add_var_to_bashrc "OLD_PX4_FW" "false" "Are we running an old (1.12) Pixhawk FW? (Applies to Pixhawk 4 used in MRS)\n values: true, false"
# add_var_to_bashrc "ROS_MASTER_URI" "http://localhost:11311" "Address of the ROS master. Do not modify on UAVs"
add_var_to_bashrc "ROS_DISTRO" "jazzy" "ROS 2 distribution to use.\n values: jazzy"
add_var_to_bashrc "RMW_IMPLEMENTATION" "rmw_zenoh_cpp" "ROS 2 middleware implementation to use.\n values: rmw_zenoh_cpp"
exit 1
