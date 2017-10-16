#!/bin/bash

echo " -=- Getting software -=-"
sudo apt-get update
sudo apt-get -y install libav-tools screen lighttpd php5 php5-cgi git
cd /opt
sudo git clone https://github.com/Fmstrat/diy-ipmi
sudo chown pi diy-ipmi -R
chmod +x /opt/diy-ipmi/Pi3/*.py
chmod +x /opt/diy-ipmi/Pi3/*.sh
cd -

echo " -=- Time to set up the HTTP server -=-"
read -s -p "Password for web IPMI console (user 'ipmi'): " IPMIPASS
echo ""
echo "ipmi:${IPMIPASS}" | sudo tee --append /var/www/ipmipasswd
sudo lighty-enable-mod fastcgi-php
sudo adduser www-data gpio
echo '' | sudo tee --append /etc/lighttpd/lighttpd.conf
echo 'server.modules += ( "mod_auth" )' | sudo tee --append /etc/lighttpd/lighttpd.conf
echo 'auth.debug = 2' | sudo tee --append /etc/lighttpd/lighttpd.conf
echo 'auth.backend = "plain"' | sudo tee --append /etc/lighttpd/lighttpd.conf
echo 'auth.backend.plain.userfile = "/var/www/ipmipasswd"' | sudo tee --append /etc/lighttpd/lighttpd.conf
echo 'auth.require = ( "/" =>' | sudo tee --append /etc/lighttpd/lighttpd.conf
echo '        (' | sudo tee --append /etc/lighttpd/lighttpd.conf
echo '                "method" => "basic",' | sudo tee --append /etc/lighttpd/lighttpd.conf
echo '                "realm" => "Password protected area",' | sudo tee --append /etc/lighttpd/lighttpd.conf
echo '                "require" => "user=ipmi"' | sudo tee --append /etc/lighttpd/lighttpd.conf
echo '        )' | sudo tee --append /etc/lighttpd/lighttpd.conf
echo ')' | sudo tee --append /etc/lighttpd/lighttpd.conf

echo " -=- Linking the web files -=-"
cd /var/www/
sudo mv /var/www/html /var/www/html.orig
sudo ln -s /opt/diy-ipmi/Pi3/html /var/www/html

echo " -=- Making configuration -=-"
echo '[Server 1]' | sudo tee --append /etc/ipmi.conf
echo 'TTY=/dev/ttyUSB0' | sudo tee --append /etc/ipmi.conf
echo 'VID=/dev/video0' | sudo tee --append /etc/ipmi.conf
echo 'INP=1' | sudo tee --append /etc/ipmi.conf
echo 'PIN=2' | sudo tee --append /etc/ipmi.conf

echo " -=- Restarting the web server -=-"
sudo service lighttpd force-reload
sudo systemctl restart lighttpd

echo " -=- Final steps -=-"
sudo chmod a+rw /dev/video0
sudo mkdir -p /mnt/ramdisk
sudo mount -t tmpfs -o size=3m tmps /mnt/ramdisk
sudo chown www-data /mnt/ramdisk
sudo v4l2-ctl -d /dev/video0 --set-input=1
sudo chmod a+rw /dev/ttyUSB0

echo " -=- Make sure they happen on boot -=-"
sudo sed -i 's/exit 0//g' /etc/rc.local
echo "chmod a+rw /dev/video0" | sudo tee --append /etc/rc.local
echo "mkdir -p /mnt/ramdisk" | sudo tee --append /etc/rc.local
echo "mount -t tmpfs -o size=3m tmps /mnt/ramdisk" | sudo tee --append /etc/rc.local
echo "chown www-data /mnt/ramdisk" | sudo tee --append /etc/rc.local
echo "v4l2-ctl -d /dev/video0 --set-input=1" | sudo tee --append /etc/rc.local
echo "chmod a+rw /dev/ttyUSB0" | sudo tee --append /etc/rc.local
echo "exit 0" | sudo tee --append /etc/rc.local


echo " -=- Time to set up the Pi0 -=-"
echo " -=- Logging into the Pi0 -=-"
if ! /opt/diy-ipmi/Pi3/checkPi0Login.sh; then
	echo " -=- Logging into the Pi0 as 'pi' with password 'raspberry' has failed -=-"
	echo "     Open another terminal session and use 'screen /dev/ttyUSB0 115200' to login to the Pi0"
	echo "     Once logged in, hit 'Ctrl-A' then type ':quit' to exit the screen session"
	echo "     Lastly, return here and press 'Enter' to continue or 'Ctrl-C' to give up. -=-"
	read CONT
fi

echo " -=- Setting up auto login on the serial terminal -=-"
echo "sudo systemctl enable serial-getty@ttyAMA0.service" >> /dev/ttyUSB0
echo "sudo cp /lib/systemd/system/serial-getty@.service /etc/systemd/system/serial-getty@ttyAMA0.service" >> /dev/ttyUSB0
echo "sudo sed -i 's/agetty --keep-baud 115200/agetty -a pi --keep-baud 115200/g' /etc/systemd/system/serial-getty@ttyAMA0.service" >> /dev/ttyUSB0
echo "sudo systemctl daemon-reload" >> /dev/ttyUSB0

echo " -=- Disabling network to speed Pi0 bootup -=-"
echo "sudo systemctl disable networking" >> /dev/ttyUSB0
echo "sudo apt-get -y remove dhcpcd5 isc-dhcp-client isc-dhcp-common" >> /dev/ttyUSB0
echo " -=- Waiting for removal of network to complete (60s) -=-"
sleep 60

echo " -=- Transfering files to Pi0 for HID -=-"
echo "rm -f /tmp/B64" >> /dev/ttyUSB0
for LINE in $(base64 /opt/diy-ipmi/Pi0/enableHID.sh); do echo "echo $LINE >> /tmp/B64" >> /dev/ttyUSB0; done
echo "base64 -d /tmp/B64 > /home/pi/enableHID.sh" >> /dev/ttyUSB0
echo "chmod +x /home/pi/enableHID.sh" >> /dev/ttyUSB0

echo " -=- Transfering files to Pi0 for HID send keys -=-"
echo "rm -f /tmp/B64" >> /dev/ttyUSB0
for LINE in $(base64 /opt/diy-ipmi/Pi0/sendkeys.c); do echo "echo $LINE >> /tmp/B64" >> /dev/ttyUSB0; done
echo "base64 -d /tmp/B64 > /home/pi/sendkeys.c" >> /dev/ttyUSB0
echo "gcc -o /home/pi/sendkeys /home/pi/sendkeys.c" >> /dev/ttyUSB0

echo " -=- Compiling and transfering files to Pi0 for HID reset -=-"
sudo apt-get -y install libusb-dev
cd /opt/diy-ipmi/Pi0/
gcc -o hub-ctrl hub-ctrl.c -lusb
for LINE in $(base64 hub-ctrl); do echo "echo $LINE >> /tmp/B64" >> /dev/ttyUSB0; done
echo "base64 -d /tmp/B64 > /home/pi/hub-ctrl" >> /dev/ttyUSB0
echo "chmod +x /home/pi/hub-ctrl" >> /dev/ttyUSB0
cd -

echo " -=- Enabling HID on Pi0 and adding boot options -=-"
echo "sudo /home/pi/enableHID.sh" >> /dev/ttyUSB0
echo "sudo sed -i 's/exit 0//g' /etc/rc.local" >> /dev/ttyUSB0
echo "echo /home/pi/enableHID.sh | sudo tee --append /etc/rc.local" >> /dev/ttyUSB0
echo "echo exit 0 | sudo tee --append /etc/rc.local" >> /dev/ttyUSB0

echo " -=- Finished! Try http://<ip of pi3> -=-"
