#!/usr/bin/python
import RPi.GPIO as GPIO
import time

GPIO.setmode(GPIO.BCM)

# init list with pin numbers

pinList = [2, 3, 4, 17, 27, 22, 10, 9]

# loop through pins and set mode and state to 'low'

for i in pinList:
    GPIO.setup(i, GPIO.OUT)
    GPIO.output(i, GPIO.HIGH)

# time to sleep between operations in the main loop

SleepTimeL = 2

# Set the pin

pin = 2
if len(sys.argv) > 1:
   pin = sys.argv[1]

# main loop

try:
  GPIO.output(pin, GPIO.LOW)
  print "Relay 1 - Rebooting server"
  time.sleep(SleepTimeL);
  GPIO.output(pin, GPIO.HIGH)
  time.sleep(SleepTimeL);
  GPIO.cleanup()
  print "Good bye!"

# End program cleanly with keyboard
except KeyboardInterrupt:
  print "  Quit"

  # Reset GPIO settings
  GPIO.cleanup()
