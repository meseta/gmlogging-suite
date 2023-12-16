if (async_load[? "status"] != 1) { // content still being downloaded
	for (var _i=callbacks_length-1; _i>=0; _i--) {
		var _callback = callbacks[_i];
		var _handled = _callback(async_load);
	
		if (_handled) {
			array_delete(callbacks, _i, 1);
			callbacks_length -= 1;
		}
	}
}