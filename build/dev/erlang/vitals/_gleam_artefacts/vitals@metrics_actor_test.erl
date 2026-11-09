-module(vitals@metrics_actor_test).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "test/vitals/metrics_actor_test.gleam").
-export([main/0, counters_gauges_histograms_and_reset_test/0]).

-file("test/vitals/metrics_actor_test.gleam", 6).
-spec main() -> nil.
main() ->
    gleeunit:main().

-file("test/vitals/metrics_actor_test.gleam", 10).
-spec counters_gauges_histograms_and_reset_test() -> nil.
counters_gauges_histograms_and_reset_test() ->
    M@1 = case vitals@metrics_actor:start() of
        {ok, M} -> M;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"vitals/metrics_actor_test"/utf8>>,
                        function => <<"counters_gauges_histograms_and_reset_test"/utf8>>,
                        line => 11,
                        value => _assert_fail,
                        start => 180,
                        'end' => 220,
                        pattern_start => 191,
                        pattern_end => 196})
    end,
    vitals@metrics_actor:inc_counter(
        M@1,
        <<"requests_total"/utf8>>,
        [{<<"method"/utf8>>, <<"GET"/utf8>>}]
    ),
    vitals@metrics_actor:inc_counter(
        M@1,
        <<"requests_total"/utf8>>,
        [{<<"method"/utf8>>, <<"GET"/utf8>>}]
    ),
    vitals@metrics_actor:set_gauge(M@1, <<"active_sessions"/utf8>>, 10, []),
    vitals@metrics_actor:set_gauge(M@1, <<"active_sessions"/utf8>>, 12, []),
    vitals@metrics_actor:observe_histogram(M@1, <<"latency"/utf8>>, 0.5, []),
    vitals@metrics_actor:observe_histogram(M@1, <<"latency"/utf8>>, 1.0, []),
    Rendered = vitals@metrics_actor:get_metrics(M@1),
    _pipe = Rendered,
    _pipe@1 = gleam_stdlib:contains_string(
        _pipe,
        <<"requests_total{method=\"GET\"} 2"/utf8>>
    ),
    gleeunit@should:equal(_pipe@1, true),
    _pipe@2 = Rendered,
    _pipe@3 = gleam_stdlib:contains_string(
        _pipe@2,
        <<"active_sessions 12"/utf8>>
    ),
    gleeunit@should:equal(_pipe@3, true),
    _pipe@4 = Rendered,
    _pipe@5 = gleam_stdlib:contains_string(_pipe@4, <<"latency_count 2"/utf8>>),
    gleeunit@should:equal(_pipe@5, true),
    _pipe@6 = Rendered,
    _pipe@7 = gleam_stdlib:contains_string(_pipe@6, <<"latency_sum 1.5"/utf8>>),
    gleeunit@should:equal(_pipe@7, true),
    vitals@metrics_actor:reset(M@1),
    _pipe@8 = vitals@metrics_actor:get_metrics(M@1),
    gleeunit@should:equal(_pipe@8, <<""/utf8>>).
