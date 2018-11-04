#!/bin/bash
source /etc/diy-ipmi-environment
RESPONSE=
COUNT=1

function processResponse() {
	if [ "$RESPONSE" == "raspberrypi login: " ]; then
		echo "We need to login..."
		echo "pi" >> $IPMI_SERVER_VTTY1
		echo "raspberry" >> $IPMI_SERVER_VTTY1
		sleep 1
		runCommand
		if [ "$RESPONSE" == "pi@raspberrypi:~ $" ]; then
			echo "Login successful"
		else
			echo "Error logging in"
		fi
	elif [[ ( "$RESPONSE" == "pi@raspberrypi:~ $" ) ||  ( "$RESPONSE" =~ ^root@raspberrypi:.*#$ ) ]]; then
		echo "Already logged in"
	elif [ ! $COUNT -eq 5 ]; then
		echo "Error logging into Pi0 on try $COUNT.. Retrying in 10s"
		let COUNT=COUNT+1
		sleep 10;
		runCommand;
	else
		echo "Error.. Giving up"
		exit 1
	fi
}

function runCommand() {
        exec 3<$IPMI_SERVER_VTTY1                    #REDIRECT SERIAL OUTPUT TO FD 3
        cat <&3 > /mnt/ramdisk/ttyDump.dat &          #REDIRECT SERIAL OUTPUT TO FILE
        PID=$!                                #SAVE PID TO KILL CAT
        echo "" > $IPMI_SERVER_VTTY1             #SEND COMMAND STRING TO SERIAL PORT
        sleep 1                          #WAIT FOR RESPONSE
        kill $PID                             #KILL CAT PROCESS
        exec 3<&-                               #FREE FD 3
        RESPONSE=$(tail -n 1 /mnt/ramdisk/ttyDump.dat)                    #DUMP CAPTURED DATA
        RESPONSE=$(echo $RESPONSE | sed "s,\x1B\[[0-9;]*[a-zA-Z],,g") #Remove (color/special/escape/ANSI) codes from text with sed
        echo $RESPONSE
	processResponse;
}

runCommand;

