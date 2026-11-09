-module(vitals@metrics_test).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "test/vitals/metrics_test.gleam").
-export([main/0, format_metrics_renders_counter_gauge_histogram_test/0]).

-file("test/vitals/metrics_test.gleam", 6).
-spec main() -> nil.
main() ->
    gleeunit:main().

-file("test/vitals/metrics_test.gleam", 10).
-spec format_metrics_renders_counter_gauge_histogram_test() -> nil.
format_metrics_renders_counter_gauge_histogram_test() ->
    Rendered = vitals@metrics:format_metrics(
        [{counter_metric,
                <<"http_requests_total"/utf8>>,
                7,
                [{<<"method"/utf8>>, <<"GET"/utf8>>}]}],
        [{gauge_metric, <<"active_sessions"/utf8>>, 3, []}],
        [{histogram_metric,
                <<"latency_seconds"/utf8>>,
                2,
                1.5,
                [{0.5, 1}, {1.0, 2}],
                [{<<"route"/utf8>>, <<"/health"/utf8>>}]}]
    ),
    _pipe = gleam_stdlib:contains_string(
        Rendered,
        <<"# TYPE http_requests_total counter"/utf8>>
    ),
    gleeunit@should:equal(_pipe, true),
    _pipe@1 = gleam_stdlib:contains_string(
        Rendered,
        <<"http_requests_total{method=\"GET\"} 7"/utf8>>
    ),
    gleeunit@should:equal(_pipe@1, true),
    _pipe@2 = gleam_stdlib:contains_string(
        Rendered,
        <<"# TYPE active_sessions gauge"/utf8>>
    ),
    gleeunit@should:equal(_pipe@2, true),
    _pipe@3 = gleam_stdlib:contains_string(
        Rendered,
        <<"active_sessions 3"/utf8>>
    ),
    gleeunit@should:equal(_pipe@3, true),
    _pipe@4 = gleam_stdlib:contains_string(
        Rendered,
        <<"# TYPE latency_seconds histogram"/utf8>>
    ),
    gleeunit@should:equal(_pipe@4, true),
    _pipe@5 = gleam_stdlib:contains_string(
        Rendered,
        <<"latency_seconds_count{route=\"/health\"} 2"/utf8>>
    ),
    gleeunit@should:equal(_pipe@5, true),
    _pipe@6 = gleam_stdlib:contains_string(
        Rendered,
        <<"latency_seconds_sum{route=\"/health\"} 1.5"/utf8>>
    ),
    gleeunit@should:equal(_pipe@6, true).
