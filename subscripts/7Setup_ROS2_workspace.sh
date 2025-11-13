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


WORKSPACE_NAME=$(whiptail --inputbox "$3\n What should be your workspace name?" 0 0 "workspace" --title "ROS2 workspace setup" --cancel-button "Cancel"  3>&1 1>&2 2>&3)

ret_val=$?
if [ $ret_val -eq 255 ]; then
  # User hit Escape
  exit 1
elif [ $ret_val -eq 1 ]; then
  # User hit Cancel
  exit 1
elif [ $ret_val -eq 0 ]; then
  # valid input
  return 0
else
  echo "Error state"
  exit 0
fi

# Pass choices variable to whiptail
SELECTIONS=$(whiptail --separate-output --title "MRS UAV System Install Utility" --checklist "Choose options by pressing the spacebar" 0 0 0 "${CHOICES[@]}" 3>&1 1>&2 2>&3)

ret_val=$?


if [[ "$ret_val" -eq 1 ]]; then
  exit 1
fi
if [[ "$ret_val" -eq 255 ]]; then
  exit 1
fi

echo "Setting up ~/$WORKSPACE_NAME..."
source /opt/ros/jazzy/setup.bash             # source the general ROS workspace so that the local one will extend it and see all the packages
mkdir -p ~/$WORKSPACE_NAME/src && cd ~/$WORKSPACE_NAME    # create the workspace folder in home and cd to it
sudo apt install python3-colcon-mixin
colcon init
colcon mixin add default https://raw.githubusercontent.com/colcon/colcon-mixin-repository/master/index.yaml
colcon mixin update default
colcon mixin add mrs https://raw.githubusercontent.com/ctu-mrs/mrs_uav_development/refs/heads/ros2/mixin/index.yaml
colcon mixin mrs default
# Create colcon defaults.yaml file with build options
mkdir -p ~/$WORKSPACE_NAME/.colcon
cat <<EOT >> ~/$WORKSPACE_NAME/colcon_defaults.yaml
build:
  parallel-workers: 8
  mixin:
    - rel-with-deb-info
EOT

mkdir ~/git
cd ~/git
for CHOICE in $SELECTIONS; do
  case "$CHOICE" in
    "1") git clone https://github.com/ctu-mrs/mrs_uav_deployment.git
      cd mrs_uav_deployment
      git checkout ros2
      cd ..
      ln -s ~/git/mrs_uav_deployment ~/$WORKSPACE_NAME/src/
      ;;
    "2") git clone https://github.com/ctu-mrs/mrs_core_examples.git
      cd mrs_core_examples
      git checkout ros2
      cd ..
      ln -s ~/git/mrs_core_examples ~/$WORKSPACE_NAME/src/
      ;;
    "3") git clone https://github.com/ctu-mrs/mrs_uav_development.git
      cd mrs_uav_development
      git checkout ros2
      cd ..
      ln -s ~/git/mrs_uav_development ~/$WORKSPACE_NAME/src/
      add_to_bashrc "source ~/git/mrs_uav_development/shell_additions/shell_additions.sh" "\nsource ~/git/mrs_uav_development/shell_additions/shell_additions.sh"
      ;;
    *)
      exit 1
      ;;
  esac
done

cd ~/$WORKSPACE_NAME
colcon build 

add_to_bashrc "export ROS_WORKSPACE=" "\nexport ROS_WORKSPACE=\"$HOME/$WORKSPACE_NAME\""
add_to_bashrc "source /opt/ros/jazzy/setup.bash" "\nsource /opt/ros/jazzy/setup.bash" 
add_to_bashrc "source ~/$WORKSPACE_NAME/install/" "\nsource ~/$WORKSPACE_NAME/install/setup.bash"
exit 0
