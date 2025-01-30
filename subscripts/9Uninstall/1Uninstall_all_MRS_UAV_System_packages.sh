#!/bin/bash

sudo apt-get -y install aptitude
sudo apt remove $(aptitude search -F '%p' '~S ~i ?origin("ctu-mrs") ?label("unstable")')
sudo apt remove $(aptitude search -F '%p' '~S ~i ?origin("ctu-mrs") ?label("stable")')

exit 0
