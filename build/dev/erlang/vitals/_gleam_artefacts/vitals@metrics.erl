-module(vitals@metrics).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/vitals/metrics.gleam").
-export([format_metrics/3]).
-export_type([metrics_registry/0, counter_metric/0, gauge_metric/0, histogram_metric/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " Prometheus metrics types and text-format rendering.\n"
    "\n"
    " Provides counters, gauges, and histograms with label support.\n"
    " Output is compatible with the Prometheus text exposition format.\n"
    "\n"
    " ## Usage\n"
    "\n"
    " ```gleam\n"
    " let output = metrics.format_metrics(\n"
    "   counters: [metrics.CounterMetric(\"http_requests\", 42, [#(\"method\", \"GET\")])],\n"
    "   gauges: [metrics.GaugeMetric(\"active_conns\", 7, [])],\n"
    "   histograms: [],\n"
    " )\n"
    " ```\n"
).

-type metrics_registry() :: {metrics_registry,
        list(counter_metric()),
        list(gauge_metric()),
        list(histogram_metric())}.

-type counter_metric() :: {counter_metric,
        binary(),
        integer(),
        list({binary(), binary()})}.

-type gauge_metric() :: {gauge_metric,
        binary(),
        integer(),
        list({binary(), binary()})}.

-type histogram_metric() :: {histogram_metric,
        binary(),
        integer(),
        float(),
        list({float(), integer()}),
        list({binary(), binary()})}.

-file("src/vitals/metrics.gleam", 59).
-spec format_labels(list({binary(), binary()})) -> binary().
format_labels(Labels) ->
    case Labels of
        [] ->
            <<""/utf8>>;

        _ ->
            Pairs = gleam@list:map(
                Labels,
                fun(Pair) ->
                    <<<<<<(erlang:element(1, Pair))/binary, "=\""/utf8>>/binary,
                            (erlang:element(2, Pair))/binary>>/binary,
                        "\""/utf8>>
                end
            ),
            <<<<"{"/utf8, (gleam@string:join(Pairs, <<","/utf8>>))/binary>>/binary,
                "}"/utf8>>
    end.

-file("src/vitals/metrics.gleam", 70).
-spec format_counters(list(counter_metric())) -> list(binary()).
format_counters(Counters) ->
    gleam@list:map(
        Counters,
        fun(C) ->
            Labels = format_labels(erlang:element(4, C)),
            <<<<<<<<<<<<"# TYPE "/utf8, (erlang:element(2, C))/binary>>/binary,
                                " counter\n"/utf8>>/binary,
                            (erlang:element(2, C))/binary>>/binary,
                        Labels/binary>>/binary,
                    " "/utf8>>/binary,
                (erlang:integer_to_binary(erlang:element(3, C)))/binary>>
        end
    ).

-file("src/vitals/metrics.gleam", 77).
-spec format_gauges(list(gauge_metric())) -> list(binary()).
format_gauges(Gauges) ->
    gleam@list:map(
        Gauges,
        fun(G) ->
            Labels = format_labels(erlang:element(4, G)),
            <<<<<<<<<<<<"# TYPE "/utf8, (erlang:element(2, G))/binary>>/binary,
                                " gauge\n"/utf8>>/binary,
                            (erlang:element(2, G))/binary>>/binary,
                        Labels/binary>>/binary,
                    " "/utf8>>/binary,
                (erlang:integer_to_binary(erlang:element(3, G)))/binary>>
        end
    ).

-file("src/vitals/metrics.gleam", 84).
-spec format_histograms(list(histogram_metric())) -> list(binary()).
format_histograms(Histograms) ->
    gleam@list:map(
        Histograms,
        fun(H) ->
            Labels = format_labels(erlang:element(6, H)),
            Sum_str = gleam_stdlib:float_to_string(erlang:element(4, H)),
            <<<<<<<<<<<<<<<<<<<<<<<<<<"# TYPE "/utf8,
                                                                (erlang:element(
                                                                    2,
                                                                    H
                                                                ))/binary>>/binary,
                                                            " histogram\n"/utf8>>/binary,
                                                        (erlang:element(2, H))/binary>>/binary,
                                                    "_count"/utf8>>/binary,
                                                Labels/binary>>/binary,
                                            " "/utf8>>/binary,
                                        (erlang:integer_to_binary(
                                            erlang:element(3, H)
                                        ))/binary>>/binary,
                                    "\n"/utf8>>/binary,
                                (erlang:element(2, H))/binary>>/binary,
                            "_sum"/utf8>>/binary,
                        Labels/binary>>/binary,
                    " "/utf8>>/binary,
                Sum_str/binary>>
        end
    ).

-file("src/vitals/metrics.gleam", 48).
?DOC(" Render counters, gauges, and histograms to Prometheus text format.\n").
-spec format_metrics(
    list(counter_metric()),
    list(gauge_metric()),
    list(histogram_metric())
) -> binary().
format_metrics(Counters, Gauges, Histograms) ->
    Lines = begin
        _pipe = lists:append(format_counters(Counters), format_gauges(Gauges)),
        lists:append(_pipe, format_histograms(Histograms))
    end,
    gleam@string:join(Lines, <<"\n"/utf8>>).
