/** A logger instance that can be used for writing log messages
 * @param {String} _name The logger's name. This will appear in any log messages produced by this logger
 * @param {Struct} _bound_values Optional struct of bound values which will be included in all log messages produced by this logger
 * @param {Struct.Logger} _root_logger The loot logger instance that is this logger's parent
 * @author Meseta https://meseta.dev
 */
function Logger(_name="logger", _bound_values=undefined, _root_logger=undefined) constructor {
	/* @ignore */ self.__name = _name;
	/* @ignore */ self.__bound_values = (is_struct(_bound_values) ? _bound_values : {});
	/* @ignore */ self.__file_handle = -1;
	/* @ignore */ self.__filename = undefined;
	
	/* @ignore */ self.__root_logger = _root_logger;
	/* @ignore */ self.__auto_flush = false;
	/* @ignore */ self.__sentry = undefined;
	/* @ignore */ self.__sentry_send_errors = false;
	
	/* @ignore */ self.__minimum_log_level = undefined;
	/* @ignore */ self.__enable_fatal = true;
	/* @ignore */ self.__enable_error = true;
	/* @ignore */ self.__enable_warning = true;
	/* @ignore */ self.__enable_info = true;
	/* @ignore */ self.__enable_debug = true;
	
	/* @ignore */ self.__pad_width = 48; // Width of the padding used in the output
	
	/* @ignore */ static __global_json_logging = false;
	/* @ignore */ static __global_logging_enabled = true; // Set to false to globally disable logging

	/** Globally enable or disable loggin
	 * @param {Bool} _enable
	 */
	static set_global_enabled = function(_enabled) {
		self.__global_logging_enabled = _enabled;
	};
	
	/** Globally set loggers to json
	 * @param {Bool} _json_mode
	 */
	static set_global_json = function(_json_mode) {
		self.__global_json_logging = _json_mode;
	};

	/** Output a debug-level log message
	 * @param {String} _message The log message
	 * @param {Struct} _extras Any key/values to include in the log message
	 * @param {String} _type Optional log type (used for Sentry breadcrumbs)
	 */
	static debug = function(_message, _extras=undefined, _type=undefined) {
		// Create a debug-level log message
		if (!self.__global_logging_enabled || !self.__enable_debug) return;
		self.__log(Logger.DEBUG, _message, _extras, _type);	
	};
	
	/** Output an info-level log message
	 * @param {String} _message The log message
	 * @param {Struct} _extras Any key/values to include in the log message
	 * @param {String} _type Optional log type (used for Sentry breadcrumbs)
	 */
	static info = function(_message, _extras=undefined, _type=undefined) {
		// Create an info-level log message
		if (!self.__global_logging_enabled || !self.__enable_info) return;
		self.__log(Logger.INFO, _message, _extras, _type);	
	};
	static log = self.info; // this is an alias of info
	
	/** Output a warning-level log message
	 * @param {String} _message The log message
	 * @param {Struct} _extras Any key/values to include in the log message
	 * @param {String} _type Optional log type (used for Sentry breadcrumbs)
	 */
	static warning = function(_message, _extras=undefined, _type=undefined) {
		// Create a warning-level log message
		if (!self.__global_logging_enabled || !self.__enable_warning) return;
		self.__log(Logger.WARNING, _message, _extras, _type);	
	};
	static warn = self.warning; // sometimes this gets mixed up, so why not both
	
	/** Output an error-level log message. This will also send a sentry report if sentry is enabled in the logger instance
	 * @param {String} _message The log message
	 * @param {Struct} _extras Any key/values to include in the log message
	 * @param {String} _type Optional log type (used for Sentry breadcrumbs)
	 */
	static error = function(_message, _extras=undefined, _type=undefined) {
		// Create an error-level log message
		if (!self.__global_logging_enabled || !self.__enable_error) return;
		
		if (self.__sentry_send_errors) {
			var _stacktrace = debug_get_callstack();
			array_delete(_stacktrace, 0, 1);
			self.__log(Logger.ERROR, _message, _extras, _type, _stacktrace);
		}
		else {
			self.__log(Logger.ERROR, _message, _extras, _type);
		}
	};
	
	/** Output a fatal-level log message
	 * @param {String} _message The log message
	 * @param {Struct} _extras Any key/values to include in the log message
	 * @param {String} _type Optional log type (used for Sentry breadcrumbs)
	 */
	static fatal = function(_message, _extras=undefined, _type=undefined) {
		// Create an fatal-level log message
		if (!self.__global_logging_enabled || !self.__enable_fatal) return;
		self.__log(Logger.FATAL, _message, _extras, _type);	
	};
	
	/** Output a stacktrace (as a debug-level log)
	 * @param {String} _message The log message
	 * @param {Struct} _extras Any key/values to include in the log message
	 * @param {String} _type Optional log type (used for Sentry breadcrumbs)
	 */
	static stacktrace = function(_message, _extras=undefined, _type=undefined) {
		// Log a stacktrace
		if (!self.__global_logging_enabled) return;
		var _stacktrace = debug_get_callstack();
		array_delete(_stacktrace, 0, 1);
		self.__log(Logger.DEBUG, _message, _extras, _type, _stacktrace);	
	};
	
	/** Output a log for an exception
	 * @param {Struct} _exception The exception to log
	 * @param {Struct} _extras Any key/values to include in the log message
	 * @param {String} _level The log level for this exception
	 */
	static exception = function(_exception, _extras=undefined, _level=Logger.ERROR, _type=undefined) {
		// logs a GML catch exception, or one of our own Exception structs
		if (!self.__global_logging_enabled) return;
	
		if (is_struct(_exception)) {
			// If it has a message component, log it
			self.__log(_level, _exception[$ "message"] ?? instanceof(_exception), _extras, _type, _exception[$ "stacktrace"]);
		}
		else {
			// Not a struct, so maybe a string? log it
			var _stacktrace = debug_get_callstack();
			array_delete(_stacktrace, 0, 1);
			self.__log(_level, string(_exception), _extras, _type, _stacktrace)
		}
	};
		
	/** Create a child loger from this loger instance, with optional variables bound to it
	 * @param {String} _name Name of the child
	 * @param {Struct} _extras Any key/values to bind to the child logger
	 */
	static bind_named = function(_name, _extras=undefined) {
		// create a new logger instance with extra bindings
		
		// combine current bound values
		var _struct = variable_clone(self.__bound_values);
		
		// copy in the extras
		if (is_struct(_extras)) {
			struct_foreach(_extras, method(_struct, function(_name, _value) { /* Feather ignore once GM1041 */struct_set(self, _name, _value) }));
		}
		
		var _root_logger = is_undefined(self.__root_logger) ? self : self.__root_logger;
		var _new_logger = new Logger(_name, _struct, /* Feather ignore once GM1041 */_root_logger);
		_new_logger.set_level(self.__minimum_log_level);
		
		if (!is_undefined(self.__sentry)) {
			_new_logger.use_sentry(self.__sentry, self.__sentry_send_errors);
		}
		
		return _new_logger;
	};
	
	/** Create a child loger from this loger instance, but with the same logger name
	 * @param {Struct} _extras Any key/values to bind to the child logger
	 */
	static bind = function(_extras) {
		// create a new logger instance with extra bindings, but same name
		return self.bind_named(self.__name, _extras);
	};
	
	/** Sets the logging level of this logger instance. Any logs with severity lower than the minimum log level will be silenced
	 * @param {String} _minimum_log_level The minimum severity level for logs that this logger instance will output
	 */
	static set_level = function(_minimum_log_level=Logger.DEBUG) {
		self.__minimum_log_level = _minimum_log_level;
		self.__enable_fatal = false
		self.__enable_error = false;
		self.__enable_warning = false;
		self.__enable_info = false;
		self.__enable_debug = false;
		switch(_minimum_log_level) {
			default:
			case Logger.DEBUG: self.__enable_debug = true;
			case Logger.INFO: self.__enable_info = true;
			case Logger.WARNING: self.__enable_warning = true;
			case Logger.ERROR: self.__enable_error = true;
			case Logger.FATAL: self.__enable_fatal = true;
		}
		return self;
	};
	
	/** When file logging is enabled, explicitly flush the log to file */
	static flush_to_file = function() {
		// Flush pending log messages to file
		if (!self.__global_logging_enabled) return;
		if (self.__file_handle != -1) {
			file_text_close(self.__file_handle);
			self.__file_handle = file_text_open_append(self.__filename);
		}
	};
	
	/** Enables logging to file
	 * @param {String} _filename Name of the file to log to
	 * @param {Bool} _auto_flush Automatically flush the file after every log. This is quite an expensive operation
	 */
	static log_to_file = function(_filename, _auto_flush=false) {
		// Configure this logger to log to file
		if (!self.__global_logging_enabled) return;
		self.close_log()
		
		self.__filename =_filename
		self.__auto_flush = _auto_flush;
		
		if (is_undefined(self.__filename)) {
			self.__filename = self.__generate_log_filename();	
		}
		
		self.__file_handle = file_text_open_append(self.__filename);
		if (self.__file_handle == -1) {
			throw "Could not create log file";	
		}
		return self;
	};
	
	/** Close the file log */
	static close_log = function() {
		// Explicitly close the log
		if (!self.__global_logging_enabled) return;
		if (self.__file_handle != -1) {
			file_text_close(self.__file_handle);
		}
	};
	
	/** Enables Sentry for this logging instance
	 * @param {Struct.Sentry} _sentry The Sentry instance to use
	 * @param {Bool} _sentry_send_errors Whether to automatically send error-level logs to Sentry as reports
	 */
	static use_sentry = function(_sentry, _sentry_send_errors=false) {
		// Attach a sentry instance to logger, to automatically add breadcrumbs
		// and optionally automatically send to sentry on errors
		self.__sentry = _sentry;
		self.__sentry_send_errors = _sentry_send_errors;
		return self;
	};
	
	/** Internal function for actually doing the logging
	 * @param {String} _level The log level to report at
	 * @param {String} _message The log message
	 * @param {Struct} _extras Any key/values to include in the log message
	 * @param {String} _type Optional log type (used for Sentry breadcrumbs)
	 * @param {Array<String>} _stacktrace Optional stacktrace to include
	 * @ignore
	 */
	static __log = function(_level, _message, _extras=undefined, _type=undefined, _stacktrace=undefined) {
		// Create a log message
		
		if (!self.__global_logging_enabled) return;
		
		if (!(_level == Logger.FATAL and self.__enable_fatal) and 
			!(_level == Logger.ERROR and self.__enable_error) and
			!(_level == Logger.WARNING and self.__enable_warning) and
			!(_level == Logger.INFO and self.__enable_info) and
			!(_level == Logger.DEBUG and self.__enable_debug)){
			return;
		}

		// copy bound values
		var _combined = variable_clone(self.__bound_values);
		
		// add Type
		if (!is_undefined(_type)) {
			_combined[$ "type"] = _type
		}
		
		// copy in the extras
		if (is_struct(_extras)) {
			struct_foreach(_extras, method(_combined, function(_name, _value) { /* Feather ignore once GM1041 */ struct_set(self, _name, _value) }));
		}

		var _output
		if (self.__global_json_logging) {
			var _struct = {
				logName: self.__name,
				times: self.__datetime_string_iso(),
				severity: string_upper(_level),
				message: string(_message),
				extras: _combined,
			}
			if (!is_undefined(_stacktrace)) {
				_struct[$ "stacktrace"] = _stacktrace
			}
			_output = json_stringify(_struct);
		}
		else {
			if (!is_undefined(_stacktrace)) {
				_combined[$ "stacktrace"] = _stacktrace;
			}
			
			var _level_str;
			switch(_level) {
				case Logger.FATAL:		_level_str = "fatal  "; break;
				case Logger.ERROR:		_level_str = "error  "; break;
				case Logger.WARNING:	_level_str = "warning"; break;
				case Logger.INFO:		_level_str = "info   "; break;
				case Logger.DEBUG:		_level_str = "debug  "; break;
				default:			_level_str = string(_level);
			}
			
			if (struct_names_count(_combined)) {
				_output = $"{self.__datetime_string()} [{_level_str}][{self.__string_pad(self.__name + "] " + string(_message), self.__pad_width)} {json_stringify(_combined)}";
			}
			else {
				_output = $"{self.__datetime_string()} [{_level_str}][{self.__name}] {_message}";
			}
		}

		show_debug_message(_output);
		self.__write_line_to_file(_output);
		
		if (!is_undefined(self.__sentry)) {
			if (self.__sentry_send_errors && _level == Logger.ERROR) {
				self.__sentry.send_report(_level, _message, undefined, undefined, self.__name, _combined, _stacktrace); 
			}
			else {
				if (is_undefined(_type)) {
					if (_level == Logger.FATAL || _level = Logger.ERROR || _level = Logger.WARNING) {
						_type = Logger.ERROR	
					}
					else if (_level == Logger.INFO || _level == Logger.DEBUG) {
						_type = _level
					}
					else {
						_type = "default";	
					}
				}
				self.__sentry.add_breadcrumb(self.__name, _message, _combined, _level, _type);
			}
		}
	};
	
	/** Internal function for actually writing output to file
	 * @param {String} _output The line of text to write
	 * @ignore
	 */
	static __write_line_to_file = function(_output) {
		if (self.__file_handle != -1) {
			file_text_write_string(self.__file_handle, _output);
			file_text_writeln(self.__file_handle);
			
			if (self.__auto_flush) {
				self.flush_to_file();
			}
		}
		else if (!is_undefined(self.__root_logger)) {
			// if I don't have a file handle, but have a root, and use grandparent's output
			self.__root_logger.__write_line_to_file(_output);
		}
	};
	
	/** Generate the log filename from the current time
	 * @return {String}
	 * @pure
	 * @ignore
	 */
	static __generate_log_filename = function() {
		var _datetime = date_current_datetime();	
		var _filename = $"log_{self.__date_string(_datetime, "")}{self.__time_string(_datetime, "")}.log";
		return _filename;
	};
	
	/** Pad the string with spaces to a given length
	 * @param {String} _str The string to pad
	 * @param {Real} _length Length of padding
	 * @pure
	 * @ignore
	 */
	static __string_pad = function(_str, _length) {
		var _spaces_to_add = _length - string_length(_str);
		
		while(_spaces_to_add >= 8)	{ _spaces_to_add -= 8; _str += "        "; }
		if (_spaces_to_add >= 4)	{ _spaces_to_add -= 4; _str += "    "; }
		if (_spaces_to_add >= 2)	{ _spaces_to_add -= 2; _str += "  "; }
		if (_spaces_to_add == 1)	{ _str += " "; }
		
		return _str;
	};
	
	/** Get a formatted datetime string
	 * @pure
	 * @ignore
	 */
	static __datetime_string = function() {
		var _datetime = date_current_datetime();
		return self.__date_string(_datetime) + " " + self.__time_string(_datetime);
	};
		
	/** Get a formatted datetime string in ISO date format
	 * @pure
	 * @ignore
	 */
	static __datetime_string_iso = function() {
		var _old_tz = date_get_timezone();
		date_set_timezone(timezone_utc);
		
		var _datetime = date_current_datetime();	
		var _str = self.__date_string(_datetime) + "T" + self.__time_string(_datetime) + "Z";
		date_set_timezone(_old_tz);
		return _str;
	};
	
	/** Get the formatted date
	 * @param {Real} _datetime The current datetime using Gamemaker's datetime format, e.g. date_current_datetime()
	 * @param {String} _separator The character to use as separator
	 * @pure
	 * @ignore
	 */
	static __date_string = function(_datetime, _separator="-") {
		var _str = string_format(date_get_year(_datetime), 4, 0) + _separator +
				    string_format(date_get_month(_datetime), 2, 0) + _separator +
				    string_format(date_get_day(_datetime), 2, 0) ;
		return string_replace_all(_str, " ", "0");
	};
	
	/** Get the formatted time
	 * @param {Real} _datetime The current datetime using Gamemaker's datetime format, e.g. date_current_datetime()
	 * @param {String} _separator The character to use as separator
	 * @pure
	 * @ignore
	 */
	static __time_string = function(_datetime, _separator=":") {
		var _str = string_format(date_get_hour(_datetime), 2, 0) + _separator +
				string_format(date_get_minute(_datetime), 2, 0) + _separator +
				string_format(date_get_second(_datetime), 2, 0);
		return string_replace_all(_str, " ", "0");
	};
	
	/// Feather ignore GM2017
	// Log severity levels. These match the sentry level macros. so are interchangeable
	static FATAL = "fatal"
	static ERROR = "error"
	static WARNING = "warning"
	static INFO = "info"
	static DEBUG = "debug"

	// Log types. These match the sentry breadcrumb types
	static TYPE_DEFAULT = "default"
	static TYPE_ERROR = "error"
	static TYPE_INFO = "info"
	static TYPE_DEBUG = "debug"
	static TYPE_NAVIGATION = "navigation"
	static TYPE_HTTP = "http"
	static TYPE_QUERY = "query"
	static TYPE_TRANSACTION = "transaction"
	static TYPE_UI = "ui"
	static TYPE_USER = "user"
}

/** A quick debugging function that is an alias for the root logger's debug() output
 * @param {Any} _message The message or data to send
 * @param {Struct} _extras Optional extra data to send
 */
function trace(_message, _extras=undefined) {
	LOGGER.debug(_message, _extras);
}