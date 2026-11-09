-record(channel_status, {
    name :: binary(),
    ready :: boolean(),
    error :: gleam@option:option(binary())
}).
