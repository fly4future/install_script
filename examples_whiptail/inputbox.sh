#!/bin/bash 

name=$(whiptail --inputbox "Enter your name" 10 30 3>&1 1>&2 2>&3)

echo "Hello $name" 
