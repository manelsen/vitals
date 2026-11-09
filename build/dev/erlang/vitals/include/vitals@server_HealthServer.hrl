-record(health_server, {
    start_time_ms :: integer(),
    port :: integer(),
    metrics :: gleam@erlang@process:subject(vitals@metrics_actor:metrics_command())
}).
