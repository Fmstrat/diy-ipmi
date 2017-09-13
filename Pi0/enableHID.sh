#!/bin/bash
if [ "$(lsusb)" == "Bus 001 Device 001: ID 1d6b:0002 Linux Foundation 2.0 root hub" ]; then
	modprobe libcomposite
	cd /sys/kernel/config/usb_gadget/
	mkdir -p g1
	cd g1
	echo 0x1d6b > idVendor # Linux Foundation
	echo 0x0104 > idProduct # Multifunction Composite Gadget
	echo 0x0100 > bcdDevice # v1.0.0
	echo 0x0200 > bcdUSB # USB2
	mkdir -p strings/0x409
	echo "deadbeef01234567890" > strings/0x409/serialnumber
	echo "example.com" > strings/0x409/manufacturer
	echo "Generic USB Keyboard" > strings/0x409/product
	N="usb0"
	mkdir -p functions/hid.$N
	echo 1 > functions/hid.usb0/protocol
	echo 1 > functions/hid.usb0/subclass
	echo 8 > functions/hid.usb0/report_length
	echo -ne \\x05\\x01\\x09\\x06\\xa1\\x01\\x05\\x07\\x19\\xe0\\x29\\xe7\\x15\\x00\\x25\\x01\\x75\\x01\\x95\\x08\\x81\\x02\\x95\\x01\\x75\\x08\\x81\\x03\\x95\\x05\\x75\\x01\\x05\\x08\\x19\\x01\\x29\\x05\\x91\\x02\\x95\\x01\\x75\\x03\\x91\\x03\\x95\\x06\\x75\\x08\\x15\\x00\\x25\\x65\\x05\\x07\\x19\\x00\\x29\\x65\\x81\\x00\\xc0 > functions/hid.usb0/report_desc
	C=1
	mkdir -p configs/c.$C/strings/0x409
	echo "Config $C: ECM network" > configs/c.$C/strings/0x409/configuration 
	echo 250 > configs/c.$C/MaxPower 
	ln -s functions/hid.$N configs/c.$C/
	ls /sys/class/udc > UDC
	chmod -R 777 /dev/hidg0
fi
