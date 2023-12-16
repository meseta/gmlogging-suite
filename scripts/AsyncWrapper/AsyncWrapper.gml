/** Provise callback-based implementation for async events */
function AsyncWrapper() constructor {
	/* @ignore */ static __async_http_wrapper = noone;
	/* @ignore */ static __async_networking_wrapper = noone;
	
	/** Adds an async HTTP callback to the async http wrapper object
	 * @param {Function} _callback The callback to trigger on receiving HTTP requests
	*/
	static add_async_http_callback = function(_callback) {
		if (!instance_exists(self.__async_http_wrapper)) {
			self.__async_http_wrapper = instance_create_depth(0, 0, 0, oAsyncWrapperHttp);
		}
		self.__async_http_wrapper.add_callback(_callback);
	}
	
	/** Adds an async networking handler
	 * @param {Function} _callback The callback to trigger on receiving a networking requests
	*/
	static add_async_networking_callback = function(_callback) {
		if (!instance_exists(self.__async_networking_wrapper)) {
			self.__async_networking_wrapper = instance_create_depth(0, 0, 0, oAsyncWrapperNetworking);
		}
		self.__async_networking_wrapper.add_callback(_callback);
	}
	
	/** Remove a new networking handler
	 * @param {Function} _callback The callback to remove
	*/
	static remove_async_networking_callback = function(_callback) {
		if (instance_exists(self.__async_networking_wrapper)) {
			self.__async_networking_wrapper.remove_callback(_callback);
		}
	}
}

// Instantiate statis
new AsyncWrapper();