-record(counter_metric, {
    name :: binary(),
    value :: integer(),
    labels :: list({binary(), binary()})
}).
