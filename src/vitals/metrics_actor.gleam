//// Prometheus metrics actor.
////
//// Thread-safe metrics collection via OTP actor.
//// Exposes counters, gauges, and histograms in Prometheus text format.
////
//// ## Usage
////
//// ```gleam
//// let assert Ok(m) = metrics_actor.start()
////
//// metrics_actor.inc_counter(m, "http_requests", [#("method", "GET")])
//// metrics_actor.set_gauge(m, "active_sessions", 12, [])
//// metrics_actor.observe_histogram(m, "latency_seconds", 0.042, [])
////
//// let output = metrics_actor.get_metrics(m)
//// // Prometheus text output
//// ```

import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/otp/actor
import vitals/metrics as m

pub type Metrics =
  Subject(MetricsCommand)

pub type MetricsCommand {
  IncCounter(name: String, labels: List(#(String, String)))
  SetGauge(name: String, value: Int, labels: List(#(String, String)))
  ObserveHistogram(name: String, value: Float, labels: List(#(String, String)))
  GetMetrics(reply_to: Subject(String))
  Reset(reply_to: Subject(Nil))
}

fn handle_message(
  state: m.MetricsRegistry,
  message: MetricsCommand,
) -> actor.Next(m.MetricsRegistry, MetricsCommand) {
  case message {
    IncCounter(name, labels) -> {
      let new_counters = case find_counter(state.counters, name, labels) {
        Ok(c) -> update_counter(state.counters, name, labels, c.value + 1)
        Error(Nil) ->
          list.prepend(
            state.counters,
            m.CounterMetric(name: name, value: 1, labels: labels),
          )
      }
      actor.continue(m.MetricsRegistry(
        ..state,
        counters: new_counters,
      ))
    }
    SetGauge(name, value, labels) -> {
      let new_gauges = case find_gauge(state.gauges, name, labels) {
        Ok(_) -> update_gauge(state.gauges, name, labels, value)
        Error(Nil) ->
          list.prepend(
            state.gauges,
            m.GaugeMetric(name: name, value: value, labels: labels),
          )
      }
      actor.continue(m.MetricsRegistry(..state, gauges: new_gauges))
    }
    ObserveHistogram(name, value, labels) -> {
      let new_histograms = case find_histogram(state.histograms, name, labels) {
        Ok(h) ->
          update_histogram(
            state.histograms,
            name,
            labels,
            h.count + 1,
            h.sum +. value,
          )
        Error(Nil) ->
          list.prepend(
            state.histograms,
            m.HistogramMetric(
              name: name,
              count: 1,
              sum: value,
              buckets: default_buckets(),
              labels: labels,
            ),
          )
      }
      actor.continue(m.MetricsRegistry(..state, histograms: new_histograms))
    }
    GetMetrics(reply_to) -> {
      let output =
        m.format_metrics(
          counters: state.counters,
          gauges: state.gauges,
          histograms: state.histograms,
        )
      actor.send(reply_to, output)
      actor.continue(state)
    }
    Reset(reply_to) -> {
      actor.send(reply_to, Nil)
      actor.continue(
        m.MetricsRegistry(counters: [], gauges: [], histograms: []),
      )
    }
  }
}

fn default_buckets() -> List(#(Float, Int)) {
  [
    #(0.005, 0),
    #(0.01, 0),
    #(0.025, 0),
    #(0.05, 0),
    #(0.1, 0),
    #(0.25, 0),
    #(0.5, 0),
    #(1.0, 0),
    #(2.5, 0),
    #(5.0, 0),
    #(10.0, 0),
  ]
}

fn find_counter(
  counters: List(m.CounterMetric),
  name: String,
  labels: List(#(String, String)),
) -> Result(m.CounterMetric, Nil) {
  list.find(counters, fn(c) { c.name == name && c.labels == labels })
}

fn update_counter(
  counters: List(m.CounterMetric),
  name: String,
  labels: List(#(String, String)),
  new_value: Int,
) -> List(m.CounterMetric) {
  list.map(counters, fn(c) {
    case c.name == name && c.labels == labels {
      True -> m.CounterMetric(..c, value: new_value)
      False -> c
    }
  })
}

fn find_gauge(
  gauges: List(m.GaugeMetric),
  name: String,
  labels: List(#(String, String)),
) -> Result(m.GaugeMetric, Nil) {
  list.find(gauges, fn(g) { g.name == name && g.labels == labels })
}

fn update_gauge(
  gauges: List(m.GaugeMetric),
  name: String,
  labels: List(#(String, String)),
  new_value: Int,
) -> List(m.GaugeMetric) {
  list.map(gauges, fn(g) {
    case g.name == name && g.labels == labels {
      True -> m.GaugeMetric(..g, value: new_value)
      False -> g
    }
  })
}

fn find_histogram(
  histograms: List(m.HistogramMetric),
  name: String,
  labels: List(#(String, String)),
) -> Result(m.HistogramMetric, Nil) {
  list.find(histograms, fn(h) { h.name == name && h.labels == labels })
}

fn update_histogram(
  histograms: List(m.HistogramMetric),
  name: String,
  labels: List(#(String, String)),
  new_count: Int,
  new_sum: Float,
) -> List(m.HistogramMetric) {
  list.map(histograms, fn(h) {
    case h.name == name && h.labels == labels {
      True -> m.HistogramMetric(..h, count: new_count, sum: new_sum)
      False -> h
    }
  })
}

/// Start a metrics actor.
pub fn start() -> Result(Metrics, actor.StartError) {
  case start_linked() {
    Ok(started) -> Ok(started.data)
    Error(e) -> Error(e)
  }
}

/// Start and return the full Started record (for use with supervisors).
pub fn start_linked() -> Result(actor.Started(Metrics), actor.StartError) {
  actor.new(m.MetricsRegistry(counters: [], gauges: [], histograms: []))
  |> actor.on_message(handle_message)
  |> actor.start
}

pub fn inc_counter(
  metrics: Metrics,
  name: String,
  labels: List(#(String, String)),
) -> Nil {
  actor.send(metrics, IncCounter(name, labels))
}

pub fn set_gauge(
  metrics: Metrics,
  name: String,
  value: Int,
  labels: List(#(String, String)),
) -> Nil {
  actor.send(metrics, SetGauge(name, value, labels))
}

pub fn observe_histogram(
  metrics: Metrics,
  name: String,
  value: Float,
  labels: List(#(String, String)),
) -> Nil {
  actor.send(metrics, ObserveHistogram(name, value, labels))
}

pub fn get_metrics(metrics: Metrics) -> String {
  actor.call(metrics, waiting: 5000, sending: GetMetrics)
}

pub fn reset(metrics: Metrics) -> Nil {
  actor.call(metrics, waiting: 5000, sending: Reset)
}
