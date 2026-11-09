# PRD — `vitals`

## Visão

Métricas Prometheus e endpoints de health check para aplicações Gleam prontas para Kubernetes e Docker Compose, com o mínimo de configuração possível. Uma aplicação que adiciona `vitals` ao `gleam.toml` tem `/health`, `/health/live`, `/health/ready` e `/metrics` funcionando em minutos.

## Problema

Aplicações Gleam em produção precisam expor sinais de saúde para orquestradores (Kubernetes, Fly.io, Railway) e sistemas de monitoramento (Prometheus, Grafana). Não existe nenhuma solução padronizada no ecossistema — cada projeto implementa isso do zero com `mist` ou `wisp`, sem convenções compartilhadas. O resultado são implementações inconsistentes e frequentemente incompletas (sem `/health/ready`, sem formato Prometheus correto).

## Público-alvo

Desenvolvedores Gleam fazendo deploy de aplicações em ambientes com orquestração de containers ou monitoramento baseado em Prometheus. Pré-requisito: familiaridade básica com HTTP servers em Gleam (mist).

## Escopo da v1.0

**Entra:**
- Coleta de métricas: contadores, gauges, histogramas com labels
- Exposição no formato Prometheus text (`text/plain; version=0.0.4`)
- Endpoints `/health`, `/health/live`, `/health/ready`, `/metrics`
- Integração com supervision trees via `start_linked`

**Não entra na v1.0:**
- Push para Prometheus Pushgateway
- Integração com OpenTelemetry
- Autenticação nos endpoints
- Rate limiting nos endpoints de métricas

---

## Problemas a resolver antes da publicação

### P1 — `server.start` usa `let assert` e pode travar (bloqueador de confiabilidade)

**Problema:** Se a porta já está em uso, `mist.start` retorna `Error(...)` e o `let assert Ok(_)` causa um crash sem retorno tratável.

**Decisão:** Mudar a assinatura para retornar `Result`:

```gleam
// Antes — trava se porta ocupada
pub fn start(port: Int, ...) -> HealthServer

// Depois — retorna erro tratável
pub fn start(port: Int, ...) -> Result(HealthServer, String)
```

O `let assert` interno precisa ser substituído por um `case` que retorna `Error("Failed to bind to port N: ...")`.

### P2 — `get_ready_checks` não consegue expressar falha (bloqueador de utilidade)

**Problema:** A callback tem assinatura `fn() -> List(String)` — apenas lista os serviços prontos. Não há como expressar que um serviço está em estado de erro, qual o erro, ou retornar HTTP 503 quando o sistema não está pronto.

**Decisão:** Mudar a assinatura da callback e o tipo de retorno do endpoint `/health/ready`:

```gleam
// A callback retorna ChannelStatus em vez de String
pub fn start(
  port port: Int,
  metrics metrics: Metrics,
  get_ready_checks get_ready_checks: fn() -> List(health.ChannelStatus),
) -> Result(HealthServer, String)
```

O handler `/health/ready` passa a retornar HTTP 503 se qualquer `ChannelStatus` tiver `ready: False`.

### P3 — Sem testes dos endpoints HTTP (bloqueador de confiança)

**Problema:** `server_test.gleam` verifica apenas start/stop. O comportamento principal — responses corretas de `/health`, `/health/ready`, `/metrics` — nunca é testado automaticamente.

**Decisão:** Adicionar testes de integração em `test/vitals/server_integration_test.gleam`:

- `health_endpoint_returns_200_with_json_test`
- `live_endpoint_returns_ok_test`
- `ready_endpoint_returns_503_when_check_fails_test`
- `metrics_endpoint_returns_prometheus_format_test`
- `unknown_path_returns_404_test`

Implementação: iniciar o servidor em porta 0, fazer requests HTTP com `gleam_hackney` (dev dependency), verificar respostas.

### P4 — `io.println` hardcoded no start

**Problema:** O servidor imprime no stdout incondicionalmente. Em produção, logs são gerenciados pelo framework de logging da aplicação.

**Decisão:** Remover o `io.println`. A porta real após bind pode ser exposta via campo `HealthServer.port` (já existe), e quem quiser logar pode fazer isso após chamar `start`.

