#!/bin/bash

#!/bin/bash
add_to_bashrc () { #arg1 - what should we look for in .bashrc; arg2 - what should we put in bashrc if we did not find arg1
  if grep --quiet "$1" ~/.bashrc; then
    echo "$1 found in .bashrc"
  else
    echo "$1 not found in .bashrc, adding ..."
    echo -e "$2" >> ~/.bashrc
  fi
}

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# check for internet connectivity - cannot install without internet!
if [[ "$(nm-online -t 3 | grep 'offline' )" != "" ]]; then
  echo -e "${RED}You are not connected to the internet!${NC}"
  exit 1
else
  echo -e "${GREEN}internet connected${NC}"
fi

cd

sudo apt update
sudo apt -y install vim ranger net-tools openssh-server curl git # install some basic programs

curl https://ctu-mrs.github.io/ppa-stable/add_ros_ppa.sh | bash # add the ROS ppa and install ROS
sudo apt -y install ros-noetic-desktop-full

curl https://ctu-mrs.github.io/ppa-stable/add_ppa.sh | bash # add the mrs_uav_system ppa and install the system
sudo apt -y install ros-noetic-mrs-uav-system-full

mkdir git # make the git repo and clone some basic repositories
cd git
git clone https://github.com/ctu-mrs/mrs_uav_deployment.git
git clone https://github.com/ctu-mrs/mrs_core_examples.git

cd

# setup the ROS workspace
source /opt/ros/noetic/setup.bash             # source the general ROS workspace so that the local one will extend it and see all the packages
mkdir -p ~/workspace/src && cd ~/workspace    # create the workspace folder in home and cd to it
catkin init -w ~/workspace                    # initialize the new workspace
# setup basic compilation profiles
catkin config --profile debug --cmake-args -DCMAKE_BUILD_TYPE=Debug -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DCMAKE_CXX_FLAGS='-std=c++17 -Og' -DCMAKE_C_FLAGS='-Og'
catkin config --profile release --cmake-args -DCMAKE_BUILD_TYPE=Release -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DCMAKE_CXX_FLAGS='-std=c++17'
catkin config --profile reldeb --cmake-args -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DCMAKE_CXX_FLAGS='-std=c++17'
catkin profile set reldeb                     # set the reldeb profile as active

cd ~/workspace/src
ln -s ~/git/mrs_core_examples
ln -s ~/git/mrs_uav_deployment
cd ~/workspace
catkin build

sudo systemctl enable systemd-networkd.service
cd
ln -s ~/git/mrs_uav_deployment/tmux/just_flying/tmux.sh

if grep --quiet "Following lines were added by the automatic install script:" ~/.bashrc; then
  echo ""
else
  echo -e "\n" >> ~/.bashrc
  echo "#Following lines were added by the automatic install script: " >> ~/.bashrc
  echo -e "\n" >> ~/.bashrc
fi

add_to_bashrc "export UAV_NAME" "export UAV_NAME=uav1"
add_to_bashrc "export RUN_TYPE" "export RUN_TYPE=realworld"
add_to_bashrc "export UAV_TYPE" "export UAV_TYPE=x500"
add_to_bashrc "export UAV_MASS" "export UAV_MASS=3.0"
add_to_bashrc "export WORLD_NAME" "export WORLD_NAME=kn_yard"
add_to_bashrc "export INITIAL_DISTURBANCE_X" "export INITIAL_DISTURBANCE_X=0.0"
add_to_bashrc "export INITIAL_DISTURBANCE_Y" "export INITIAL_DISTURBANCE_Y=0.0"
add_to_bashrc "export SENSORS" 'export SENSORS="pixhawk, garmin_down"'
add_to_bashrc "export PIXGARM" "export PIXGARM=true"
add_to_bashrc "export OLD_PX4_FW" "export OLD_PX4_FW=0"

add_to_bashrc "source ~/workspace/devel/" "\nsource ~/workspace/devel/setup.bash"

sudo apt -y update && rosdep update && sudo apt -y upgrade --with-new-pkgs --allow-downgrades
source ~/.bashrc

//TODO - zavolat computer scripts z deploymentu (network manager, hibernatce, atd)
//TODO - prekopcit netplan
//TODO - prekopcit udev rules
