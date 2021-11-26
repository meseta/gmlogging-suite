// Sentry will warn you when it has no DSN, and therefore can't send reports
#macro SENTRY_WARN_WHEN_NO_DSN true

// Privacy stuff: set to true to record a device-specific hash. No identifying information
// is included, but the device hash is specific to a device
#macro SENTRY_USE_DEVICE_HASH true

// Privacy stuff: set to true to record the parameters used to launch the game. This sometimes
// includes the instaled path of the game, and may potentially include identifying information
#macro SENTRY_USE_GAME_PARAMETERS false

// Report levels. These match the logger level macros. so are interchangeable
#macro LEVEL_FATAL "fatal"
#macro LEVEL_ERROR "error"
#macro LEVEL_WARNING "warning"
#macro LEVEL_INFO "info"
#macro LEVEL_DEBUG "debug"

// Some breadcrumb types you can use. It may cause sentry
// to display the breadcrumb with a specific icon
// see: https://develop.sentry.dev/sdk/event-payloads/breadcrumbs/#breadcrumb-types
#macro BREADCRUMB_DEFAULT "default"
#macro BREADCRUMB_ERROR "error"
#macro BREADCRUMB_INFO "info"
#macro BREADCRUMB_DEBUG "debug"
#macro BREADCRUMB_NAVIGATION "navigation"
#macro BREADCRUMB_HTTP "http"
#macro BREADCRUMB_QUERY "query"
#macro BREADCRUMB_TRANSACTION "transaction"
#macro BREADCRUMB_UI "ui"
#macro BREADCRUMB_USER "user"

#macro SENTRY_LOGGING_SUITE_VERSION "0.9.1"