### P5 — `server.stop` é no-op

**Problema:** A função existe mas não faz nada, o que é enganoso.

**Decisão:** Investigar se `mist` em 6.x expõe alguma forma de parar o servidor. Se não: remover `stop` da API pública e documentar no README que o servidor roda enquanto a aplicação vive (que é o caso de uso real). Não manter uma API que mente sobre o que faz.

---

## API pública alvo para v1.0

```gleam
// vitals/metrics.gleam — tipos e formatação pura
pub fn format_metrics(
  counters: List(CounterMetric),
  gauges: List(GaugeMetric),
  histograms: List(HistogramMetric),
) -> String

// vitals/metrics_actor.gleam — coleta thread-safe
pub fn start() -> Result(Metrics, actor.StartError)
pub fn start_linked() -> Result(actor.Started(Metrics), actor.StartError)
pub fn inc_counter(m: Metrics, name: String, labels: List(#(String, String))) -> Nil
pub fn set_gauge(m: Metrics, name: String, value: Int, labels: List(#(String, String))) -> Nil
pub fn observe_histogram(m: Metrics, name: String, value: Float, labels: List(#(String, String))) -> Nil
pub fn get_metrics(m: Metrics) -> String

// vitals/health.gleam — tipos e serialização
pub type ChannelStatus { ChannelStatus(name: String, ready: Bool, error: Option(String)) }
pub fn channel_ok(name: String) -> ChannelStatus
pub fn channel_error(name: String, reason: String) -> ChannelStatus

// vitals/server.gleam — servidor HTTP
pub fn start(
  port port: Int,
  metrics metrics: metrics_actor.Metrics,
  get_ready_checks get_ready_checks: fn() -> List(health.ChannelStatus),
) -> Result(HealthServer, String)
```

`channel_ok` e `channel_error` são novos construtores de conveniência que tornam a callback mais ergonômica:

```gleam
server.start(
  port: 9090,
  metrics: m,
  get_ready_checks: fn() {
    [
      health.channel_ok("database"),
      case cache_connected() {
        True  -> health.channel_ok("cache")
        False -> health.channel_error("cache", "connection refused")
      },
    ]
  },
)
```

---

## Critérios de aceitação para publicação

- [ ] `gleam.toml`: `user` preenchido, `links` com URL do repositório
- [ ] `README.md` com: descrição, instalação, exemplo end-to-end com métricas + health, diagrama dos endpoints
- [ ] `server.start` retorna `Result(HealthServer, String)` — sem `let assert`
- [ ] `get_ready_checks` aceita `fn() -> List(health.ChannelStatus)`
- [ ] `/health/ready` retorna 503 quando qualquer check tem `ready: False`
- [ ] `io.println` removido de `server.start`
- [ ] `server.stop` removido ou funcional (não no-op silencioso)
- [ ] `health.channel_ok` e `health.channel_error` implementados
- [ ] Testes de integração HTTP: ≥ 5 casos cobrindo todos os endpoints
- [ ] `start_linked` no metrics actor (já existe) — verificar se também precisa no server
- [ ] `gleam docs build` sem erros
- [ ] CI: `.github/workflows/test.yml`
- [ ] `gleam test` verde

## Pendências de decisão

- **`metrics_actor.reset`:** útil em testes mas perigoso em produção (apaga todas as métricas). Avaliar tornar `pub(internal)` ou aceitar o tradeoff documentando que é para uso em testes.
- **`# HELP` no formato Prometheus:** adicionar linha `# HELP metric_name description` requer que o usuário forneça uma descrição no momento do `inc_counter` / `set_gauge`. Isso muda a assinatura de todas as funções de coleta. Avaliar se vale para v1 ou vai para v2.
- **Histograma com buckets customizáveis:** atualmente hardcoded. Aceitar `buckets: List(Float)` como parâmetro de `observe_histogram` ou definir buckets no momento de criação da métrica são duas abordagens possíveis. Decidir antes de publicar.
- **`gleam_hackney` como dev dependency nos testes de integração:** adicionar ao `gleam.toml` apenas em `[dev_dependencies]`.
