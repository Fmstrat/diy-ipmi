#!/bin/bash

RESPONSE=

function runCommand() {
        exec 3</dev/ttyUSB0                     #REDIRECT SERIAL OUTPUT TO FD 3
        cat <&3 > /mnt/ramdisk/ttyDump.dat &          #REDIRECT SERIAL OUTPUT TO FILE
        PID=$!                                #SAVE PID TO KILL CAT
        echo "" > /dev/ttyUSB0             #SEND COMMAND STRING TO SERIAL PORT
        sleep 1                          #WAIT FOR RESPONSE
        kill $PID                             #KILL CAT PROCESS
        exec 3<&-                               #FREE FD 3
        RESPONSE=$(tail -n 1 /mnt/ramdisk/ttyDump.dat)                    #DUMP CAPTURED DATA
}

runCommand;
if [ "$RESPONSE" == "raspberrypi login: " ]; then
        echo "We need to login..."
        echo "pi" >> /dev/ttyUSB0
        echo "raspberry" >> /dev/ttyUSB0
        sleep 1
        runCommand
        if [ "$RESPONSE" == "pi@raspberrypi:~$ " ]; then
                echo "Login successful"
        else
                echo "Error logging in"
        fi
elif [ "$RESPONSE" == "pi@raspberrypi:~$ " ]; then
        echo "Already logged in"
else
        echo aa${RESPONSE}aa
        echo "Error"
fi
