-record(metrics_registry, {
    counters :: list(vitals@metrics:counter_metric()),
    gauges :: list(vitals@metrics:gauge_metric()),
    histograms :: list(vitals@metrics:histogram_metric())
}).
