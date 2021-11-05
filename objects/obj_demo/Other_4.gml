// Create sentry
sentry = new Sentry("https://############################(at)#######.sentry.io/#######");

// Register sentry as the global exception handler
exception_unhandled_handler(exception_handler);

// Create a new logger, which uses sentry to automatically report errors
logger = new Logger().use_sentry(sentry, true);

logger.debug("blah");
logger.info("info");
logger.error("this is an error"); // <--- this will automatically fire off an error message to sentry

// Example of using exceptions
throw new Exception("this is a new error") // <--- This of exception object will trigger the global exception handler

// Example using exceptions in try/catch
try {
	if (choose(0, 1)) {
		something("This will be caught because something() doesn't exist");
	}
	else {
		throw new Exception("this will be ignored");	
	}
}
catch (_err) {
	if (exception_is(_err, Exception)) { // checks if we threw an Exception
		logger.info("Ignoring error");	
	}
	else { // otherwise it must have been that normal GM runtime error
		exception_rethrow(_err); // rethrow the exception
	}
}
