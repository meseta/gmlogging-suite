function exception_wrap(_err){
	// Cleans up exception objects, wrapping them with custom exceptions
	
	if (not is_struct(_err)) {
		// Not a struct, so maybe a string? Wrap it in generic custom Exception
		return new Exception(_err);
	}
	
	if (variable_struct_exists(_err, "__msg")) {
		// If it's one of this exception library's custom errors, throw it
		return _err;
	}
	
	// Otherwise, assume it's a a gamemaker runtime error, wrap it
	return new RuntimeException(_err);
}