var img;

function startRefresh() {
	img = document.getElementById("monitor");
	img.addEventListener('load', imageLoaded)
	img.addEventListener('error', imageLoaded)
	img.src = "/image.php?t=" + new Date().getTime();
}

function imageLoaded() {
	img.src = "/image.php?t=" + new Date().getTime();
}
