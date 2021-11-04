// This object exists solely as a way to collect the async HTTP response
// Because structs alone can't do it.
// This object will be spawned when asked, and will be removed when its 
// job is done, you don't have to touch it.
handle_async_load(async_load);