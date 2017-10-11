<?php
	$tty = $_POST['tty'];
	$key = $_POST['k'];
	$cmd='echo "echo \''.$key.'\' | /home/pi/sendkeys /dev/hidg0 keyboard" >> '.$tty;
	system($cmd);
?>
