#!/bin/bash
echo " -=- Getting software -=-"
#sudo apt-get update
sudo apt-get -y install libav-tools screen lighttpd php php-cgi git socat raspberrypi-kernel-headers v4l2loopback-dkms
cd /opt
sudo git clone https://github.com/spyd3rweb/diy-ipmi
sudo chown pi diy-ipmi -R
chmod +x /opt/diy-ipmi/Pi3/*.py
chmod +x /opt/diy-ipmi/Pi3/*.sh
sudo cp /opt/diy-ipmi/diy-ipmi-environment /etc/
source /etc/diy-ipmi-environment
cd -

if sudo [ ! -f $HOME/.ssh/id_rsa ]; then
	echo " -=- Generating SSH Key -=- "
	sudo chown -R pi:pi /home/pi/.ssh ; sudo chmod 700 /home/pi/.ssh
	ssh-keygen -b 2048 -t rsa -f $HOME/.ssh/id_rsa -q -N ""	
	cp ~/.ssh/id_rsa.pub ~/.ssh/authorized_keys
	sudo chmod 644 ~/.ssh/authorized_keys
fi

if sudo [ ! -f $CA_SERVER_KEY ]; then
	echo " -=- Generating CA Server Key -=- "
	sudo rm -rf $CA_SERVER_CERT $IPMI_SERVER_KEY $IPMI_SERVER_CERT $IPMI_SERVER_PEM $HID_SERVER_KEY $HID_SERVER_CERT $HID_SERVER_PEM 2>/dev/null
	sudo openssl genrsa -out $CA_SERVER_KEY 4096
	sudo chmod 600 $CA_SERVER_KEY 
fi

if sudo [ ! -f $CA_SERVER_CERT ]; then
	echo " -=- Generating CA Server Cert -=- "
	sudo openssl req -x509 -new -nodes -key $CA_SERVER_KEY -subj "/C=US/O=DIY/CN=*.diy.local" -sha256 -days 3653 -out $CA_SERVER_CERT
	echo 01 | sudo tee --append /etc/ssl/certs/ca.srl
fi

if sudo [ ! -f $IPMI_SERVER_KEY ]; then
	echo " -=- Generating IPMI Server Key -=- "
	sudo openssl genrsa -out $IPMI_SERVER_KEY 2048
	sudo chmod 600 $IPMI_SERVER_KEY 
fi

if sudo [ ! -f $HID_SERVER_KEY ]; then
	echo " -=- Generating HID Server Key -=- "
	sudo openssl genrsa -out $HID_SERVER_KEY 2048
	sudo chmod 600 $HID_SERVER_KEY 
fi

if sudo [ ! -f $IPMI_SERVER_CERT ]; then
	echo " -=- Generating and Signing IPMI Server Certificate Singing Request -=- "
	sudo openssl req -new -sha256 -key $IPMI_SERVER_KEY -subj "/C=US/O=DIY/CN=ipmi.diy.local" -out $PRIVATE_DIR/ipmi.diy.local.csr
	sudo chmod 600 $PRIVATE_DIR/ipmi.diy.local.csr
	sudo openssl x509 -req -in $PRIVATE_DIR/ipmi.diy.local.csr -CA $CA_SERVER_CERT -CAkey $CA_SERVER_KEY -out $IPMI_SERVER_CERT -days 3653 -sha256
fi

if sudo [ ! -f $HID_SERVER_CERT ]; then
	echo " -=- Generating and Signing HID Server Certificate Singing Request -=- "
	sudo openssl req -new -sha256 -key $HID_SERVER_KEY -subj "/C=US/O=DIY/CN=hid.diy.local" -out $PRIVATE_DIR/hid.diy.local.csr
	sudo chmod 600 $PRIVATE_DIR/hid.diy.local.csr
	sudo openssl x509 -req -in $PRIVATE_DIR/hid.diy.local.csr -CA $CA_SERVER_CERT -CAkey $CA_SERVER_KEY -out $HID_SERVER_CERT -days 3653 -sha256
fi

if sudo [ ! -f $IPMI_SERVER_PEM ]; then
	echo " -=- Creating IPMI Server PEM Certificate -=- "
	sudo /bin/sh -c  "sudo cat $IPMI_SERVER_KEY $IPMI_SERVER_CERT $CA_SERVER_CERT > $IPMI_SERVER_PEM"
	sudo chmod 600 $IPMI_SERVER_PEM 
fi

if sudo [ ! -f $HID_SERVER_PEM ]; then
	echo " -=- Creating HID Server PEM Certificate -=- "
	sudo /bin/sh -c "sudo cat $HID_SERVER_KEY $HID_SERVER_CERT $CA_SERVER_CERT > $HID_SERVER_PEM"
	sudo chmod 600 $HID_SERVER_PEM 
fi

echo " -=- Time to set up the HTTP server -=-"
echo '
server.modules += ( "mod_auth" )
auth.debug = 2
auth.backend = "plain"
auth.backend.plain.userfile = "/var/www/ipmipasswd"
auth.require = ( "/" =>
        (
                "method" => "basic",
                "realm" => "Password protected area",
                "require" => "user=ipmi"
        )
)' > /opt/diy-ipmi/Pi3/lighttpd-http.conf

if [[ -n $(diff /etc/lighttpd/lighttpd.conf /opt/diy-ipmi/Pi3/lighttpd-http.conf 2>/dev/null | grep -e "^> ") ]]; then
	cat /opt/diy-ipmi/Pi3/lighttpd-http.conf | sudo tee --append /etc/lighttpd/lighttpd.conf
fi 

if [[ ! -n $(grep -e "ipmi\:.*" /var/www/ipmipasswd 2> /dev/null) ]]; then 
	read -s -p "Password for web IPMI console (user 'ipmi'): " IPMIPASS
	echo ""
	echo "ipmi:${IPMIPASS}" | sudo tee --append /var/www/ipmipasswd
	sudo lighty-enable-mod fastcgi-php
	sudo adduser www-data gpio
fi


echo " -=- Time to set up the HTTPS server -=-"
echo '
	$SERVER["socket"] == ":443" {
	ssl.engine = "enable"
	ssl.pemfile = "'"$IPMI_SERVER_PEM"'"
	server.name = "ipmi.local"
	server.document-root = "/var/www/html"
	ssl.use-sslv2 = "disable"
	ssl.use-sslv3 = "disable"
	ssl.use-compression = "disable"
	ssl.honor-cipher-order = "enable"
	ssl.cipher-list = "ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-RC4-SHA:ECDHE-RSA-RC4-SHA:ECDH-ECDSA-RC4-SHA:ECDH-RSA-RC4-SHA:ECDHE-RSA-AES256-SHA:RC4-SHA"
	server.errorlog = "/var/log/lighttpd/serror.log"
	accesslog.filename = "/var/log/lighttpd/saccess.log"
	}
' > /opt/diy-ipmi/Pi3/lighttpd-https.conf

if [[ -n $(diff /etc/lighttpd/lighttpd.conf /opt/diy-ipmi/Pi3/lighttpd-https.conf 2>/dev/null | grep -e "^> ") ]]; then
        cat /opt/diy-ipmi/Pi3/lighttpd-https.conf | sudo tee --append /etc/lighttpd/lighttpd.conf
fi


echo " -=- Linking the web files -=-"
cd /var/www/
sudo mv /var/www/html /var/www/html.orig
sudo ln -s /opt/diy-ipmi/Pi3/html /var/www/html

echo " -=- Making configuration -=-"
echo '[Server 1]
TTY='"$IPMI_SERVER_VTTY1"'
VID=/dev/video0
INP=1
PIN=2' > /opt/diy-ipmi/Pi3/ipmi.conf 
if [[ ! -e /etc/ipmi.conf || $(diff /etc/ipmi.conf /opt/diy-ipmi/Pi3/ipmi.conf 2>/dev/null) =~ "^\>" ]]; then
        cat /opt/diy-ipmi/Pi3/ipmi.conf | sudo tee --append /etc/ipmi.conf
fi

echo " -=- Restarting the web server -=-"
sudo service lighttpd force-reload
sudo systemctl restart lighttpd
sudo systemctl enable lighttpd

echo " -=- Time to set up the Pi0 -=-"
LOGINSUCCESS=0
while [ $LOGINSUCCESS -eq 0 ]; do
	ssh-copy-id -i $HOME/.ssh/id_rsa pi@$HID_SERVER_IPV4 2>/dev/null
        
	echo " -=- Installing socat on Pi0 -=-" 
	ssh -i $HOME/.ssh/id_rsa pi@$HID_SERVER_IPV4 "sudo apt-get install -y socat"
	
	echo " -=- Transfering Server Certs and HID Server Keys to Pi0 -=-"
	# create dirs	
        ssh -i $HOME/.ssh/id_rsa pi@$HID_SERVER_IPV4 "mkdir -p /home/pi/certs /home/pi/private 2>/dev/null && sudo mkdir $CERTS_DIR $PRIVATE_DIR 2>/dev/null" 
        # scp Certs
	sudo sh -c "scp -i $HOME/.ssh/id_rsa $CA_SERVER_CERT $IPMI_SERVER_CERT $HID_SERVER_CERT pi@$HID_SERVER_IPV4:/home/pi/certs"
	# scp PEM and keys
	sudo scp -i $HOME/.ssh/id_rsa $HID_SERVER_KEY $HID_SERVER_PEM pi@$HID_SERVER_IPV4:/home/pi/private
        # mv and secure permissions
 	ssh -i $HOME/.ssh/id_rsa pi@$HID_SERVER_IPV4 "sudo mv /home/pi/certs/* $CERTS_DIR/" 
 	ssh -i $HOME/.ssh/id_rsa pi@$HID_SERVER_IPV4 "sudo mv /home/pi/private/* $PRIVATE_DIR/" 

	echo " -=- Enabling SSL TTY Service on Pi0 -=-"
	# Copy environment variable file
	sudo scp -i $HOME/.ssh/id_rsa /etc/diy-ipmi-environment pi@$HID_SERVER_IPV4:/home/pi/
	ssh -i $HOME/.ssh/id_rsa pi@$HID_SERVER_IPV4 "sudo cp /home/pi/diy-ipmi-environment /etc/" 
	# Copy and enable diy-ipmi-keyboard systemd service units
	ssh -i $HOME/.ssh/id_rsa pi@$HID_SERVER_IPV4 "sudo systemctl disable diy-ipmi-keyboard*.service && sudo rm -rf /etc/systemd/system/diy-ipmi-keyboard* && sudo rm -rf /home/pi/diy-ipmi-keyboard*"
	scp -i $HOME/.ssh/id_rsa /opt/diy-ipmi/Pi0/diy-ipmi-keyboard*.service pi@$HID_SERVER_IPV4:/home/pi/ 
	ssh -i $HOME/.ssh/id_rsa pi@$HID_SERVER_IPV4 "sudo cp /home/pi/diy-ipmi-keyboard*.service /etc/systemd/system/ && sudo systemctl daemon-reload && sudo systemctl enable diy-ipmi-keyboard*.service && sudo systemctl restart diy-ipmi-keyboard*.service"
	
	echo " -=- Time to set up the IPMI Server diy-ipmi-keyboard* systemd service units on Pi3 -=-"
	sudo systemctl disable diy-ipmi-keyboard*.service 2>/dev/null
	sudo rm -rf /etc/systemd/system/diy-ipmi-keyboard* 2>/dev/null 
	sudo cp /opt/diy-ipmi/Pi3/diy-ipmi-keyboard*.service /etc/systemd/system/
	sudo systemctl daemon-reload
	sudo systemctl enable /etc/systemd/system/diy-ipmi-keyboard*.service 
	sudo systemctl restart diy-ipmi-keyboard*.service

	echo " -=- Time to set up the IPMI Server diy-ipmi-video* systemd service units on Pi3 -=-"
	sudo systemctl disable diy-ipmi-video*.service 2>/dev/null
	sudo rm -rf /etc/systemd/system/diy-ipmi-video* 2>/dev/null 
	sudo cp /opt/diy-ipmi/Pi3/diy-ipmi-video*.service /etc/systemd/system/
	sudo systemctl daemon-reload
	sudo systemctl enable /etc/systemd/system/diy-ipmi-video*.service 
	sudo systemctl restart diy-ipmi-video*.service

	if ! /opt/diy-ipmi/Pi3/checkPi0Login.sh; then
		echo " -=- Logging into the Pi0 as 'pi' with given password via $IPMI_SERVER_VTTY1 has failed -=-"
		echo "     Open another terminal session and use 'ssh pi@$HID_SERVER_IPV4' to login to the Pi0 to validate password"
                echo "     Once logged in, check status of keyboard systemd service by using 'sudo systemctl status diy-ipmi-keyboard*'"
	        echo "     Open another terminal session and use 'screen $IPMI_SERVER_VTTY1 115200' to login to the Pi0"
		echo "     Once logged in, hit 'Ctrl-A' then type ':quit' to exit the screen session"
		echo "     Lastly, return here and press 'Enter' to continue or 'Ctrl-C' to give up. -=-"
		read CONT

	else
		LOGINSUCCESS=1
	fi
done

echo " -=- Setting up auto login on the serial terminal -=-"
#echo "sudo systemctl enable serial-getty@ttyAMA0.service" >> $IPMI_SERVER_VTTY1
ssh -i $HOME/.ssh/id_rsa pi@$HID_SERVER_IPV4 "sudo systemctl enable serial-getty@ttyAMA0.service"
#echo "sudo cp /lib/systemd/system/serial-getty@.service /etc/systemd/system/serial-getty@ttyAMA0.service" >> $IPMI_SERVER_VTTY1
ssh -i $HOME/.ssh/id_rsa pi@$HID_SERVER_IPV4 "sudo cp /lib/systemd/system/serial-getty@.service /etc/systemd/system/serial-getty@ttyAMA0.service"
#echo "sudo sed -i 's/agetty --keep-baud 115200/agetty -a pi --keep-baud 115200/g' /etc/systemd/system/serial-getty@ttyAMA0.service" >> $IPMI_SERVER_VTTY1
ssh -i $HOME/.ssh/id_rsa pi@$HID_SERVER_IPV4 "sudo sed -i 's/agetty --keep-baud 115200/agetty -a pi --keep-baud 115200/g' /etc/systemd/system/serial-getty@ttyAMA0.service"
#echo "sudo systemctl daemon-reload" >> $IPMI_SERVER_VTTY1
ssh -i $HOME/.ssh/id_rsa pi@$HID_SERVER_IPV4 "sudo systemctl daemon-reload"

echo " -=- Transfering files to Pi0 for HID -=-"
scp -i $HOME/.ssh/id_rsa /opt/diy-ipmi/Pi0/enableHID.sh pi@$HID_SERVER_IPV4:/home/pi
#echo "chmod +x /home/pi/enableHID.sh" >> $IPMI_SERVER_VTTY1
ssh -i $HOME/.ssh/id_rsa pi@$HID_SERVER_IPV4 "chmod +x /home/pi/enableHID.sh"

echo " -=- Transfering files to Pi0 for HID send keys -=-"
scp -i $HOME/.ssh/id_rsa /opt/diy-ipmi/Pi0/sendkeys.c pi@$HID_SERVER_IPV4:/home/pi
#echo "[[ ! -e /home/pi/sendkeys ]] || gcc -o /home/pi/sendkeys /home/pi/sendkeys.c" >> $IPMI_SERVER_VTTY1
ssh -i $HOME/.ssh/id_rsa pi@$HID_SERVER_IPV4 "[[ ! -e /home/pi/sendkeys ]] || gcc -o /home/pi/sendkeys /home/pi/sendkeys.c"

echo " -=- Compiling and transfering files to Pi0 for HID reset -=-"
sudo apt-get -y install libusb-dev
cd /opt/diy-ipmi/Pi0/
if [[ ! -e hub-ctrl ]]; then
	gcc -o hub-ctrl hub-ctrl.c -lusb
fi
scp -i $HOME/.ssh/id_rsa /opt/diy-ipmi/Pi0/hub-ctrl pi@$HID_SERVER_IPV4:/home/pi
#echo "chmod +x /home/pi/hub-ctrl" >> $IPMI_SERVER_VTTY1
ssh -i $HOME/.ssh/id_rsa pi@$HID_SERVER_IPV4 "chmod +x /home/pi/hub-ctrl"

echo " -=- Transfering files to Pi0 for HID Service -=-"
scp -i $HOME/.ssh/id_rsa hid.service testkeys.py pi@$HID_SERVER_IPV4:/home/pi
#echo "sudo cp /home/pi/hid.service /etc/systemd/system/" >> $IPMI_SERVER_VTTY1
ssh -i $HOME/.ssh/id_rsa pi@$HID_SERVER_IPV4 "sudo cp /home/pi/hid.service /etc/systemd/system/"

echo " -=- Enabling HID on Pi0 -=-"
#echo "sudo systemctl daemon-reload" >> $IPMI_SERVER_VTTY1
ssh -i $HOME/.ssh/id_rsa pi@$HID_SERVER_IPV4 "sudo systemctl daemon-reload"
#echo "sudo systemctl enable hid.service" >> $IPMI_SERVER_VTTY1
ssh -i $HOME/.ssh/id_rsa pi@$HID_SERVER_IPV4 "sudo systemctl enable hid.service"
#echo "sudo systemctl start hid.service" >> $IPMI_SERVER_VTTY1
ssh -i $HOME/.ssh/id_rsa pi@$HID_SERVER_IPV4 "sudo systemctl start hid.service"

cd -

echo " -=- Finished! Try https://$IPMI_SERVER_WEB_IPV4 or http://$IPMI_SERVER_WEB_IPV4 -=-"

