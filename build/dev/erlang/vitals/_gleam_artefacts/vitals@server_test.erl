-module(vitals@server_test).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "test/vitals/server_test.gleam").
-export([main/0, start_and_stop_server_test/0]).

-file("test/vitals/server_test.gleam", 6).
-spec main() -> nil.
main() ->
    gleeunit:main().

-file("test/vitals/server_test.gleam", 10).
-spec start_and_stop_server_test() -> nil.
start_and_stop_server_test() ->
    M@1 = case vitals@metrics_actor:start() of
        {ok, M} -> M;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"vitals/server_test"/utf8>>,
                        function => <<"start_and_stop_server_test"/utf8>>,
                        line => 11,
                        value => _assert_fail,
                        start => 166,
                        'end' => 206,
                        pattern_start => 177,
                        pattern_end => 182})
    end,
    Srv = vitals@server:start(0, M@1, fun() -> [<<"db"/utf8>>] end),
    _pipe = erlang:element(3, Srv),
    gleeunit@should:equal(_pipe, 0),
    _pipe@1 = vitals@server:stop(Srv),
    gleeunit@should:equal(_pipe@1, nil).
