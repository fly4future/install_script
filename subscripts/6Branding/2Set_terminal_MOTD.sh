#!/bin/bash

sudo chmod -x /etc/update-motd.d/10-help-text
sudo chmod -x /etc/update-motd.d/60-unminimize
sudo chmod -x /etc/update-motd.d/90-updates-available

sudo cp subscripts/6Branding/DISREGARD/10-fly4future /etc/update-motd.d/10-fly4future
sudo chmod +x /etc/update-motd.d/10-fly4future

echo "Terminal MOTD has been set use Fly4Future branding."

exit 0
