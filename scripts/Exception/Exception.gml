/** Custom exception to mirror gamemaker's built-in exceptions
 * @param {String} _message The exception message
 * @param {String} _long_message A longer message
 * @author Meseta https://meseta.dev
 */
function Exception(_message, _long_message=undefined) constructor {
	/// Feather ignore GM2017
	self.stacktrace = debug_get_callstack();
	// need to delete the first item in the stacktrace which points uselessly to the line above;
	array_delete(self.stacktrace, 0, 1);
	
	self.message = _message;
	self.longMessage = _long_message ?? _message;
	self.long_message = self.longMessage;
	
	global.sentry_last_exception = self;
	
	static toString = function() {
		return $"{instanceof(self)}: {self.message}";
	}
}