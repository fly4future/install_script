#!/bin/bash

sudo apt-get -y install aptitude
sudo apt-get remove $(aptitude search -F '%p' '~S ~i ?origin("ctu-mrs") ?label("unstable")')
sudo apt-get remove $(aptitude search -F '%p' '~S ~i ?origin("ctu-mrs") ?label("stable")')

exit 0
