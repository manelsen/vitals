-module(vitals@health).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/vitals/health.gleam").
-export([health_status_to_json/1, readiness_status_to_json/1]).
-export_type([health_status/0, readiness_status/0, channel_status/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " Health check types and JSON serialisation.\n"
    "\n"
    " Compatible with Kubernetes liveness/readiness probes and Docker healthchecks.\n"
).

-type health_status() :: {health_status, binary(), integer()}.

-type readiness_status() :: {readiness_status,
        binary(),
        integer(),
        list(channel_status())}.

-type channel_status() :: {channel_status,
        binary(),
        boolean(),
        gleam@option:option(binary())}.

-file("src/vitals/health.gleam", 24).
-spec health_status_to_json(health_status()) -> binary().
health_status_to_json(Status) ->
    _pipe = gleam@json:object(
        [{<<"status"/utf8>>, gleam@json:string(erlang:element(2, Status))},
            {<<"uptime_seconds"/utf8>>,
                gleam@json:int(erlang:element(3, Status))}]
    ),
    gleam@json:to_string(_pipe).

-file("src/vitals/health.gleam", 32).
-spec channel_status_to_json(channel_status()) -> gleam@json:json().
channel_status_to_json(Ch) ->
    Error_json = case erlang:element(4, Ch) of
        {some, E} ->
            gleam@json:string(E);

        none ->
            gleam@json:null()
    end,
    gleam@json:object(
        [{<<"name"/utf8>>, gleam@json:string(erlang:element(2, Ch))},
            {<<"ready"/utf8>>, gleam@json:bool(erlang:element(3, Ch))},
            {<<"error"/utf8>>, Error_json}]
    ).

-file("src/vitals/health.gleam", 44).
-spec readiness_status_to_json(readiness_status()) -> binary().
readiness_status_to_json(Status) ->
    _pipe = gleam@json:object(
        [{<<"status"/utf8>>, gleam@json:string(erlang:element(2, Status))},
            {<<"uptime_seconds"/utf8>>,
                gleam@json:int(erlang:element(3, Status))},
            {<<"channels_ready"/utf8>>,
                gleam@json:array(
                    erlang:element(4, Status),
                    fun channel_status_to_json/1
                )}]
    ),
    gleam@json:to_string(_pipe).
