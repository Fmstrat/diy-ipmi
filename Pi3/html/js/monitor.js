var img;
var tty;
var pin;
var vid;

function startRefresh() {
	var firstserver = '';
	var select = document.getElementById("servers");
	for (var server in servers) {
		var option = document.createElement('option');
		option.text = option.value = server;
		select.add(option);
		if (firstserver == '') {
			firstserver = server;
		}
	}
	img = document.getElementById("monitor");
	if (firstserver != '') {
		selectServer(firstserver);
		//img.addEventListener('load', imageLoaded)
		//img.addEventListener('error', imageLoaded)
		//img.src = "/image.php?t=" + new Date().getTime();
	}
}

function selectServer(server) {
	vid = servers[server].vid;
	tty = servers[server].tty;
	pin = servers[server].pin;
	alert(vid);
}

function onSelectChange(option) {
	selectServer(option.value);
}

function imageLoaded() {
	img.src = "/image.php?vid=" + vid + "&t=" + new Date().getTime();
}
