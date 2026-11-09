-record(histogram_metric, {
    name :: binary(),
    count :: integer(),
    sum :: float(),
    buckets :: list({float(), integer()}),
    labels :: list({binary(), binary()})
}).
