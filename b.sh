#!/bin/bash
add_to_bashrc () { #arg1 - what should we look for in .bashrc; arg2 - what should we put in bashrc if we did not find arg1
  if grep --quiet "$1" ~/test_shrc; then
    echo "$1 found in .bashrc"
  else
    echo "$1 not found in .bashrc, adding ..."
    echo -e "$2" >> ~/test_shrc
  fi
}

if grep --quiet "Following lines were added by the automatic install script:" ~/test_shrc; then
  echo ""
else
  echo -e "\n" >> ~/test_shrc
  echo "#Following lines were added by the automatic install script: " >> ~/test_shrc
  echo -e "\n" >> ~/test_shrc
fi

add_to_bashrc "export UAV_NAME" "export UAV_NAME=uav1"
add_to_bashrc "export RUN_TYPE" "export RUN_TYPE=realworld"
add_to_bashrc "export UAV_TYPE" "export UAV_TYPE=x500"
add_to_bashrc "export UAV_MASS" "export UAV_MASS=2.0"
add_to_bashrc "export WORLD_NAME" "export WORLD_NAME=temesvar_field"
add_to_bashrc "export INITIAL_DISTURBANCE_X" "export INITIAL_DISTURBANCE_X=0.0"
add_to_bashrc "export INITIAL_DISTURBANCE_Y" "export INITIAL_DISTURBANCE_Y=0.0"
add_to_bashrc "export SENSORS" 'export SENSORS="pixhawk, rtk, garmin_down, realsense_front"'
add_to_bashrc "export OLD_PX4_FW" "export OLD_PX4_FW=0"

add_to_bashrc "source ~/workspace/devel/" "\nsource ~/workspace/devel/setup.bash"



