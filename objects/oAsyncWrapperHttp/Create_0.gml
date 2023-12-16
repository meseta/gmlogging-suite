// This object exists solely to be spawned by add_async_http_callback
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
