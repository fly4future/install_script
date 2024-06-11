#!/bin/bash

# Path to the script to be executed
SCRIPT_TO_RUN="/usr/local/bin/setup_ap.sh"

# Log file to keep track of power button presses
LOGFILE="/tmp/power_button_press.log"

# Maximum time interval (in seconds) between presses to count as a triple press
TIME_INTERVAL=7

# Log the current time
echo "$(date +%s)" >> $LOGFILE

# Remove entries older than the TIME_INTERVAL
awk -v interval=$TIME_INTERVAL -v now=$(date +%s) '$1 >= now - interval' $LOGFILE > ${LOGFILE}.tmp
mv ${LOGFILE}.tmp $LOGFILE

# Remove duplicate consecutive entries (within 1 second interval to handle multiple events per press)
awk '!seen[$1]++' $LOGFILE > ${LOGFILE}.tmp
mv ${LOGFILE}.tmp $LOGFILE

# Count the number of unique entries in the log file within the TIME_INTERVAL
COUNT=$(wc -l < $LOGFILE)

# Check if there are 3 or more unique entries
if [ $COUNT -ge 3 ]; then
  # Clear the log file
  > $LOGFILE
  # Run the script
  /bin/bash $SCRIPT_TO_RUN
fi