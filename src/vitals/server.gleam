//// Health and metrics HTTP server.
////
//// Serves the following endpoints:
////
//// - `GET /health`       — basic liveness with uptime
//// - `GET /health/live`  — simple liveness probe (returns "ok")
//// - `GET /health/ready` — readiness probe with channel status
//// - `GET /metrics`      — Prometheus text format metrics
////
//// ## Usage
////
//// ```gleam
//// let assert Ok(m) = metrics_actor.start()
//// let srv = server.start(
////   port: 9090,
////   metrics: m,
////   get_ready_checks: fn() { ["database", "cache"] },
//// )
//// ```

import gleam/bytes_tree
import gleam/http/request
import gleam/http/response
import gleam/int
import gleam/io
import gleam/list
import gleam/option
import mist.{type Connection, type ResponseData}
import vitals/health
import vitals/metrics_actor

pub type HealthServer {
  HealthServer(start_time_ms: Int, port: Int, metrics: metrics_actor.Metrics)
}

@external(erlang, "vitals_ffi", "current_timestamp")
fn current_timestamp() -> Int

fn uptime_seconds(start_time_ms: Int) -> Int {
  { current_timestamp() - start_time_ms } / 1000
}

fn handle_request(
  req: request.Request(Connection),
  metrics: metrics_actor.Metrics,
  start_time_ms: Int,
  get_ready_checks: fn() -> List(String),
) -> response.Response(ResponseData) {
  case request.path_segments(req) {
    ["health"] -> handle_health(start_time_ms)
    ["health", "live"] -> handle_live()
    ["health", "ready"] -> handle_ready(start_time_ms, get_ready_checks)
    ["metrics"] -> handle_metrics(metrics)
    _ -> handle_not_found()
  }
}

fn handle_health(start_time_ms: Int) -> response.Response(ResponseData) {
  let body =
    health.health_status_to_json(health.HealthStatus(
      status: "ok",
      uptime_seconds: uptime_seconds(start_time_ms),
    ))
  response.new(200)
  |> response.set_body(mist.Bytes(bytes_tree.from_string(body)))
  |> response.set_header("content-type", "application/json")
}

fn handle_live() -> response.Response(ResponseData) {
  response.new(200)
  |> response.set_body(mist.Bytes(bytes_tree.from_string("ok")))
}

fn handle_ready(
  start_time_ms: Int,
  get_ready_checks: fn() -> List(String),
) -> response.Response(ResponseData) {
  let channels =
    list.map(get_ready_checks(), fn(name) {
      health.ChannelStatus(name: name, ready: True, error: option.None)
    })
  let body =
    health.readiness_status_to_json(health.ReadinessStatus(
      status: "ok",
      uptime_seconds: uptime_seconds(start_time_ms),
      channels_ready: channels,
    ))
  response.new(200)
  |> response.set_body(mist.Bytes(bytes_tree.from_string(body)))
  |> response.set_header("content-type", "application/json")
}

fn handle_metrics(metrics: metrics_actor.Metrics) -> response.Response(ResponseData) {
  response.new(200)
  |> response.set_body(
    mist.Bytes(bytes_tree.from_string(metrics_actor.get_metrics(metrics))),
  )
  |> response.set_header("content-type", "text/plain; version=0.0.4")
}

fn handle_not_found() -> response.Response(ResponseData) {
  response.new(404)
  |> response.set_body(mist.Bytes(bytes_tree.from_string("Not Found")))
}

/// Start the health and metrics server on the given port.
///
/// `get_ready_checks` is called on every `/health/ready` request and should
/// return the names of subsystems that are currently healthy.
pub fn start(
  port port: Int,
  metrics metrics: metrics_actor.Metrics,
  get_ready_checks get_ready_checks: fn() -> List(String),
) -> HealthServer {
  let start_time_ms = current_timestamp()
  let assert Ok(_) =
    fn(req: request.Request(Connection)) -> response.Response(ResponseData) {
      handle_request(req, metrics, start_time_ms, get_ready_checks)
    }
    |> mist.new
    |> mist.bind("0.0.0.0")
    |> mist.port(port)
    |> mist.start
  io.println("vitals: health server listening on port " <> int.to_string(port))
  HealthServer(start_time_ms: start_time_ms, port: port, metrics: metrics)
}

/// Stop the health server. Currently a no-op; mist does not expose a stop API.
pub fn stop(_server: HealthServer) -> Nil {
  Nil
}
