// Log severity levels. These match the sentry level macros. so are interchangeable
#macro LOG_FATAL "fatal"
#macro LOG_ERROR "error"
#macro LOG_WARNING "warning"
#macro LOG_INFO "info"
#macro LOG_DEBUG "debug"

// Setting this to True globally disables logging, causing the logger to do nothing when called
// NOTE: this includes not sending sentry reports, or adding values to the sentry breadcrumbs.
// If you want to turn off log outputs, but still send sentry reports, use set_levels() with
// no arguments
#macro LOGGING_DISABLED false

// Width of the padding used in the output
#macro LOGGING_PAD_WIDTH 48