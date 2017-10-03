<?php

	$key = $_POST['k'];
	$cmd='echo "echo \''.$key.'\' | /home/pi/sendkeys /dev/hidg0 keyboard" >> /dev/ttyUSB0';
	system($cmd);
?>
