#!/bin/bash 
source /etc/diy-ipmi-environment
echo "sudo ./hub-ctrl -h 0 -P 1 -p 0" >> $IPMI_SERVER_VTTY1
echo "sudo reboot" >> $IPMI_SERVER_VTTY1
