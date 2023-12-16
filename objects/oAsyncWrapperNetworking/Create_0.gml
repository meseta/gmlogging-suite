// This object exists solely to be spawned by add_async_networking_callback
// Do not spawn this object by hand

callbacks = [];
callbacks_length = 0;

/** Add a callback to the handler to respond to HTTP events
 * @param {Function} _callback A callback to add
 * @self
 */
add_callback = function(_callback) {
	array_push(callbacks, _callback);
	callbacks_length += 1;
}

/** Remove a callback
 * @param {Function} _callback The callback to remove
 * @self
 */
remove_callback = function(_callback) {
	for (var _i=callbacks_length-1; _i>=0; _i--) {
		if (callbacks[_i] == _callback) {
			array_delete(callbacks, _i, 1);
			callbacks_length -= 1;
		}
	}
}
