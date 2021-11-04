function RuntimeException(_err) : Exception(_err) constructor {
	// For wrapping a runtime exception
	array_push(__inheritence, script_get_name(RuntimeException))
	if (is_struct(_err)) {
		__msg = _err[? "message"];
		__stack = _err[? "stacktrace"];
	}
}