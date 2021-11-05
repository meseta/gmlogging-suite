function Sentry(_dsn="") constructor {
	__enable_send = false;
	try {
		// parse DSN
		var _prot_pos = string_pos("://", _dsn);
		if (_prot_pos == 0) {
			throw "Malformed DSN, no protocol found";
		}
	
		var _at_pos = string_pos("@", _dsn)
		if (_at_pos == 0) {
			throw "Malformed DSN, no @ found";
		}
	
		var _dsn_prot = string_copy(_dsn, 1, _prot_pos-1);
	
		var _at_pre = string_copy(_dsn, _prot_pos+3, _at_pos-_prot_pos-3);
		var keyPos = string_pos(":", _at_pre);
		if (keyPos) {
			__dsn_public_key = string_copy(_at_pre, 1, keyPos-1);
			__dsn_secret_key = string_copy(_at_pre, keyPos+1, string_length(_at_pre)-keyPos);
		}
		else {
			__dsn_public_key = _at_pre;
			__dsn_secret_key = "";
		}
	
		if (string_length(__dsn_public_key) == 0) {
			throw "Malformed DSN, no public key found";
		}
	
		var _at_post = string_copy(_dsn, _at_pos+1, string_length(_dsn)-_at_pos);
		for (var _next_pos = 1, _slash_pos = 1; _next_pos != 0; _slash_pos += _next_pos) {
			_next_pos = string_pos("/", string_copy(_at_post, _slash_pos, string_length(_at_post)-_slash_pos));
		}
	
		var _dsn_host_path = string_copy(_at_post, 1, _slash_pos-2);
	
		if (string_length(_dsn_host_path) == 0) {
			throw "Malformed DSN, no host/path found";
			return false;
		}
	
		var _dsn_project = string_copy(_at_post, _slash_pos, string_length(_at_post)-_slash_pos+1);
	
		if (string_length(_dsn_project) == 0) {
			throw "Malformed DSN, no project found";
		}
	
		__endpoint = _dsn_prot + "://" + _dsn_host_path + "/api/" + _dsn_project + "/store/";
		__enable_send = true;
	}
	catch (_err) {
		show_debug_message(_err);
		if (is_string(_err) and SENTRY_WARN_WHEN_NO_DSN) {
			var _err_msg = "Sentry does not have a valid DSN. See output console for details. Either provide a DSN, or set SENTRY_WARN_WHEN_NO_DSN to false to surpress this warning";
			show_debug_message(_err_msg);
			show_error(_err_msg, false);
		}
	}
	
	__tags = {};
	__breadcrumbs = []
	__user = undefined;
	__options = {
		breadcrumbs_max: 100,
		backup_before_send: true,
		backup_autoclean: true,
		backup_path: "",
		show_popup: true,
		ask_to_send: true,
		error_message: "Sorry, an error occured and the game had to close\r\r",
		show_stacktrace: true,
		separator: "______________________________________________________________________",
		question: "Would you like to submit this error as a bug report?",
		thanks: "Bug report submitted, thanks!",
		newline: "\r",
	}
	__requests = {};
	__instance = noone;
	static SENTRY_LOG_FILE_PREFIX = "sentry_";
	
	add_tag = function(_key, _value) {
		// Add a custom tag to sentry
		__tags[$ _key] = _value;
	}
	remove_tag = function(_key) {
		// Remove a custom tag to sentry
		if (variable_struct_exists(__tags, _key)) {
			variable_struct_remove(__tags, _key);
		}
	}
	
	add_breadcrumb = function(_category, _message, _data=undefined, _level=LEVEL_DEBUG, _type="default") {
		// Add a breadcrumb to sentry
		var _struct = {
			type: _type,
			category: _category,
			timestamp: __unix_timestamp(),
			level: _level,
			message: _message,
		}
		if (not is_undefined(_data)) {
			_struct[$ "data"] = _data;
		}
		array_push(__breadcrumbs, _struct);
		
		// trim to length
		if (array_length(__breadcrumbs) > __options.breadcrumbs_max) {
			array_delete(__breadcrumbs, 0, 1);	
		}
	}
	
	set_user = function(_id=undefined, _email=undefined, _username=undefined, _extras=undefined) {
		__user = {}
		if (not is_undefined(_id)) {
			__user[$ "id"] = _id;
		}
		if (not is_undefined(_email)) {
			__user[$ "email"] = _email;
		}
		if (not is_undefined(_username)) {
			__user[$ "username"] = _username;
		}
		
		if (is_struct(_extras)) {
			var _keys = variable_struct_get_names(_extras);
			var _len = array_length(_keys);
			for (var _i=0; _i<_len; _i++) {
				var _key = _keys[_i];
				__user[$ _key] = _extras[$ _key];
			}
		}
	}
	
	clear_user = function() {
		__user = undefined;
	}
	
	set_option = function(_option, _value) {
		if (variable_struct_exists(__options, _option)) {
			__options[$ _option] = _value;
		}
		else {
			show_error("You tried to set sentry option " + string(_option) + " but this does not exist", true);
		}
	}
	
	send_report = function(_level, _message, _callback=undefined, _errorback=undefined, _logger="gmsentry", _extras=undefined, _raw_stacktrace=undefined) {
		// Send a request to sentry
		if (is_undefined(_raw_stacktrace)) {
			_raw_stacktrace = debug_get_callstack();
			array_delete(_raw_stacktrace, 0, 1);
		}
		var _stacktrace = __format_stacktrace(_raw_stacktrace);
		var _payload = __create_payload(_level, _message, _stacktrace, _extras, _logger);
		var _send = __show_popup_and_send_confirmation(_message, _stacktrace)
		if (_send) {
			__save_and_send(_payload, _callback, _errorback);
		}
	}
	
	list_all_backed_up_reports = function() {
		// return a list of saved files
		var _files = []
		var _file = file_find_first(__options.backup_path + SENTRY_LOG_FILE_PREFIX + "*", 0);
		while (_file != "") {
			array_push(_files, _file);
			_file = file_find_next();
		}
		file_find_close();
		return _files;
	}
	
	delete_all_backed_up_reports = function() {
		// deletes all saved files
		var _files = list_all_backed_up_reports();
		var _len = array_length(_files);
		for(var _i=0; _i<_len; _i++) {
			var _file = _files[_i];
			file_delete(_file);
		}
	}
	
	send_backed_up_report = function(_file, _callback=undefined, _errorback=undefined) {
		// send a single backed up report
		if (file_exists(_file)) {
			var _uuid4 = string_copy(_file, string_length(_file)-31, 32);
		
			if (string_length(_uuid4) == 32) {
				var _buff = buffer_load(_file);
				if (__enable_send) {
					var _async_id = __sentry_request(_buff);
					__requests[$ string(_async_id)] = {
						uuid: _uuid4,
						callback: _callback,
						errorback: _errorback,
					};
				}
				buffer_delete(_buff);
			}
		}
	}
	
	send_all_backed_up_reports = function(_callback=undefined, _errorback=undefined) {
		// send all backed up reports
		var _files = list_all_backed_up_reports();
		var _len = array_length(_files);
		for(var _i=0; _i<_len; _i++) {
			var _file = _files[_i];
			send_backed_up_report(_file, _callback, _errorback);
		}
	}
	
	
	exception_handler = function(_err) {
		// try to detect our own custom exceptions
		var _msg = _err.message;
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
			var _trace_array = json_parse(array_pop(_lines));
		
			// jon the rest of the lines back up
			var _message = _lines[0];
			for (var _i=1; _i<_arrlen; _i++) {
				_message += __options.newline + _lines[_i];
			}
		}
		else {
			var _message = _err.message;
			var _trace_array = _err.stacktrace;
		}
		
		var _stacktrace = __format_stacktrace(_trace_array);
		var _payload = __create_payload(LEVEL_ERROR, _message, _stacktrace);
		var _send = __show_popup_and_send_confirmation(_message, _stacktrace)
		if (_send) {
			__save_and_send(_payload, undefined, undefined);
		}
	}
	
	__show_popup_and_send_confirmation = function(_message, _stacktrace) {
		var _trace_lines = ""
		var _len = array_length(_stacktrace);
		for (var _i=0; _i<_len; _i++) {
			var _line = _stacktrace[_i];
			_trace_lines += __options.newline + _line[$ "function"];
			if (is_numeric(_line.lineno)) {
				_trace_lines += " (line " + string(_line.lineno) + ")";
			}
		}

		var _popup = __options.error_message + _message;
			
		if (__options.show_stacktrace) {
			_popup = __options.separator + __options.newline + 
					__options.newline + 
					__options.newline + 
					_popup + __options.newline + __options.newline +
					__options.separator + __options.newline +
					__options.newline + 
					"STACKTRACE:" + _trace_lines;
		}
			
		show_debug_message(_popup);
		
		var _send = true;
		if (__options.ask_to_send) {
			_send = show_question(_popup +
								__options.newline +
								__options.newline +
								__options.question + 
								__options.newline);
		}
		else if (__options.show_popup) {
			show_message(_popup);
		}
		return _send;
	}
	
	__save_and_send = function(_payload, _callback, _errorback) {
		var _async_id = -1;
		
		var _compress = __compress_payload(_payload);
		
		if (__options.backup_before_send) {
			var _filename = __options.backup_path + SENTRY_LOG_FILE_PREFIX + _payload.event_id;
			buffer_save(_compress, _filename);
		}
		if (__enable_send) {
			_async_id = __sentry_request(_compress);
			__requests[$ string(_async_id)] = {
				uuid: _payload.event_id,
				callback: _callback,
				errorback: _errorback,
			};
			
			if (__options.ask_to_send) {
				show_message(__options.thanks);
			}
		}
		buffer_delete(_compress);
	}

	__compress_payload = function(__payload) {
		var _json = json_stringify(__payload);
		var _buff = buffer_create(string_byte_length(_json), buffer_fixed, 1);
		buffer_write(_buff, buffer_text, _json);
		var _compress = buffer_compress(_buff, 0, buffer_tell(_buff));
		buffer_delete(_buff);
		
		return _compress;
	}

	__sentry_request = function(_buffer) {
		var _x_auth = "Sentry sentry_version=7," +
			        " sentry_client="+ game_project_name + "/" + GM_version + "," +
		 			" sentry_timestamp=" + string(__unix_timestamp()) + "," +
					" sentry_key=" + __dsn_public_key;
				 
		if (not is_undefined(__dsn_secret_key)) {
			_x_auth += ", sentry_secret=" + __dsn_secret_key;
		}
	
		var _headers = ds_map_create();
		ds_map_add(_headers, "Content-Type", "application/json");
		ds_map_add(_headers, "Content-Encoding", "zlib");
		ds_map_add(_headers, "X-Sentry-Auth", _x_auth);
		
		var _async_id = http_request(__endpoint, "POST", _headers, buffer_base64_encode(_buffer, 0, buffer_get_size(_buffer)));
		show_debug_message("Sent sentry request")
		if (not instance_exists(__instance)) {
			__instance = instance_create_depth(0, 0, 0, obj_sentry_http_handler);
			__instance.handle_async_load = __handle_async_load;
		}
		ds_map_destroy(_headers);
	
		return _async_id;
	}

	__create_payload = function(_level, _message, _stacktrace=undefined, _extras=undefined, _logger="gmsentry") {

		__tags[$ "device_string"] = __system_string();
		
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
				version: SENTRY_LOGGING_SUITE_VERSION
			},
			breadcrumbs: {
				values:__breadcrumbs
			},
			contexts: {
				_device: {
					os_device_: os_device,
				},
				os: {
					name: __os_string(),
					version: __os_version_string(),
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
					app_start_time: __datetime_string(date_current_datetime() - current_time/86400000),
					build_type: os_get_config(),
					code_is_compiled_: code_is_compiled(),
					app_name: game_display_name,
					app_version: GM_version,
					debug_mode_: debug_mode,
					app_build: __datetime_string(GM_build_date),
				},
			},
		}
		
		if (SENTRY_USE_GAME_PARAMETERS) {
			_payload.contexts.app.parameters = []
			for (var _i=0; _i<parameter_count(); _i++) {
				array_push(_payload.contexts.app.parameters, parameter_string(_i));
			}
		}
		
		if (SENTRY_USE_DEVICE_HASH) {
			_payload.contexts.app.device_app_hash = __device_hash();
		}
		
		if (not is_undefined(__user)) {
			_payload[$ "user"] = __user;	
		}
		
		if (os_browser != browser_not_a_browser) {
			_payload[$ "browser"] = {
				name: __browser_string(),
			};	
		}
		
		_payload[$ "sentry.interfaces.Message"] = {
			formatted: _message,
		};
		
		if (not is_undefined(_stacktrace)) {
			_payload[$ "stacktrace"] = {
				frames: _stacktrace
			};
		}
		
		if (not is_undefined(_extras)) {
			_payload[$ "extra"] = _extras;
		}
		
		return _payload;
	}

	__format_stacktrace = function(_stacktrace) {
		// Turns an array from GM's stacktrace into a sentry frames array
		var _frames = [];
		var _len = array_length(_stacktrace);
		for (var _i=0; _i<_len; _i++) {
			var _entry = _stacktrace[_i];
			
			if (not is_string(_entry)) {
				continue;
			}
			var _struct = {}
			var _pos = string_pos(":", _entry);
			if (_pos > 0) {
				// : separated
				_struct[$ "function"] = string_copy(_entry, 1, _pos-1);
				_struct[$ "lineno"] = real(string_delete(_entry, 1, _pos));
			}
			else {
				// bracket separated
				var _pos = string_pos(" (line ", _entry);
				if (_pos > 0) {
					_struct[$ "function"]  = string_copy(_entry, 1, _pos-1);
					_struct[$ "lineno"] = real(string_delete(_entry, 1, _pos + 6));
				}
			}
			array_push(_frames, _struct)
		}
		return _frames;
	}

	__datetime_string = function(_datetime=undefined) {
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
	__unix_timestamp = function() {
		// Return current unix timestamp
		var _old_tz = date_get_timezone();
		date_set_timezone(timezone_utc);
		var _timestamp = floor((date_current_datetime() - 25569) * 86400);
		date_set_timezone(_old_tz);
		return _timestamp;

	}
	__uuid4 = function() {
		// Generate UUID4. We cheat and use md5 of the current time
		var _uuid = md5_string_utf8(string(date_current_datetime()) + string(get_timer()));
		_uuid = string_set_byte_at(_uuid, 13, ord("4"));
		_uuid = string_set_byte_at(_uuid, 17, ord(choose("8", "9", "a", "b")));
		return _uuid;	
	}
	
	__handle_async_load = function(_async_load) {
		var _async_id = _async_load[? "id"]
		var _request = __requests[$ string(_async_id)];

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
		
				if (__options.backup_autoclean) {
					var _filename = __options.backup_path + SENTRY_LOG_FILE_PREFIX + _request.uuid;
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
				if (is_method(_request.errorback)) {
					_request.errorback(_request.uuid, _http_status, _async_result);
				}
				variable_struct_remove(_request, string(_async_id));
			}
		}
	}
	
	__os_string = function() {
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
	
	__os_version_string = function() {
		switch (os_type) {
			case os_windows:
			case os_uwp:
				switch (os_version) {
					case 327680: return "2000";
					case 327681:
					case 237862:
						return "XP"; break;
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
				var major = os_version >> 24;
				var minor = (os_version >> 12) & 0xfff;
				return string(major) + "." + string(minor)
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
	
	__browser_string = function() {
		switch (os_browser) {
			case browser_not_a_browser: return undefined;
			case browser_ie:
			case browser_ie_mobile:
				return "Internet Explorer";
			case browser_firefox: return "Firefox";
			case browser_chrome: return "Chrome";
			case browser_safari:
			case browser_safari_mobile:
				return "Safari";
			case browser_opera: return "Opera";
			case browser_tizen: _device = "Tizen"; break;
			case browser_windows_store: _device = "Windows App"; break;
			default: return "Unknown Browser";
		}
	}
	
	__system_string = function() {
		if (os_browser == browser_not_a_browser) {
			return __os_string() + " " + __os_version_string();
		}
		else {
			return __browser_string();
		}
	}
	
	__device_hash = function() {
		var _empty = ds_map_create();
		ds_map_secure_save(_empty, "sentry_device_hash");
		ds_map_destroy(_empty);
		
		var _hash = md5_file("sentry_device_hash")
		file_delete("sentry_device_hash");
		
		return _hash;
	}
}