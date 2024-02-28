#!/bin/bash

add_to_bashrc () { #arg1 - what should we look for in .bashrc; arg2 - what should we put in bashrc if we did not find arg1
  if grep --quiet "$1" ~/.bashrc; then
    echo "$1 found in .bashrc"
  else
    echo "$1 not found in .bashrc, adding ..."
    echo -e "$2" >> ~/.bashrc
  fi
}

CHOICES=(
  "1" "Add mrs_uav_deployment (Necessary for real UAVs)" ON
  "2" "Add mrs_core_examples (example nodes which demonstrate system functionality)" ON
  "3" "Add mrs_uav_development (MRS only, bash additions for development)" OFF
)

# Pass choices variable to whiptail
SELECTIONS=$(whiptail --separate-output --title "MRS UAV System Install Utility" --checklist "Choose options by pressing the spacebar" 0 0 0 "${CHOICES[@]}" 3>&1 1>&2 2>&3)

ret_val=$?


if [[ "$ret_val" -eq 1 ]]; then
  exit 1
fi
if [[ "$ret_val" -eq 255 ]]; then
  exit 1
fi

echo "Setting up ~/workspace..."
source /opt/ros/noetic/setup.bash             # source the general ROS workspace so that the local one will extend it and see all the packages
mkdir -p ~/workspace/src && cd ~/workspace    # create the workspace folder in home and cd to it
catkin init -w ~/workspace                    # initialize the new workspace
# setup basic compilation profiles
catkin config --profile debug --cmake-args -DCMAKE_BUILD_TYPE=Debug -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DCMAKE_CXX_FLAGS='-std=c++17 -Og' -DCMAKE_C_FLAGS='-Og'
catkin config --profile release --cmake-args -DCMAKE_BUILD_TYPE=Release -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DCMAKE_CXX_FLAGS='-std=c++17'
catkin config --profile reldeb --cmake-args -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DCMAKE_CXX_FLAGS='-std=c++17'
catkin profile set reldeb                     # set the reldeb profile as active

mkdir ~/git
cd ~/git
for CHOICE in $SELECTIONS; do
  case "$CHOICE" in
    "1") git clone https://github.com/ctu-mrs/mrs_uav_deployment.git
      ln -s ~/git/mrs_uav_deployment ~/workspace/src/
      ;;
    "2") git clone https://github.com/ctu-mrs/mrs_core_examples.git
      ln -s ~/git/mrs_core_examples ~/workspace/src/
      ;;
    "3") git clone https://github.com/ctu-mrs/mrs_uav_development.git
      ln -s ~/git/mrs_uav_development ~/workspace/src/
      ;;
    *)
      exit 1
      ;;
  esac
done

cd ~/workspace
catkin build

add_to_bashrc "source ~/workspace/devel/" "\nsource ~/workspace/devel/setup.bash"
exit 0
