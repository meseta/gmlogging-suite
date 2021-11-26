function exception_handler(_err){
	// Custom exception handler that helps format our custom exceptions
	var _msg = _err.message
	
	// match our hacked custom exceptions
	if (string_pos("Unable to find a handler for exception ", _msg) == 1) {
		
		// split message into lines
		var _pos = 39;
		var _lines = [];
		var _strlen = string_length(_msg);
		var _arrlen = -1;
		do {
			var _last_pos = _pos;
			_pos = string_pos_ext("\n", _msg, _last_pos);
			var _line = string_copy(_msg, _last_pos+1, (_pos>0?_pos: _strlen)-_last_pos-1);
			if (_line != "" and _line != "NO CALLSTACK") {
				array_push(_lines, _line);
				_arrlen += 1;
			}
		} until (_pos == 0);
		
		// get the call stack
		var _stacktrace = json_parse(array_pop(_lines));
		
		// join the rest of the lines back up
		var _message = _lines[0];
		for (var _i=1; _i<_arrlen; _i++) {
			_message += "\r" + _lines[_i];
		}
	}
	else {
		var _message = _err.message;
		var _stacktrace = _err.stacktrace;
	}
	
	var _trace_lines = ""
	var _len = array_length(_stacktrace);
	for (var _i=0; _i<_len; _i++) {
		_trace_lines += string(_stacktrace[_i]) + "\r";
	}
	
	show_message(
		"______________________________________________________________\r\r" +
		_message + "\r" +
		"______________________________________________________________\r\r" +
		"STACKTRACE:\r" +
		_trace_lines + "\r"
	);
}