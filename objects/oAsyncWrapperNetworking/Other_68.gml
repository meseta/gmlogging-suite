array_foreach(callbacks, function(_callback) {
	_callback(async_load);
});