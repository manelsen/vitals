-record(set_gauge, {
    name :: binary(),
    value :: integer(),
    labels :: list({binary(), binary()})
}).
