function exception_is(_err, _exception){
	// Returns whether this error is a given exception or its children
	var _exception_type = script_get_name(_exception);
	
	// Loop through error's inheritence tree to find a match
	var _len = array_length(_err.__inheritence);
	for (var _i=0; _i<_len; _i++) {
		if (_err.__inheritence[_i] == _exception_type) {
			return true;
		}
	}
	return false;
}