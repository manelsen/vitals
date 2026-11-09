{application, vitals, [
    {vsn, "1.0.0"},
    {applications, [gleam_erlang,
                    gleam_http,
                    gleam_json,
                    gleam_otp,
                    gleam_stdlib,
                    gleeunit,
                    mist]},
    {description, "Prometheus metrics and Kubernetes health check endpoints for Gleam"},
    {modules, [vitals_test]},
    {registered, []}
]}.
