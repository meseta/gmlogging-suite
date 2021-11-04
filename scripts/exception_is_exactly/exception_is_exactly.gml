function exception_is_exactly(_err, _exception){
	// Returns whether this error is exactly a given exception
	return instanceof(_err) == script_get_name(_exception)
}