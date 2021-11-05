function Logger(_name="logger", _bound_values=undefined, _json_mode=false, _root_logger=undefined) constructor {
	__name = _name;
	__bound_values = (is_struct(_bound_values) ? _bound_values : {});
	__json_logging = _json_mode;
	__file_handle = -1;
	__filename = undefined;
	
	__root_logger = _root_logger;
	__auto_flush = false;
	__sentry = undefined;
	__sentry_send_errors = false;
	
	__enable_fatal = true
	__enable_error = true;
	__enable_warning = true;
	__enable_info = true;
	__enable_debug = true;
	
	logger = function(_level, _message, _extras=undefined, _type=undefined, _stacktrace=undefined) {
		// Create a log message
		
		if (LOGGING_DISABLED) return;
		
		if (!(_level == LOG_FATAL and __enable_fatal) and 
			!(_level == LOG_ERROR and __enable_error) and
			!(_level == LOG_WARNING and __enable_warning) and
			!(_level == LOG_INFO and __enable_info) and
			!(_level == LOG_DEBUG and __enable_debug)){
			return;
		}

		// start combined with "type" added
		var _combined = {};
		var _combined_str = " ";
		
		if (not is_undefined(_type)) {
			_combined[$ "type"] = _type
			_combined_str += "type=" + string(_type) + " ";
		}
		
		// combine extras and bound values
		var _extras_is_struct = is_struct(_extras)
			
		// output from extras
		if (_extras_is_struct) {
			var _keys = variable_struct_get_names(_extras);
			var _len = array_length(_keys);
			for (var _i=0; _i<_len; _i++) {
				var _key = _keys[_i];
				_combined[$ _key] = _extras[$ _key]
				_combined_str += _key + "=" + string(_extras[$ _key]) + " ";
			}
		}
		
		// output from bound values
		var _keys = variable_struct_get_names(__bound_values);
		var _len = array_length(_keys);
		for (var _i=0; _i<_len; _i++) {
			var _key = _keys[_i];
			if (not _extras_is_struct or not variable_struct_exists(_extras, _key)) {
				_combined[$ _key] = __bound_values[$ _key];
				_combined_str += _key + "=" + string(__bound_values[$ _key]) + " ";
			}
		}

		if (__json_logging) {
			var _struct = {
				logName: __name,
				times: __datetime_string_iso(),
				severity: string_upper(_level),
				message: string(_message),
				extras: _combined,
			}
			if (not is_undefined(_stacktrace)) {
				_struct[$ "stacktrace"] = _stacktrace
			}
			var _output = json_stringify(_struct);
		}
		else {
			var _output = __datetime_string()
			switch(_level) {
				case LOG_FATAL:		_output += " [fatal  ]["; break;
				case LOG_ERROR:		_output += " [error  ]["; break;
				case LOG_WARNING:	_output += " [warning]["; break;
				case LOG_INFO:		_output += " [info   ]["; break;
				case LOG_DEBUG:		_output += " [debug  ]["; break;
				default:			_output += " ["+_level+"][";
			}
			_output += __string_pad(__name + "] " + _message, LOGGING_PAD_WIDTH) + _combined_str;
			if (not is_undefined(_stacktrace)) {
				_combined_str += "stacktrace=" + string(_stacktrace) + " ";
			}
		}
		

		show_debug_message(_output);
		__write_line_to_file(_output);
		
		if (not is_undefined(__sentry)) {
			if (__sentry_send_errors and _level == LOG_ERROR) {
				__sentry.send_report(_level, _message, undefined, undefined, __name, _combined, _stacktrace); 
			}
			else {
				if (is_undefined(_type)) {
					if (_level == LOG_FATAL or _level = LOG_ERROR or _level = LOG_WARNING) {
						_type = LOG_ERROR	
					}
					else if (_level == LOG_INFO or _level == LOG_DEBUG) {
						_type = _level
					}
					else {
						_type = "default";	
					}
				}
				__sentry.add_breadcrumb(__name, _message, _combined, _level, _type);
			}
		}
	}
	
	debug = function(_message, _extras=undefined, _type=undefined) {
		// Create a debug-level log message
		if (LOGGING_DISABLED or not __enable_debug) return;
		logger(LOG_DEBUG, _message, _extras, _type);	
	}
	info = function(_message, _extras=undefined, _type=undefined) {
		// Create an info-level log message
		if (LOGGING_DISABLED or not __enable_info) return;
		logger(LOG_INFO, _message, _extras, _type);	
	}
	log = function(_message, _extras=undefined, _type=undefined) {
		// This function exists purely to appease javascript "console.log()" lovers
		if (LOGGING_DISABLED or not __enable_info) return;
		logger(LOG_INFO, _message, _extras, _type);	
	}
	warning = function(_message, _extras=undefined, _type=undefined) {
		// Create a warning-level log message
		if (LOGGING_DISABLED or not __enable_warning) return;
		logger(LOG_WARNING, _message, _extras, _type);	
	}
	error = function(_message, _extras=undefined, _type=undefined) {
		// Create an error-level log message
		if (LOGGING_DISABLED or not __enable_error) return;
		
		if (__sentry_send_errors) {
			var _stacktrace = debug_get_callstack();
			array_delete(_stacktrace, 0, 1);
			logger(LOG_ERROR, _message, _extras, _type, _stacktrace);
		}
		else {
			logger(LOG_ERROR, _message, _extras, _type);
		}
	}
	fatal = function(_message, _extras=undefined, _type=undefined) {
		// Create an fatal-level log message
		if (LOGGING_DISABLED or not __enable_fatal) return;
		logger(LOG_FATAL, _message, _extras, _type);	
	}
	stacktrace = function(_message, _extras=undefined, _type=undefined) {
		// Log a stacktrace
		if (LOGGING_DISABLED) return;
		var _stacktrace = debug_get_callstack();
		array_delete(_stacktrace, 0, 1);
		logger(LOG_DEBUG, _message, _extras, _type, _stacktrace);	
	}
	exception = function(_exception, _extras=undefined, _level=LOG_ERROR) {
		// logs a GML catch exception, or one of our own Exception structs
		if (LOGGING_DISABLED) return;
	
		if (not is_struct(_exception)) {
			// Not a struct, so maybe a string? log it
			var _stacktrace = debug_get_callstack();
			array_delete(_stacktrace, 0, 1);
			logger(_level, string(_exception), _extras, undefined, _stacktrace)
		}
		else if (variable_struct_exists(_exception, "__msg")) {
			// If it's one of our exception library's custom errors
			logger(_level, string(_exception.__msg), _extras, undefined, _exception.__stack);
		}
		else {
			// Otherwise, assume it's a a gamemaker runtime error, wrap it
			logger(_level, string(_exception.message), _extras, undefined, _exception.stacktrace);
		}
	}
	
	bind_named = function(_name, _extras=undefined) {
		// create a new logger instance with extra bindings
		
		if (LOGGING_DISABLED) return new Logger(_name);
		// combine curretn bound values
		var _struct = {}
		
		// copy current bound values
		var _keys = variable_struct_get_names(__bound_values);
		var _len = array_length(_keys);
		for (var _i=0; _i<_len; _i++) {
			var _key = _keys[_i];
			_struct[$ _key] = __bound_values[$ _key];
		}
		
		// copy extras
		if (is_struct(_extras)) {
			var _keys = variable_struct_get_names(_extras);
			var _len = array_length(_keys);
			for (var _i=0; _i<_len; _i++) {
				var _key = _keys[_i];
				_struct[$ _key] = _extras[$ _key];
			}
		}
		
		var _root_logger = is_undefined(__root_logger) ? self : __root_logger;
		var _new_logger = new Logger(_name, _struct, __json_logging, _root_logger);
		
		if (not is_undefined(__sentry)) {
			_new_logger.use_sentry(__sentry, __sentry_send_errors);
		}
		
		return _new_logger;
	}
	
	bind = function(_extras=undefined) {
		// create a new logger instance with extra bindings, but same name
		return bind_named(__name, _extras);
	}
	
	set_level = function(_minimum_log_level=LOG_DEBUG) {
		__enable_fatal = false
		__enable_error = false;
		__enable_warning = false;
		__enable_info = false;
		__enable_debug = false;
		switch(_minimum_log_level) {
			case LOG_DEBUG: __enable_debug = true;
			case LOG_INFO: __enable_info = true;
			case LOG_WARNING: __enable_warning = true;
			case LOG_ERROR: __enable_error = true;
			case LOG_FATAL: __enable_fatal = true;
		}
		return self;
	}
	
	flush_to_file = function() {
		// Flush pending log messages to file
		if (LOGGING_DISABLED) return;
		if (__file_handle >= 0) {
			file_text_close(__file_handle);
			file_text_open_append(__filename);
		}
	}
	
	log_to_file = function(_filename=undefined, _auto_flush=false) {
		// Configure this logger to log to file
		if (LOGGING_DISABLED) return;
		close_log()
		
		__filename =_filename
		__auto_flush = _auto_flush;
		
		if (is_undefined(__filename)) {
			__filename = __generate_log_filename();	
		}
		
		__file_handle = file_text_open_append(__filename);
		if (__file_handle == -1) {
			throw "Could not create log file";	
		}
		return self;
	}
	
	json_mode = function(_mode=true) {
		// Configure this logger to write logs in json mode
		__json_logging = _mode;
		return self;
	}
	
	close_log = function() {
		// Explicitly close the log
		if (LOGGING_DISABLED) return;
		if (__file_handle >= 0) {
			file_text_close(__file_handle);
		}
	}
	
	use_sentry = function(_sentry=undefined, _sentry_send_errors=false) {
		// Attach a sentry instance to logger, to automatically add breadcrumbs
		// and optionally automatically send to sentry on errors
		__sentry = _sentry;
		__sentry_send_errors = _sentry_send_errors;
		return self;
	}
	
	__write_line_to_file = function(_output) {
		if ( __file_handle >= 0) {
			file_text_write_string(__file_handle, _output);
			file_text_writeln(__file_handle);
			
			if (__auto_flush) {
				flush_to_file();
			}
		}
		else if (not is_undefined(__root_logger)) {
			// if I don't have a file handle, but have a root, and use grandparent's output
			__root_logger.__write_line_to_file(_output);
		}
	}
	
	__generate_log_filename = function() {
		var _datetime = date_current_datetime();	
		var _filename = "log_" + __date_string(_datetime, "") + __time_string(_datetime, "") + ".log";
		return _filename;
	}
	
	__string_pad = function(_str, _spaces) {
		var _spaces_to_add = _spaces - string_length(_str);
		
		while(_spaces_to_add >= 8)	{ _spaces_to_add -= 8; _str += "        "; }
		if (_spaces_to_add >= 4)	{ _spaces_to_add -= 4; _str += "    "; }
		if (_spaces_to_add >= 2)	{ _spaces_to_add -= 2; _str += "  "; }
		if (_spaces_to_add == 1)	{ _str += " "; }
		
		return _str;
	}
	
	__datetime_string = function() {
		var _datetime = date_current_datetime();	
		return __date_string(_datetime) + " " + __time_string(_datetime);
	}
	
	__datetime_string_iso = function() {
		var _old_tz = date_get_timezone();
		date_set_timezone(timezone_utc);
		
		var _datetime = date_current_datetime();	
		var _str = __date_string(_datetime) + "T" + __time_string(_datetime) + "Z";
		date_set_timezone(_old_tz);
		return _str;
	}
	
	__date_string = function(_datetime, _separator="-") {
		var _str = string_format(date_get_year(_datetime), 4, 0) + _separator +
				    string_format(date_get_month(_datetime), 2, 0) + _separator +
				    string_format(date_get_day(_datetime), 2, 0) ;
		return string_replace_all(_str, " ", "0");
	}
	__time_string = function(_datetime, _separator=":") {
		var _str = string_format(date_get_hour(_datetime), 2, 0) + _separator +
				string_format(date_get_minute(_datetime), 2, 0) + _separator +
				string_format(date_get_second(_datetime), 2, 0);
		return string_replace_all(_str, " ", "0");
	}
	
}