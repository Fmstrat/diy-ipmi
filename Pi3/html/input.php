<?php

	system("v4l2-ctl -d ".$_POST['vid']." --set-input=".$_POST['inp']);

?>
