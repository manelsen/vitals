import gleeunit
import gleeunit/should
import vitals/metrics_actor
import vitals/server

pub fn main() {
  gleeunit.main()
}

pub fn start_and_stop_server_test() {
  let assert Ok(m) = metrics_actor.start()
  let srv = server.start(port: 0, metrics: m, get_ready_checks: fn() { ["db"] })
  srv.port |> should.equal(0)
  server.stop(srv) |> should.equal(Nil)
}
