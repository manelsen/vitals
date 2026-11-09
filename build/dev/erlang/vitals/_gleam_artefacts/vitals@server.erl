-module(vitals@server).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/vitals/server.gleam").
-export([start/3, stop/1]).
-export_type([health_server/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " Health and metrics HTTP server.\n"
    "\n"
    " Serves the following endpoints:\n"
    "\n"
    " - `GET /health`       — basic liveness with uptime\n"
    " - `GET /health/live`  — simple liveness probe (returns \"ok\")\n"
    " - `GET /health/ready` — readiness probe with channel status\n"
    " - `GET /metrics`      — Prometheus text format metrics\n"
    "\n"
    " ## Usage\n"
    "\n"
    " ```gleam\n"
    " let assert Ok(m) = metrics_actor.start()\n"
    " let srv = server.start(\n"
    "   port: 9090,\n"
    "   metrics: m,\n"
    "   get_ready_checks: fn() { [\"database\", \"cache\"] },\n"
    " )\n"
    " ```\n"
).

-type health_server() :: {health_server,
        integer(),
        integer(),
        gleam@erlang@process:subject(vitals@metrics_actor:metrics_command())}.

-file("src/vitals/server.gleam", 39).
-spec uptime_seconds(integer()) -> integer().
uptime_seconds(Start_time_ms) ->
    (vitals_ffi:current_timestamp() - Start_time_ms) div 1000.

-file("src/vitals/server.gleam", 58).
-spec handle_health(integer()) -> gleam@http@response:response(mist:response_data()).
handle_health(Start_time_ms) ->
    Body = vitals@health:health_status_to_json(
        {health_status, <<"ok"/utf8>>, uptime_seconds(Start_time_ms)}
    ),
    _pipe = gleam@http@response:new(200),
    _pipe@1 = gleam@http@response:set_body(
        _pipe,
        {bytes, gleam_stdlib:wrap_list(Body)}
    ),
    gleam@http@response:set_header(
        _pipe@1,
        <<"content-type"/utf8>>,
        <<"application/json"/utf8>>
    ).

-file("src/vitals/server.gleam", 69).
-spec handle_live() -> gleam@http@response:response(mist:response_data()).
handle_live() ->
    _pipe = gleam@http@response:new(200),
    gleam@http@response:set_body(
        _pipe,
        {bytes, gleam_stdlib:wrap_list(<<"ok"/utf8>>)}
    ).

-file("src/vitals/server.gleam", 74).
-spec handle_ready(integer(), fun(() -> list(binary()))) -> gleam@http@response:response(mist:response_data()).
handle_ready(Start_time_ms, Get_ready_checks) ->
    Channels = gleam@list:map(
        Get_ready_checks(),
        fun(Name) -> {channel_status, Name, true, none} end
    ),
    Body = vitals@health:readiness_status_to_json(
        {readiness_status,
            <<"ok"/utf8>>,
            uptime_seconds(Start_time_ms),
            Channels}
    ),
    _pipe = gleam@http@response:new(200),
    _pipe@1 = gleam@http@response:set_body(
        _pipe,
        {bytes, gleam_stdlib:wrap_list(Body)}
    ),
    gleam@http@response:set_header(
        _pipe@1,
        <<"content-type"/utf8>>,
        <<"application/json"/utf8>>
    ).

-file("src/vitals/server.gleam", 93).
-spec handle_metrics(
    gleam@erlang@process:subject(vitals@metrics_actor:metrics_command())
) -> gleam@http@response:response(mist:response_data()).
handle_metrics(Metrics) ->
    _pipe = gleam@http@response:new(200),
    _pipe@1 = gleam@http@response:set_body(
        _pipe,
        {bytes,
            gleam_stdlib:wrap_list(vitals@metrics_actor:get_metrics(Metrics))}
    ),
    gleam@http@response:set_header(
        _pipe@1,
        <<"content-type"/utf8>>,
        <<"text/plain; version=0.0.4"/utf8>>
    ).

-file("src/vitals/server.gleam", 101).
-spec handle_not_found() -> gleam@http@response:response(mist:response_data()).
handle_not_found() ->
    _pipe = gleam@http@response:new(404),
    gleam@http@response:set_body(
        _pipe,
        {bytes, gleam_stdlib:wrap_list(<<"Not Found"/utf8>>)}
    ).

-file("src/vitals/server.gleam", 43).
-spec handle_request(
    gleam@http@request:request(mist@internal@http:connection()),
    gleam@erlang@process:subject(vitals@metrics_actor:metrics_command()),
    integer(),
    fun(() -> list(binary()))
) -> gleam@http@response:response(mist:response_data()).
handle_request(Req, Metrics, Start_time_ms, Get_ready_checks) ->
    case gleam@http@request:path_segments(Req) of
        [<<"health"/utf8>>] ->
            handle_health(Start_time_ms);

        [<<"health"/utf8>>, <<"live"/utf8>>] ->
            handle_live();

        [<<"health"/utf8>>, <<"ready"/utf8>>] ->
            handle_ready(Start_time_ms, Get_ready_checks);

        [<<"metrics"/utf8>>] ->
            handle_metrics(Metrics);

        _ ->
            handle_not_found()
    end.

-file("src/vitals/server.gleam", 110).
?DOC(
    " Start the health and metrics server on the given port.\n"
    "\n"
    " `get_ready_checks` is called on every `/health/ready` request and should\n"
    " return the names of subsystems that are currently healthy.\n"
).
-spec start(
    integer(),
    gleam@erlang@process:subject(vitals@metrics_actor:metrics_command()),
    fun(() -> list(binary()))
) -> health_server().
start(Port, Metrics, Get_ready_checks) ->
    Start_time_ms = vitals_ffi:current_timestamp(),
    case begin
        _pipe = fun(Req) ->
            handle_request(Req, Metrics, Start_time_ms, Get_ready_checks)
        end,
        _pipe@1 = mist:new(_pipe),
        _pipe@2 = mist:bind(_pipe@1, <<"0.0.0.0"/utf8>>),
        _pipe@3 = mist:port(_pipe@2, Port),
        mist:start(_pipe@3)
    end of
        {ok, _} -> nil;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"vitals/server"/utf8>>,
                        function => <<"start"/utf8>>,
                        line => 116,
                        value => _assert_fail,
                        start => 3509,
                        'end' => 3764,
                        pattern_start => 3520,
                        pattern_end => 3525})
    end,
    gleam_stdlib:println(
        <<"vitals: health server listening on port "/utf8,
            (erlang:integer_to_binary(Port))/binary>>
    ),
    {health_server, Start_time_ms, Port, Metrics}.

-file("src/vitals/server.gleam", 129).
?DOC(" Stop the health server. Currently a no-op; mist does not expose a stop API.\n").
-spec stop(health_server()) -> nil.
stop(_) ->
    nil.
