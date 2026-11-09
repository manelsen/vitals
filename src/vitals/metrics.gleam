//// Prometheus metrics types and text-format rendering.
////
//// Provides counters, gauges, and histograms with label support.
//// Output is compatible with the Prometheus text exposition format.
////
//// ## Usage
////
//// ```gleam
//// let output = metrics.format_metrics(
////   counters: [metrics.CounterMetric("http_requests", 42, [#("method", "GET")])],
////   gauges: [metrics.GaugeMetric("active_conns", 7, [])],
////   histograms: [],
//// )
//// ```

import gleam/float
import gleam/int
import gleam/list
import gleam/string

pub type MetricsRegistry {
  MetricsRegistry(
    counters: List(CounterMetric),
    gauges: List(GaugeMetric),
    histograms: List(HistogramMetric),
  )
}

pub type CounterMetric {
  CounterMetric(name: String, value: Int, labels: List(#(String, String)))
}

pub type GaugeMetric {
  GaugeMetric(name: String, value: Int, labels: List(#(String, String)))
}

pub type HistogramMetric {
  HistogramMetric(
    name: String,
    count: Int,
    sum: Float,
    buckets: List(#(Float, Int)),
    labels: List(#(String, String)),
  )
}

/// Render counters, gauges, and histograms to Prometheus text format.
pub fn format_metrics(
  counters counters: List(CounterMetric),
  gauges gauges: List(GaugeMetric),
  histograms histograms: List(HistogramMetric),
) -> String {
  let lines =
    list.append(format_counters(counters), format_gauges(gauges))
    |> list.append(format_histograms(histograms))
  string.join(lines, "\n")
}

fn format_labels(labels: List(#(String, String))) -> String {
  case labels {
    [] -> ""
    _ -> {
      let pairs =
        list.map(labels, fn(pair) { pair.0 <> "=\"" <> pair.1 <> "\"" })
      "{" <> string.join(pairs, ",") <> "}"
    }
  }
}

fn format_counters(counters: List(CounterMetric)) -> List(String) {
  list.map(counters, fn(c) {
    let labels = format_labels(c.labels)
    "# TYPE " <> c.name <> " counter\n" <> c.name <> labels <> " " <> int.to_string(c.value)
  })
}

fn format_gauges(gauges: List(GaugeMetric)) -> List(String) {
  list.map(gauges, fn(g) {
    let labels = format_labels(g.labels)
    "# TYPE " <> g.name <> " gauge\n" <> g.name <> labels <> " " <> int.to_string(g.value)
  })
}

fn format_histograms(histograms: List(HistogramMetric)) -> List(String) {
  list.map(histograms, fn(h) {
    let labels = format_labels(h.labels)
    let sum_str = float.to_string(h.sum)
    "# TYPE " <> h.name <> " histogram\n"
    <> h.name <> "_count" <> labels <> " " <> int.to_string(h.count) <> "\n"
    <> h.name <> "_sum" <> labels <> " " <> sum_str
  })
}
