-module(vitals@metrics_actor).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/vitals/metrics_actor.gleam").
-export([start_linked/0, start/0, inc_counter/3, set_gauge/4, observe_histogram/4, get_metrics/1, reset/1]).
-export_type([metrics_command/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " Prometheus metrics actor.\n"
    "\n"
    " Thread-safe metrics collection via OTP actor.\n"
    " Exposes counters, gauges, and histograms in Prometheus text format.\n"
    "\n"
    " ## Usage\n"
    "\n"
    " ```gleam\n"
    " let assert Ok(m) = metrics_actor.start()\n"
    "\n"
    " metrics_actor.inc_counter(m, \"http_requests\", [#(\"method\", \"GET\")])\n"
    " metrics_actor.set_gauge(m, \"active_sessions\", 12, [])\n"
    " metrics_actor.observe_histogram(m, \"latency_seconds\", 0.042, [])\n"
    "\n"
    " let output = metrics_actor.get_metrics(m)\n"
    " // Prometheus text output\n"
    " ```\n"
).

-type metrics_command() :: {inc_counter, binary(), list({binary(), binary()})} |
    {set_gauge, binary(), integer(), list({binary(), binary()})} |
    {observe_histogram, binary(), float(), list({binary(), binary()})} |
    {get_metrics, gleam@erlang@process:subject(binary())} |
    {reset, gleam@erlang@process:subject(nil)}.

-file("src/vitals/metrics_actor.gleam", 108).
-spec default_buckets() -> list({float(), integer()}).
default_buckets() ->
    [{0.005, 0},
        {0.01, 0},
        {0.025, 0},
        {0.05, 0},
        {0.1, 0},
        {0.25, 0},
        {0.5, 0},
        {1.0, 0},
        {2.5, 0},
        {5.0, 0},
        {10.0, 0}].

-file("src/vitals/metrics_actor.gleam", 124).
-spec find_counter(
    list(vitals@metrics:counter_metric()),
    binary(),
    list({binary(), binary()})
) -> {ok, vitals@metrics:counter_metric()} | {error, nil}.
find_counter(Counters, Name, Labels) ->
    gleam@list:find(
        Counters,
        fun(C) ->
            (erlang:element(2, C) =:= Name) andalso (erlang:element(4, C) =:= Labels)
        end
    ).

-file("src/vitals/metrics_actor.gleam", 132).
-spec update_counter(
    list(vitals@metrics:counter_metric()),
    binary(),
    list({binary(), binary()}),
    integer()
) -> list(vitals@metrics:counter_metric()).
update_counter(Counters, Name, Labels, New_value) ->
    gleam@list:map(
        Counters,
        fun(C) ->
            case (erlang:element(2, C) =:= Name) andalso (erlang:element(4, C)
            =:= Labels) of
                true ->
                    {counter_metric,
                        erlang:element(2, C),
                        New_value,
                        erlang:element(4, C)};

                false ->
                    C
            end
        end
    ).

-file("src/vitals/metrics_actor.gleam", 146).
-spec find_gauge(
    list(vitals@metrics:gauge_metric()),
    binary(),
    list({binary(), binary()})
) -> {ok, vitals@metrics:gauge_metric()} | {error, nil}.
find_gauge(Gauges, Name, Labels) ->
    gleam@list:find(
        Gauges,
        fun(G) ->
            (erlang:element(2, G) =:= Name) andalso (erlang:element(4, G) =:= Labels)
        end
    ).

-file("src/vitals/metrics_actor.gleam", 154).
-spec update_gauge(
    list(vitals@metrics:gauge_metric()),
    binary(),
    list({binary(), binary()}),
    integer()
) -> list(vitals@metrics:gauge_metric()).
update_gauge(Gauges, Name, Labels, New_value) ->
    gleam@list:map(
        Gauges,
        fun(G) ->
            case (erlang:element(2, G) =:= Name) andalso (erlang:element(4, G)
            =:= Labels) of
                true ->
                    {gauge_metric,
                        erlang:element(2, G),
                        New_value,
                        erlang:element(4, G)};

                false ->
                    G
            end
        end
    ).

-file("src/vitals/metrics_actor.gleam", 168).
-spec find_histogram(
    list(vitals@metrics:histogram_metric()),
    binary(),
    list({binary(), binary()})
) -> {ok, vitals@metrics:histogram_metric()} | {error, nil}.
find_histogram(Histograms, Name, Labels) ->
    gleam@list:find(
        Histograms,
        fun(H) ->
            (erlang:element(2, H) =:= Name) andalso (erlang:element(6, H) =:= Labels)
        end
    ).

-file("src/vitals/metrics_actor.gleam", 176).
-spec update_histogram(
    list(vitals@metrics:histogram_metric()),
    binary(),
    list({binary(), binary()}),
    integer(),
    float()
) -> list(vitals@metrics:histogram_metric()).
update_histogram(Histograms, Name, Labels, New_count, New_sum) ->
    gleam@list:map(
        Histograms,
        fun(H) ->
            case (erlang:element(2, H) =:= Name) andalso (erlang:element(6, H)
            =:= Labels) of
                true ->
                    {histogram_metric,
                        erlang:element(2, H),
                        New_count,
                        New_sum,
                        erlang:element(5, H),
                        erlang:element(6, H)};

                false ->
                    H
            end
        end
    ).

-file("src/vitals/metrics_actor.gleam", 35).
-spec handle_message(vitals@metrics:metrics_registry(), metrics_command()) -> gleam@otp@actor:next(vitals@metrics:metrics_registry(), metrics_command()).
handle_message(State, Message) ->
    case Message of
        {inc_counter, Name, Labels} ->
            New_counters = case find_counter(
                erlang:element(2, State),
                Name,
                Labels
            ) of
                {ok, C} ->
                    update_counter(
                        erlang:element(2, State),
                        Name,
                        Labels,
                        erlang:element(3, C) + 1
                    );

                {error, nil} ->
                    gleam@list:prepend(
                        erlang:element(2, State),
                        {counter_metric, Name, 1, Labels}
                    )
            end,
            gleam@otp@actor:continue(
                {metrics_registry,
                    New_counters,
                    erlang:element(3, State),
                    erlang:element(4, State)}
            );

        {set_gauge, Name@1, Value, Labels@1} ->
            New_gauges = case find_gauge(
                erlang:element(3, State),
                Name@1,
                Labels@1
            ) of
                {ok, _} ->
                    update_gauge(
                        erlang:element(3, State),
                        Name@1,
                        Labels@1,
                        Value
                    );

                {error, nil} ->
                    gleam@list:prepend(
                        erlang:element(3, State),
                        {gauge_metric, Name@1, Value, Labels@1}
                    )
            end,
            gleam@otp@actor:continue(
                {metrics_registry,
                    erlang:element(2, State),
                    New_gauges,
                    erlang:element(4, State)}
            );

        {observe_histogram, Name@2, Value@1, Labels@2} ->
            New_histograms = case find_histogram(
                erlang:element(4, State),
                Name@2,
                Labels@2
            ) of
                {ok, H} ->
                    update_histogram(
                        erlang:element(4, State),
                        Name@2,
                        Labels@2,
                        erlang:element(3, H) + 1,
                        erlang:element(4, H) + Value@1
                    );

                {error, nil} ->
                    gleam@list:prepend(
                        erlang:element(4, State),
                        {histogram_metric,
                            Name@2,
                            1,
                            Value@1,
                            default_buckets(),
                            Labels@2}
                    )
            end,
            gleam@otp@actor:continue(
                {metrics_registry,
                    erlang:element(2, State),
                    erlang:element(3, State),
                    New_histograms}
            );

        {get_metrics, Reply_to} ->
            Output = vitals@metrics:format_metrics(
                erlang:element(2, State),
                erlang:element(3, State),
                erlang:element(4, State)
            ),
            gleam@otp@actor:send(Reply_to, Output),
            gleam@otp@actor:continue(State);

        {reset, Reply_to@1} ->
            gleam@otp@actor:send(Reply_to@1, nil),
            gleam@otp@actor:continue({metrics_registry, [], [], []})
    end.

-file("src/vitals/metrics_actor.gleam", 200).
?DOC(" Start and return the full Started record (for use with supervisors).\n").
-spec start_linked() -> {ok,
        gleam@otp@actor:started(gleam@erlang@process:subject(metrics_command()))} |
    {error, gleam@otp@actor:start_error()}.
start_linked() ->
    _pipe = gleam@otp@actor:new({metrics_registry, [], [], []}),
    _pipe@1 = gleam@otp@actor:on_message(_pipe, fun handle_message/2),
    gleam@otp@actor:start(_pipe@1).

-file("src/vitals/metrics_actor.gleam", 192).
?DOC(" Start a metrics actor.\n").
-spec start() -> {ok, gleam@erlang@process:subject(metrics_command())} |
    {error, gleam@otp@actor:start_error()}.
start() ->
    case start_linked() of
        {ok, Started} ->
            {ok, erlang:element(3, Started)};

        {error, E} ->
            {error, E}
    end.

-file("src/vitals/metrics_actor.gleam", 206).
-spec inc_counter(
    gleam@erlang@process:subject(metrics_command()),
    binary(),
    list({binary(), binary()})
) -> nil.
inc_counter(Metrics, Name, Labels) ->
    gleam@otp@actor:send(Metrics, {inc_counter, Name, Labels}).

-file("src/vitals/metrics_actor.gleam", 214).
-spec set_gauge(
    gleam@erlang@process:subject(metrics_command()),
    binary(),
    integer(),
    list({binary(), binary()})
) -> nil.
set_gauge(Metrics, Name, Value, Labels) ->
    gleam@otp@actor:send(Metrics, {set_gauge, Name, Value, Labels}).

-file("src/vitals/metrics_actor.gleam", 223).
-spec observe_histogram(
    gleam@erlang@process:subject(metrics_command()),
    binary(),
    float(),
    list({binary(), binary()})
) -> nil.
observe_histogram(Metrics, Name, Value, Labels) ->
    gleam@otp@actor:send(Metrics, {observe_histogram, Name, Value, Labels}).

-file("src/vitals/metrics_actor.gleam", 232).
-spec get_metrics(gleam@erlang@process:subject(metrics_command())) -> binary().
get_metrics(Metrics) ->
    gleam@otp@actor:call(
        Metrics,
        5000,
        fun(Field@0) -> {get_metrics, Field@0} end
    ).

-file("src/vitals/metrics_actor.gleam", 236).
-spec reset(gleam@erlang@process:subject(metrics_command())) -> nil.
reset(Metrics) ->
    gleam@otp@actor:call(Metrics, 5000, fun(Field@0) -> {reset, Field@0} end).
