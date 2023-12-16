/** Sentry logging, it is able to submit automated bug reports to Sentry.io
 * @param {String} _dsn The DSN for this project
 * @author Meseta https://meseta.dev
 */
function Sentry(_dsn="") constructor {
	/* @ignore */ self.__public_key = "";
	/* @ignore */ self.__secret_key = "";
	/* @ignore */ self.__endpoint = "";
	
	/* @ignore */ self.__tags = {};
	/* @ignore */ self.__breadcrumbs = []
	/* @ignore */ self.__user = undefined;
	/* @ignore */ self.__options = {
		breadcrumbs_max: 100,
		backup_before_send: true,
		backup_autoclean: true,
		backup_path: "",
		show_popup: true,
		ask_to_send: true,
		ask_to_send_report: true,
		error_message: "Sorry, an error occurred and the game had to close\r\r",
		show_stacktrace: true,
		separator: "______________________________________________________________________\r\r",
		question: "Would you like to submit this error as a bug report?",
		thanks: "Bug report submitted, thanks!",
		newline: "\r",
		include_parameters: false,
		include_device_hash: false,
	}
	/* @ignore */ self.__requests = {};
	/* @ignore */ self.__sentry_handled = false;
	/* @ignore */ self.__enable_send = false;
	/* @ignore */ static __sentry_log_file_prefix = "sentry_";
	/* @ignore */ static __version = "1.1.0";
	
	// This global facilitates loose coupling between exceptions and sentry
	global.sentry_last_exception = {message: "", stacktrace: []};
	
	if (is_string(_dsn)) {
		self.set_dsn(_dsn);	
	}
	
	/** Set the sentry DSN
	 * @param {String} _dsn The DSN in the format `https://<code>.ingest.setnry.io/<project_id>
	 */
	static set_dsn = function(_dsn) {
		var _prot_pos = string_pos("://", _dsn);
		if (_prot_pos == 0) {
			throw new SentryException("Malformed DSN, no protocol found");
		}
	
		var _at_pos = string_pos("@", _dsn)
		if (_at_pos == 0) {
			throw new SentryException("Malformed DSN, no @ found");
		}
	
		var _dsn_prot = string_copy(_dsn, 1, _prot_pos-1);
	
		var _at_pre = string_copy(_dsn, _prot_pos+3, _at_pos-_prot_pos-3);
		var _key_pos = string_pos(":", _at_pre);
		var _public_key = _at_pre;
		var _secret_key = "";
		
		if (_key_pos) {
			_secret_key = string_copy(_at_pre, _key_pos+1, string_length(_at_pre)-_key_pos);
			_public_key = string_copy(_at_pre, 1, _key_pos-1);
		}
	
		if (string_length(_public_key) == 0) {
			throw new SentryException("Malformed DSN, no public key found");
		}
	
		var _at_post = string_copy(_dsn, _at_pos+1, string_length(_dsn)-_at_pos);
		var _slash_pos = 1;
		for (var _next_pos=1; _next_pos != 0; _slash_pos+=_next_pos) {
			_next_pos = string_pos("/", string_copy(_at_post, _slash_pos, string_length(_at_post)-_slash_pos));
		}
	
		var _dsn_host_path = string_copy(_at_post, 1, _slash_pos-2);
	
		if (string_length(_dsn_host_path) == 0) {
			throw new SentryException("Malformed DSN, no host/path found");
		}
	
		var _dsn_project = string_copy(_at_post, _slash_pos, string_length(_at_post)-_slash_pos+1);
	
		if (string_length(_dsn_project) == 0) {
			throw new SentryException("Malformed DSN, no project found");
		}
	
		self.__endpoint = _dsn_prot + "://" + _dsn_host_path + "/api/" + _dsn_project + "/store/";
		self.__secret_key = _secret_key;
		self.__public_key = _public_key;
		self.__enable_send = true;
	}
	
	/** Add a tag to this Sentry instance, the tag is included in all reports
	 * @param {String} _key The tag key
	 * @param {String} _value The tag value
	 */
	static add_tag = function(_key, _value) {
		// Add a custom tag to sentry
		self.__tags[$ _key] = _value;
	}
	
	/** Remove a tag from this Sentry instance
	 * @param {String} _key The tag key
	 */
	static remove_tag = function(_key) {
		if (struct_exists(self.__tags, _key)) {
			struct_remove(self.__tags, _key);
		}
	}
	
	/** Add a breadcrumb to keep track of. Breadcrumbs are included with any sentry report
	 * @param {String} _category The category of the breadcrumb
	 * @param {String} _message The log message
	 * @param {Struct} _extras Any extra structured data to include
	 * @param {String} _level The log level. Supports the same values as Logger.DEBUG and friends
	 * @param {String} _type The log type. Suppors the same values as Logger.TYPE_HTTP and friends
	 */
	static add_breadcrumb = function(_category, _message, _extras=undefined, _level="debug", _type="default") {
		var _struct = {
			type: _type,
			category: _category,
			timestamp: __unix_timestamp(),
			level: _level,
			message: _message,
		}
		if (! is_undefined(_extras)) {
			_struct[$ "data"] = _extras;
		}
		array_push(self.__breadcrumbs, _struct);
		
		// trim to length
		if (array_length(self.__breadcrumbs) > self.__options.breadcrumbs_max) {
			array_delete(self.__breadcrumbs, 0, 1);	
		}
	}
	
	/** Sets the current user ID to be included in sentry reports. All params are optional
	 * @param {String} _id User ID
	 * @param {String} _email User's email
	 * @param {Struct} _username User's username
	 * @param {Struct} _extras Any extra key/values to include
	 */
	static set_user = function(_id=undefined, _email=undefined, _username=undefined, _extras=undefined) {
		self.__user = is_struct(_extras) ? variable_clone(_extras) : {};
		
		if (not is_undefined(_id)) {
			self.__user.id = _id;
		}
		if (not is_undefined(_email)) {
			self.__user.email = _email;
		}
		if (not is_undefined(_username)) {
			self.__user.username = _username;
		}
	}
	
	/** Clears the current user ID */
	static clear_user = function() {
		self.__user = undefined;
	}
	
	/** Sets extra options for sentry. See definition of self.__options for valid options
	 * @param {String} _option The option to set
	 * @param {Any} _value
	 */
	static set_option = function(_option, _value) {
		if (struct_exists(self.__options, _option)) {
			self.__options[$ _option] = _value;
		}
		else {
			throw new SentryException("You tried to set sentry option " + string(_option) + " but this does not exist");
		}
	}
	
	/** Send a report to Sentry
	 * @param {String} _level The log level
	 * @param {String} _message The log message
	 * @param {Function} _callback Callback to run when send is successful
	 * @param {Function} _errback Callback to run when send fails
	 * @param {String} _logger The Logger name
	 * @param {Struct} _extras Any extra struct data
	 * @param {Array} _raw_stacktrace The raw stacktrace to include in the report
	 */
	static send_report = function(_level, _message, _callback=undefined, _errback=undefined, _logger="gmsentry", _extras=undefined, _raw_stacktrace=undefined) {
		// Send a request to sentry
		if (is_undefined(_raw_stacktrace)) {
			_raw_stacktrace = debug_get_callstack();
			array_delete(_raw_stacktrace, 0, 1);
		}
		var _stacktrace = self.__format_stacktrace(_raw_stacktrace);
		var _payload = self.__create_payload(_level, _message, _stacktrace, _extras, _logger);
		var _send = self.__show_popup_and_send_confirmation(_message, _stacktrace, true)
		if (_send) {
			self.__save_and_send(_payload, _callback, _errback, true);
		}
	}
	
	/** Returns the bound exception handler
	 * @return {function}
	 */
	static get_exception_handler = function() {
		return method(self, self.exception_handler);	
	}
	
	/** The exception handler which can be registered as the global unhandled exception handler
	 * @param {Struct} _err The Exception struct
	 */
	static exception_handler = function(_err) {
		show_debug_message("Sentry handling error");
		
		// try to detect our own custom exceptions
		if (self.__sentry_handled) {
			// avoid getting stuck in a crash loop in HTML5
			return;
		}
		self.__sentry_handled = true;
		
		// special HTML5 handling
		if (!is_struct(_err) && !is_string(_err)) {
			var _message = string(_err);
			var _tracearray = debug_get_callstack();
			var _count = array_length(_tracearray);
			var _stacktrace = array_create(_count);
			for (var _i=0; _i<_count; _i++) {
				var _struct = {};
				var _func = _tracearray[_i];
				var _func_clean = _func;
				
				var _pos = string_pos("(", _func);
				if (_pos > 0) {
					_func_clean = string_copy(_func, 1, _pos-1);
				}
				_struct[$ "function"] = _func_clean;
				_struct[$ "context_line"] = _func;
				_stacktrace[_i] = _struct;
			}
		}
		else {
			var _msg = _err.message;
			if (string_pos("Unable to find a handler for exception ", _msg) == 1) {
				// split message into lines
				var _pos = string_pos_ext("\n", _msg, 39);
				if (_pos == 0) {
					_pos = string_pos_ext("\r", _msg, _pos);
				}
				var _line = string_copy(_msg, 40, (_pos>0?_pos: string_length(_msg))-40);
				if (_line == string(global.sentry_last_exception)) {
					var _message = string(global.sentry_last_exception);
					var _tracearray = global.sentry_last_exception.stacktrace;
				}
				else {
					var _message = _line;
					var _tracearray = _err.stacktrace;
				}
			}
			else {
				var _message = _err.message;
				var _tracearray = _err.stacktrace;
			}
			var _stacktrace = self.__format_stacktrace(_tracearray);
		}
	
		var _payload = self.__create_payload("error", _message, _stacktrace);
		var _send = self.__show_popup_and_send_confirmation(_message, _stacktrace)
		if (_send) {
			self.__save_and_send(_payload, undefined, undefined);
		}
	}
	
	/** Show the popup and send confirmation
	 * @param {String} _message The error message
	 * @param {Array} _stacktrace The stacktrace
	 * @param {Bool} _is_report Whether a report will be sent
	 * @return {Bool}
	 * @ignore
	 */
	static __show_popup_and_send_confirmation = function(_message, _stacktrace, _is_report=false) {
		var _trace_lines = ""
		var _len = array_length(_stacktrace);
		for (var _i=0; _i<_len; _i++) {
			var _line = _stacktrace[_i];
			if (variable_struct_exists(_line, "function") && _line[$ "function"] != 0) {
				_trace_lines += string(self.__options.newline) + string(_line[$ "function"]);
				if (is_numeric(_line[$ "lineno"]) and _line.lineno != -1) {
					_trace_lines += " (line " + string(_line.lineno) + ")";
				}
				if (is_string(_line[$ "context_line"])) {
					_trace_lines += " - " + _line.context_line;
				}
			}
		}

		var _popup = self.__options.error_message + _message;
			
		if (self.__options.show_stacktrace) {
			_popup = self.__options.separator +
					self.__options.newline + _popup + self.__options.newline + self.__options.newline +
					self.__options.separator +
					"STACKTRACE:" + _trace_lines;
		}
			
		show_debug_message(_popup);
		
		var _send = true;
		if ((self.__options.ask_to_send && !_is_report) || (self.__options.ask_to_send_report && _is_report)) {
			_send = show_question(_popup +
						self.__options.newline +
						self.__options.newline +
						self.__options.question + 
						self.__options.newline);
		}
		else if (self.__options.show_popup) {
			show_message(_popup);
		}
		return _send;
	}
		
	/** Save the report, and send it
	 * @param {Struct} _payload The struct payload
	 * @param {Function} _callback callback to run on success
	 * @param {Function} _errback callback to run on error
	 * @param {Bool} _is_report Whether this is a report
	 * @ignore
	 */
	static __save_and_send = function(_payload, _callback, _errback, _is_report=false) {
		var _async_id = -1;
		
		var _compress = self.__compress_payload(_payload);
		
		if (self.__options.backup_before_send) {
			var _filename = self.__options.backup_path + self.__sentry_log_file_prefix + string(_payload.event_id);
			buffer_save(_compress, _filename);
		}
		
		if (self.__enable_send) {
			_async_id = self.__sentry_request(_compress);
			self.__requests[$ string(_async_id)] = {
				uuid: _payload.event_id,
				callback: _callback,
				errback: _errback,
			};
			
			if ((self.__options.ask_to_send && !_is_report) || (self.__options.ask_to_send_report && _is_report)) {
				show_message(self.__options.thanks);
			}
		}
		buffer_delete(_compress);
	}

	/** Make the sentry request
	 * @param {Id.Buffer} _buffer The Buffer to use
	 * @param {Real}
	 * @ignore
	 */
	static __sentry_request = function(_buffer) {
		var _x_auth = "Sentry sentry_version=7," +
			        " sentry_client="+ game_project_name + "/" + GM_version + "," +
		 			" sentry_timestamp=" + string(self.__unix_timestamp()) + "," +
					" sentry_key=" + self.__public_key;
				 
		if (not is_undefined(self.__secret_key) && self.__secret_key != "") {
			_x_auth += ", sentry_secret=" + self.__secret_key;
		}
	
		var _headers = ds_map_create();
		ds_map_add(_headers, "Content-Type", "application/json");
		ds_map_add(_headers, "Content-Encoding", "deflate");
		ds_map_add(_headers, "X-Sentry-Auth", _x_auth);
		
		var _async_id = http_request(self.__endpoint, "POST", _headers, _buffer);
		show_debug_message("Sent sentry request to "+ string(self.__endpoint))
		AsyncWrapper.add_async_http_callback(method(self, self.__handle_async_load));	

		ds_map_destroy(_headers);
		return _async_id;
	}

	/** Make the sentry payload
	 * @param {String} _level The log level
	 * @param {String} _message The log message
	 * @param {Array<String>*} _stacktrace The stacktrace to include in the report
	 * @param {Struct} _extras Any extra struct data
	 * @param {String} _logger The Logger name
	 * @return {Struct}
	 * @ignore
	 */
	static __create_payload = function(_level, _message, _stacktrace=undefined, _extras=undefined, _logger="gmsentry") {
		self.__tags.device_string = self.__system_string();
		
		var _payload = {
			level: _level,
			logger: _logger,
			event_id: __uuid4(),
			timestamp: __unix_timestamp(),
			platform: "other",
			release: string_replace_all(game_display_name, " ", "-") + "@" + GM_version,
			tags: __tags,
			sdk: {
				name: "GMSentry",
				version: self.__version,
			},
			breadcrumbs: {
				values: self.__breadcrumbs
			},
			contexts: {
				device: {
					os_device_: os_device,
				},
				os: {
					name: self.__os_string(),
					version: self.__os_version_string(),
					os_type_: os_type,
					os_version_: os_version,
					os_is_paused_: os_is_paused(),
					os_is_network_connected_: os_is_network_connected(),
					os_get_language_: os_get_language(),
					os_get_region_: os_get_region(),
				},
				runtime: {
					name: "GameMaker Studio",
					version: GM_runtime_version,
				},
				app: {
					app_start_time: self.__datetime_string(date_current_datetime() - current_time/86400000),
					build_type: os_get_config(),
					code_is_compiled_: code_is_compiled(),
					app_name: game_display_name,
					app_version: GM_version,
					debug_mode_: debug_mode,
					app_build: __datetime_string(GM_build_date),
				},
			},
		}
		
		if (self.__options.include_parameters) {
			_payload.contexts.app.parameters = []
			for (var _i=0; _i<parameter_count(); _i++) {
				array_push(_payload.contexts.app.parameters, parameter_string(_i));
			}
		}
		
		if (self.__options.include_device_hash) {
			_payload.contexts.app.device_app_hash = self.__device_hash();
		}
		
		if (!is_undefined(self.__user)) {
			_payload.user = self.__user;	
		}
		
		if (os_browser != browser_not_a_browser) {
			_payload.contexts.browser = {
				name: self.__browser_string(),
			};	
		}
		
		_payload[$ "sentry.interfaces.Message"] = {
			formatted: _message,
		};
		
		if (not is_undefined(_stacktrace)) {
			_payload.stacktrace = {
				frames: array_reverse(_stacktrace) // sentry stacktraces are reversed
			};
		}
		
		if (not is_undefined(_extras)) {
			_payload.extra = _extras;
		}
		
		return _payload;
	}
	
	/** Formats a stacktrace into Frames
	 * @param {Array} _stacktrace The stacktrace to format
	 * @return {Array<Struct>}
	 * @pure
	 * @ignore
	 */
	static __format_stacktrace = function(_stacktrace) {
		// Turns an array from GM's stacktrace into a sentry frames array
		var _frames = [];
		var _len = array_length(_stacktrace);
		for (var _i=0; _i<_len; _i++) {
			var _entry = _stacktrace[_i];
			
			if (not is_string(_entry)) {
				continue;
			}
			var _struct = {}

			// bracket separated?
			var _pos = string_pos(" (line ", _entry);
			if (_pos > 0) {
				var _line_end = string_delete(_entry, 1, _pos + 6);
				var _pos2 = string_pos(")", _line_end);
				var _lineno = string_copy(_line_end, 1, _pos2-1);
				
				if (string_digits(_lineno) == _lineno) {
					_struct[$ "function"]  = string_copy(_entry, 1, _pos-1);
					_struct[$ "lineno"] = real(_lineno);
					var _context_line = string_trim(string_delete(_line_end, 1, _pos2+3));
					if (string_length(_context_line)) {
						_struct[$ "context_line"] = _context_line;
					}
					array_push(_frames, _struct);
					continue;
				}
			}
			
			var _pos = string_last_pos(":", _entry);
			if (_pos > 0) {
				var _lineno = string_delete(_entry, 1, _pos);
				
				if (string_digits(_lineno) == _lineno && _lineno != "") {
					_struct[$ "function"] = string_copy(_entry, 1, _pos-1);
					_struct[$ "lineno"] = real(_lineno);
					array_push(_frames, _struct);
					continue;
				}
			}
			
			// no line number
			_struct[$ "function"] = _entry;
			array_push(_frames, _struct);
		}
		
		// Sentry stacktrace is reversed
		return _frames;
	}
	
	/** Async handler for when a request is successful
	 * @param {Id.DsMap} _async_load the asyng_load ds_map
	 * @ignore
	 */
	static __handle_async_load = function(_async_load) {
		var _async_id = _async_load[? "id"]
		var _request = self.__requests[$ string(_async_id)];

		if (not is_undefined(_request)) {
			var _status = _async_load[? "status"];
			var _http_status = _async_load[? "http_status"];
			var _async_result = _async_load[? "result"];
	
			// check status
			if (_http_status == 200) { // success
				if (is_method(_request.callback)) {
					_request.callback(_request.uuid, _async_result);
				}
				variable_struct_remove(__requests, string(_async_id));
				show_debug_message("Sentry request succeeded");
		
				if (self.__options.backup_autoclean) {
					var _filename = self.__options.backup_path + __sentry_log_file_prefix + string(_request.uuid);
					if (file_exists(_filename)) {
						file_delete(_filename);
						show_debug_message("Sentry backup file no longer needed and deleted: "+_filename);
					}
				}
			}
			else if (_status == 1) { // downloading
				// don't need to do anything
			}
			else { // falure
				show_debug_message("Sentry request failed! No error log could be submitted")
				show_debug_message(json_encode(_async_load))
				if (is_method(_request.errback)) {
					_request.errback(_request.uuid, _http_status, _async_result);
				}
				variable_struct_remove(_request, string(_async_id));
			}
		}
	}
	
	/** Compresses a structinto a buffer
	 * @param {Struct} _payload The struct to compress
	 * @return {Id.Buffer}
	 * @ignore
	 */
	static __compress_payload = function(_payload) {
		var _json = json_stringify(_payload);
		var _buff = buffer_create(string_byte_length(_json), buffer_fixed, 1);
		buffer_write(_buff, buffer_text, _json);
		var _compress = buffer_compress(_buff, 0, buffer_tell(_buff));
		buffer_delete(_buff);
		
		return _compress;
	}
	
	/** Generate a Formatted timestamp string
	 * @return {String}
	 * @ignore
	 */
	static __datetime_string = function(_datetime=undefined) {
		if (is_undefined(_datetime)) {
			_datetime = date_current_datetime();	
		}
		
		var _old_tz = date_get_timezone();
		date_set_timezone(timezone_utc);

		var _str = string_format(date_get_year(_datetime), 4, 0) + "-" +
		            string_format(date_get_month(_datetime), 2, 0) + "-" +
		            string_format(date_get_day(_datetime), 2, 0) + "T" +
		            string_format(date_get_hour(_datetime), 2, 0) + ":" +
		            string_format(date_get_minute(_datetime), 2, 0) + ":" +
		            string_format(date_get_second(_datetime), 2, 0)
		_str = string_replace_all(_str, " ", "0");
		date_set_timezone(_old_tz);
		return _str;
		
	}
	
	/** Generate a Unix timestamp
	 * @return {Number}
	 * @ignore
	 */
	static __unix_timestamp = function() {
		// Return current unix timestamp
		var _old_tz = date_get_timezone();
		date_set_timezone(timezone_utc);
		var _timestamp = floor((date_current_datetime() - 25569) * 86400);
		date_set_timezone(_old_tz);
		return _timestamp;
	}
	
	/** Generate a UUID4
	 * @return {String}
	 * @ignore
	 */
	static __uuid4 = function() {
		// Generate UUID4. We cheat and use md5 of the current time
		var _uuid = md5_string_utf8(string(date_current_datetime()) + string(get_timer()));
		_uuid = string_set_byte_at(_uuid, 13, ord("4"));
		_uuid = string_set_byte_at(_uuid, 17, ord(choose("8", "9", "a", "b")));
		return _uuid;	
	}
	
	
	/** Returns the the OS vesion
	 * @return {String}
	 * @ignore
	 */
	static __os_string = function() {
		switch (os_type) {
			case os_windows:
			case os_uwp:
				return "Windows";
			case os_operagx:
				return "OperaGX";
			case os_linux: return "Linux";
			case os_macosx:
				return "Mac OS X";
			case os_ios:
				return "iOS";
			case os_tvos:
				return "tvOS";
			case os_android:
				return "Android";
			case os_ps4: return "PlayStation 4";
			case os_ps5: return "PlayStation 5";
			case os_xboxone: return "XBox One";
			case os_xboxseriesxs: return "XBox Series X/S";
			case os_switch: return "Switch";
			default: return "Unknown"
		}	
	}
		
	/** Returns the the OS vesion
	 * @return {String}
	 * @ignore
	 */
	static __os_version_string = function() {
		switch (os_type) {
			case os_windows:
			case os_uwp:
				switch (os_version) {
					case 327680: return "2000";
					case 327681:
					case 237862:
						return "XP";
					case 393216: return "Vista";
					case 393217: return "7";
					case 393218: return "8";
					case 393219: return "8.1";
					case 655360: return "10";
					case 720896: return "11";
				}
				break;
			case os_macosx:
			case os_ios:
				var _major = os_version >> 24;
				var _minor = (os_version >> 12) & 0xfff;
				return string(_major) + "." + string(_minor)
			case os_android:
				switch (os_version) {
					case 21:
					case 22:
						return "Lollipop";
					case 23: return "Marshmallow";
					case 24:
					case 25:
						return "Nougat";
					case 26:
					case 27:
						return "Oreo";
					case 28: return "Pie";
					case 29: return "X";
				}
				break;
		}
		return "Unknown"	
	}
	
	/** Returns the string form of the browser
	 * @return {String*}
	 * @ignore
	 */
	static __browser_string = function() {
		switch (os_browser) {
			case browser_not_a_browser: return undefined;
			case browser_ie:
			case browser_ie_mobile:
				return "Internet Explorer";
			case browser_edge: return "Edge";
			case browser_firefox: return "Firefox";
			case browser_chrome: return "Chrome";
			case browser_safari: return "Safari";
			case browser_safari_mobile: return "Safari Mobile";
			case browser_opera: return "Opera";
			case browser_tizen: return "Tizen";
			case browser_windows_store: return "Windows App";
			default: return "Unknown Browser";
		}
	}
	
	/** Returns the string form of the system
	 * @return {String}
	 * @ignore
	 */
	static __system_string = function() {
		if (os_browser == browser_not_a_browser) {
			return self.__os_string() + " " + self.__os_version_string();
		}
		else {
			return self.__browser_string();
		}
	}
	
	/** Creates a unique device hash, using one of a variety of methods
	 * @return {String}
	 * @ignore
	 */
	static __device_hash = function() {
		var _empty = ds_map_create();
		ds_map_secure_save(_empty, "sentry_device_hash");
		ds_map_destroy(_empty);
		var _hash = md5_file("sentry_device_hash")
		file_delete("sentry_device_hash");
		return _hash;
	}
	
	
	/** Returns a list of reports that Sentry has generated
	 * @return {Array<String>}
	 */
	static list_all_backed_up_reports = function() {
		// return a list of saved files
		var _files = []
		var _file = file_find_first(self.__options.backup_path + self.__sentry_log_file_prefix + "*", 0);
		while (_file != "") {
			array_push(_files, _file);
			_file = file_find_next();
		}
		file_find_close();
		return _files;
	}
	
	/** Deletes all the saved reports */
	static delete_all_backed_up_reports = function() {
		// deletes all saved files
		var _files = self.list_all_backed_up_reports();
		array_foreach(_files, function(_file) { file_delete(_file); });
	}
	
	
	/** Send a saved report
	 * @param {String} _file The file name
	 * @param {Function} _callback The function to run when successful
	 * @param {String} _errback The function to run when failed
	*/
	static send_backed_up_report = function(_file, _callback=undefined, _errback=undefined) {
		// send a single backed up report
		if (file_exists(_file) && self.__enable_send) {
			var _uuid4 = string_copy(_file, string_length(_file)-31, 32);
		
			if (string_length(_uuid4) == 32) {
				var _buff = buffer_load(_file);
				var _async_id = self.__sentry_request(_buff);
				self.__requests[$ string(_async_id)] = {
					uuid: _uuid4,
					callback: _callback,
					errback: _errback,
				};
				buffer_delete(_buff);
			}
		}
	}
	
	/** Send all the saved reports
	 * @param {Function} _callback The function to run when EACH FILE is successful
	 * @param {Function} _errback The function to run when EACH FILE failed
	*/
	static send_all_backed_up_reports = function(_callback=undefined, _errback=undefined) {
		// send all backed up reports
		var _files = self.list_all_backed_up_reports();
		var _len = array_length(_files);
		for(var _i=0; _i<_len; _i++) {
			var _file = _files[_i];
			self.send_backed_up_report(_file, _callback, _errback);
		}
		return _len;
	}
}

// Sentry setup exception
function SentryException(_message): Exception(_message) constructor {};