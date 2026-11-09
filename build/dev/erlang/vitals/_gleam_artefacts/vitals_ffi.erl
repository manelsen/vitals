-module(vitals_ffi).
-export([current_timestamp/0]).

current_timestamp() ->
    erlang:system_time(millisecond).
