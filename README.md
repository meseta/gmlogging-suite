## What is it?
gmlogging-suite Is a collection of scripts to make logging, debugging, and reporting errors in GameMaker Studio 2 a nicer experience.

Find out more [in the wiki](https://github.com/meseta/gmlogging-suite/wiki)

## Features
### Sentry.io Integration
[Sentry.io](https://sentry.io) Is a online service (with free tier!) that receives error messages and bug reports. The gmlogging-suite has Sentry.io integration, which means it can be configured to submit bug reports to your Sentry.io account automatically, so you don't have to rely on players sending screenshots or copy/pasting error messages.

It's as simple as (replace the URL below with your project's DSN from Sentry.io):
```gml
sentry = new Sentry("https://############################(at)#######.sentry.io/#######");
exception_unhandled_handler(sentry.get_exception_handler());
```

This will cause any runtime errors to be sent to your Sentry.io account (by default, the user will see a confirmation dialogue asking whether they want to send you the error logs).

### Structured Logging
The gmlogging-suite includes a logging object, which makes it easier to logs variables, and track what's going on.

Previously you might have written:
```gml
show_debug_message("Attacked at X: " + string(x) + " Y: " + string(y) + " Health: " + string(health));
```

You can now write (assuming you instantiated `logger` earlier):
```gml
logger.info("Attacked", {x: x, y: y, health: health})
```

Your output console will look something like this:
```
2021-11-04 21:06:26  [info  ][logger] Attacked              x=13.35  y=53.39 health:50
```

The logging object can log this to file, or switch to JSON logging mode, or also work with the Sentry instance, to buffer these log messages temporarily so that in the case of an crash, some contextual information will be sent alongside the bug report to helpy ou debug.

### New Exceptions
gmlogging-suite also includes an experimental new Exception object that makes it easier to use try/catch. It allows you to catch specific exceptions, so you don't accidentally catch runtime errors that hide your bugs.

In the following example, assume `do_something()` is a lengthy function in which there is one particular point where it needs to raise an exception, that depending on the context in which it is run, should be caught.

With gmlogging-suite's new exception handling code, it becomes possible to check that you threw a specific `Exception`, and avoid accidentally catching exceptions that come from runtime errors.

```gml
do_something = function() {
  ... lots of code here ...
  throw Exception("Could not do a thing");
}

try {
	do_something();
}
catch (_err) {
	if (is_instanceof(_err, Exception)) { // checks if we threw an GeneralException
		logger.info("Ignoring error");
	}
	else { // otherwise it must have been that normal GM runtime error
		throw _err; // rethrow the exception
	}
}
```

## Where to get it
Download the package from the following locations:
- https://github.com/meseta/gmlogging-suite/releases

You can import the package into your project from the GMS2 menu Tools > Import Local Package.

## Change log
- v1.0.1 Fix bug in stacktrace handling
- v1.0.0 Update to use GM2023 best practices
- v0.9.4 Use globals for longer exceptions, and avoid errors when log level isn't a string
- v0.9.3 Fix line number handling for built projects
- v0.9.2 Fix .log() function, update error text, and fix stacktrace for logger.error()
- v0.9.1 Change some parameter orders, and added missing functions
- v0.9.0 Initial release