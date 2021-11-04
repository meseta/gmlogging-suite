function Exception(_msg) constructor {
	// Root exception
	__inheritence = [script_get_name(Exception)]
	__stack = debug_get_callstack();
	array_delete(__stack, 0, 1);
	__msg = _msg;
	
	toString = function() {
		return instanceof(self) + ": " + string(__msg) + "\n" + string(__stack);
	}
}