import gleam/string
import gleeunit
import gleeunit/should
import vitals/metrics

pub fn main() {
  gleeunit.main()
}

pub fn format_metrics_renders_counter_gauge_histogram_test() {
  let rendered =
    metrics.format_metrics(
      counters: [
        metrics.CounterMetric(
          name: "http_requests_total",
          value: 7,
          labels: [#("method", "GET")],
        ),
      ],
      gauges: [
        metrics.GaugeMetric(
          name: "active_sessions",
          value: 3,
          labels: [],
        ),
      ],
      histograms: [
        metrics.HistogramMetric(
          name: "latency_seconds",
          count: 2,
          sum: 1.5,
          buckets: [#(0.5, 1), #(1.0, 2)],
          labels: [#("route", "/health")],
        ),
      ],
    )

  string.contains(rendered, "# TYPE http_requests_total counter")
  |> should.equal(True)
  string.contains(rendered, "http_requests_total{method=\"GET\"} 7")
  |> should.equal(True)
  string.contains(rendered, "# TYPE active_sessions gauge")
  |> should.equal(True)
  string.contains(rendered, "active_sessions 3")
  |> should.equal(True)
  string.contains(rendered, "# TYPE latency_seconds histogram")
  |> should.equal(True)
  string.contains(rendered, "latency_seconds_count{route=\"/health\"} 2")
  |> should.equal(True)
  string.contains(rendered, "latency_seconds_sum{route=\"/health\"} 1.5")
  |> should.equal(True)
}
