# A DIY IPMI system utilizing the Raspberry Pi
This system is under development.

## Requirements
- Rasberry Pi 3 Model B (make sure you use a 2.5Amp or greater power supply)
- Rasberry Pi Zero 1.3
- GPIO pins for Pi Zero
- GPIO cables (https://www.amazon.com/gp/product/B01BV2A54G)
- 2x MicroSD cards (https://www.amazon.com/dp/B06XWN9Q99)
- Relay board (https://www.amazon.com/dp/B0057OC5WK)
- S-video cable
- Easycap UTV007 device (https://www.amazon.com/dp/B0126O0RDC)
- USB TTL Serial cable (https://www.amazon.com/gp/product/B00QT7LQ88)


## Setting up the hardware

- Connect the Pi3 to the relay board using this method: `http://youtu.be/oaf_zQcrg7g`
- Connect the Pi0 to the Pi3 using this method: `https://www.thepolyglotdeveloper.com/2017/02/connect-raspberry-pi-pi-zero-usb-ttl-serial-cable/`. You do not need to supply power to the Pi0, it will get power via the GPIO pins.
- Plug the easycap device and the USB TTL device into the USB ports on the Pi3


## Setting up the Pi 3

Flash `http://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-2017-09-08/`. As of this writing you may use the latest Stretch version, however this was the version used successfully.

To be able to reboot the computer, run:
```
mkdir -p /opt/bin
cd /opt/bin
wget AAAAAAAAAAAA/rebootServer.py
chmod +x /opt/bin/rebootServer.py
```
Now test this script to see if it resets the computer. Look in the python script to see the numbers associated with which of the 8 relays you could use for multiple computers.

Next, move on to video caputure.
```
apt-get update
apt-get install gstreamer mencoder screen
```
Connect a source and test to see if it's working. (Input 0 is usually Composite, and Input 1 is usually S-Video)
```
mencoder tv:// -tv driver=v4l2:norm=NTSC:device=/dev/video0:input=0:fps=5 -nosound -ovc copy -o test.avi
```
Control-C that, and sftp the file to a host to playback:
```
sftp test.avi root@hostname:/folder/test.avi
```
NEED TO FINISH


## Setting up the Pi 0

Flash `http://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-2017-03-03/`. You must use this version for this to work. There aren't really security implications since the Pi0 can only be accessed from a serial session on the Pi3.

Before putting the SD into the Pi0, Add this to the end of /boot/config.txt:
```
dtoverlay=dwc2
enable_uart=1
```
Now insert the SD card and boot the Pi3 (which in turn boots the Pi0 since it get's power from the Pi3).

Access the Pi0 from the Pi3 by SSHing into the Pi3 and running:
```
screen /dev/ttyUSB0 115200
```
You can exit the session by hitting `Control-A` then typing `:quit` and pressing enter.

On the Pi0, run:
```
cd /home/pi
wget https://raw.githubusercontent.com/pelya/android-keyboard-gadget/master/hid-gadget-test/jni/hid-gadget-test.c
gcc -o sendkeys hid-gadget-test.c
wget AAAAAA/enableHID.sh
chmod +x /home/pi/enableHID.sh
sudo /home/pi/enableHID.sh
```
Next, add the following to `/etc/rc.local`:
```
/home/pi/enableHID.sh
```

Now plug a micro-USB to USB cable into the Pi0 and the computer you wish to control. You send keystrokes by:
```
/home/pi/sendkeys /dev/hidg0 keyboard
```
You will need to type things like "a" and press ENTER to send the "a." Other ways to send keys include things like:
```
echo 'a' | /home/pi/sendkeys /dev/hidg0 keyboard
echo 'return' | /home/pi/sendkeys /dev/hidg0 keyboard
echo 'shift a' | /home/pi/sendkeys /dev/hidg0 keyboard
echo 'left-meta space' | /home/pi/sendkeys /dev/hidg0 keyboard
```
