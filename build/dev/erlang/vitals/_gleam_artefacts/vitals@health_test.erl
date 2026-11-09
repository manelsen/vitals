-module(vitals@health_test).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "test/vitals/health_test.gleam").
-export([main/0, health_status_to_json_test/0, readiness_status_to_json_test/0]).

-file("test/vitals/health_test.gleam", 7).
-spec main() -> nil.
main() ->
    gleeunit:main().

-file("test/vitals/health_test.gleam", 11).
-spec health_status_to_json_test() -> nil.
health_status_to_json_test() ->
    Json = vitals@health:health_status_to_json(
        {health_status, <<"ok"/utf8>>, 42}
    ),
    _pipe = gleam_stdlib:contains_string(Json, <<"\"status\":\"ok\""/utf8>>),
    gleeunit@should:equal(_pipe, true),
    _pipe@1 = gleam_stdlib:contains_string(
        Json,
        <<"\"uptime_seconds\":42"/utf8>>
    ),
    gleeunit@should:equal(_pipe@1, true).

-file("test/vitals/health_test.gleam", 21).
-spec readiness_status_to_json_test() -> nil.
readiness_status_to_json_test() ->
    Json = vitals@health:readiness_status_to_json(
        {readiness_status,
            <<"ok"/utf8>>,
            99,
            [{channel_status, <<"db"/utf8>>, true, none},
                {channel_status,
                    <<"cache"/utf8>>,
                    false,
                    {some, <<"connection refused"/utf8>>}}]}
    ),
    _pipe = gleam_stdlib:contains_string(Json, <<"\"channels_ready\""/utf8>>),
    gleeunit@should:equal(_pipe, true),
    _pipe@1 = gleam_stdlib:contains_string(Json, <<"\"name\":\"db\""/utf8>>),
    gleeunit@should:equal(_pipe@1, true),
    _pipe@2 = gleam_stdlib:contains_string(Json, <<"\"ready\":true"/utf8>>),
    gleeunit@should:equal(_pipe@2, true),
    _pipe@3 = gleam_stdlib:contains_string(Json, <<"\"error\":null"/utf8>>),
    gleeunit@should:equal(_pipe@3, true),
    _pipe@4 = gleam_stdlib:contains_string(Json, <<"\"name\":\"cache\""/utf8>>),
    gleeunit@should:equal(_pipe@4, true),
    _pipe@5 = gleam_stdlib:contains_string(Json, <<"\"ready\":false"/utf8>>),
    gleeunit@should:equal(_pipe@5, true),
    _pipe@6 = gleam_stdlib:contains_string(
        Json,
        <<"\"error\":\"connection refused\""/utf8>>
    ),
    gleeunit@should:equal(_pipe@6, true).
