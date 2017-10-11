<?php

	$filename = "/mnt/ramdisk/snapshot.jpg";
	system("avconv -f video4linux2 -i ". $_GET['vid'] ." -vframes 1 -s 720x480 -v quiet -y ". $filename);

	if( file_exists( $filename ) ){
	  header("content-type: image/jpeg");
	  echo file_get_contents( $filename );
	} else {
	  echo "Error loading the snapshot";
	}

?>
