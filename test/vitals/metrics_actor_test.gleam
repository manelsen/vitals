import gleam/string
import gleeunit
import gleeunit/should
import vitals/metrics_actor

pub fn main() {
  gleeunit.main()
}

pub fn counters_gauges_histograms_and_reset_test() {
  let assert Ok(m) = metrics_actor.start()

  metrics_actor.inc_counter(m, "requests_total", [#("method", "GET")])
  metrics_actor.inc_counter(m, "requests_total", [#("method", "GET")])
  metrics_actor.set_gauge(m, "active_sessions", 10, [])
  metrics_actor.set_gauge(m, "active_sessions", 12, [])
  metrics_actor.observe_histogram(m, "latency", 0.5, [])
  metrics_actor.observe_histogram(m, "latency", 1.0, [])

  let rendered = metrics_actor.get_metrics(m)
  rendered
  |> string.contains("requests_total{method=\"GET\"} 2")
  |> should.equal(True)
  rendered |> string.contains("active_sessions 12") |> should.equal(True)
  rendered |> string.contains("latency_count 2") |> should.equal(True)
  rendered |> string.contains("latency_sum 1.5") |> should.equal(True)

  metrics_actor.reset(m)
  metrics_actor.get_metrics(m) |> should.equal("")
}
