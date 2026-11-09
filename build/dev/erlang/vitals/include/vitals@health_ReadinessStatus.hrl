-record(readiness_status, {
    status :: binary(),
    uptime_seconds :: integer(),
    channels_ready :: list(vitals@health:channel_status())
}).
