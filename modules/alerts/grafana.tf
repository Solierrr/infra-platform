# Alertas no Grafana Cloud: o contact point chama o worker-alerts, a política de notificação define a
# cadência e as regras avaliam as métricas que os serviços já mandam (OTLP). O Grafana Cloud roda
# fora do cluster, então continua avaliando com o cluster pausado.
#
# Contrato com o Worker: toda regra carrega alert_id, priority (P1 a P5), service_name e
# deployment_environment. Os dois últimos vêm das séries (agrupadas por serviço e ambiente).

locals {
  prometheus_uid = "grafanacloud-prom"

  # Parte comum das consultas: só o ambiente de produção
  env = "deployment_environment=\"${var.environment}\""

  http_requests = "http_server_requests_milliseconds_count"
  http_buckets  = "http_server_requests_milliseconds_bucket"
  py_requests   = "http_server_duration_milliseconds_count"

  rules = {
    A01 = {
      title    = "A01 Serviço sem dados"
      priority = "P1"
      category = "disponibilidade"
      # Pausa planejada do cluster (D29): o Worker não abre ticket enquanto ephemerality.json marca o cluster inativo
      silence_on_pause = true
      group            = "queda"
      for              = "5m"
      window           = 900
      # Serviços vistos na última hora que não aparecem nos últimos 10 minutos
      expr      = <<-PROMQL
        count by (service_name, deployment_environment) (last_over_time(target_info{${local.env}}[1h]))
        unless
        count by (service_name, deployment_environment) (last_over_time(target_info{${local.env}}[10m]))
      PROMQL
      threshold = 0
      summary   = "{{ $labels.service_name }} (${var.environment}): sem métricas há mais de 10 min"
      impact    = "O serviço parou de enviar métricas; provavelmente está fora do ar ou sem rede."
      steps     = "1. Abrir o dashboard do serviço. 2. Ver se o pod está de pé no cluster. 3. Ver os logs de erro."
    }
    A02 = {
      title     = "A02 Erros 5xx sustentados"
      priority  = "P2"
      category  = "erros"
      group     = "erros"
      for       = "10m"
      window    = 900
      expr      = <<-PROMQL
        (
          100 * sum by (service_name, deployment_environment) (rate(${local.http_requests}{${local.env},status=~"5.."}[5m]))
          / sum by (service_name, deployment_environment) (rate(${local.http_requests}{${local.env}}[5m]))
          and sum by (service_name, deployment_environment) (rate(${local.http_requests}{${local.env}}[5m])) > 0.05
        )
        or
        (
          100 * sum by (service_name, deployment_environment) (rate(${local.py_requests}{${local.env},http_status_code=~"5.."}[5m]))
          / sum by (service_name, deployment_environment) (rate(${local.py_requests}{${local.env}}[5m]))
          and sum by (service_name, deployment_environment) (rate(${local.py_requests}{${local.env}}[5m])) > 0.05
        )
      PROMQL
      threshold = 5
      summary   = "{{ $labels.service_name }} (${var.environment}): {{ $values.B.Value | printf \"%.1f\" }} % de respostas 5xx há 10 min"
      impact    = "Pelo menos 1 em cada 20 requisições falha há 10 minutos."
      steps     = "1. Abrir o dashboard do serviço. 2. Ver os logs de erro. 3. Checar a última publicação."
    }
    A03 = {
      title     = "A03 Latência p95 alta"
      priority  = "P3"
      category  = "latencia"
      group     = "latencia"
      for       = "10m"
      window    = 900
      expr      = <<-PROMQL
        histogram_quantile(0.95, sum by (le, service_name, deployment_environment) (rate(${local.http_buckets}{${local.env}}[5m])))
        and sum by (service_name, deployment_environment) (rate(${local.http_requests}{${local.env}}[5m])) > 0.05
      PROMQL
      threshold = 2000
      summary   = "{{ $labels.service_name }} (${var.environment}): latência p95 de {{ $values.B.Value | printf \"%.0f\" }} ms há 10 min"
      impact    = "Quem usa o serviço percebe lentidão: 1 em cada 20 requisições leva mais de 2 segundos."
      steps     = "1. Abrir o dashboard do serviço e ver as rotas mais lentas. 2. Ver o pool de conexões e as chamadas de saída. 3. Checar CPU e memória."
    }
    A04 = {
      title     = "A04 Memória da JVM alta"
      priority  = "P2"
      category  = "recursos"
      group     = "recursos"
      for       = "10m"
      window    = 900
      expr      = <<-PROMQL
        100 * sum by (service_name, deployment_environment) (jvm_memory_used_bytes{${local.env},area="heap"})
        / sum by (service_name, deployment_environment) (jvm_memory_max_bytes{${local.env},area="heap"})
      PROMQL
      threshold = 90
      summary   = "{{ $labels.service_name }} (${var.environment}): heap da JVM em {{ $values.B.Value | printf \"%.0f\" }} % há 10 min"
      impact    = "Com o heap quase cheio o serviço fica lento e pode ser reiniciado por falta de memória."
      steps     = "1. Abrir o dashboard do serviço e ver a memória e o GC. 2. Checar vazamento depois da última publicação. 3. Avaliar aumentar o limite do pod."
    }
  }
}

resource "grafana_folder" "alerts" {
  title = "alertas operacionais"
}

resource "grafana_contact_point" "worker_alerts" {
  name = "worker-alerts"

  webhook {
    url                       = var.webhook_url
    http_method               = "POST"
    authorization_scheme      = "Bearer"
    authorization_credentials = random_password.webhook.result
    max_alerts                = 50
  }
}

# Segundo contact point, só para a batida do heartbeat: não passa pelo caminho de tickets.
resource "grafana_contact_point" "heartbeat" {
  name = "worker-heartbeat"

  webhook {
    url                       = var.heartbeat_url
    http_method               = "POST"
    authorization_scheme      = "Bearer"
    authorization_credentials = random_password.webhook.result
    max_alerts                = 1
  }
}

# Substitui a política padrão do stack: tudo vai para o worker-alerts. A cadência dos avisos fica aqui,
# e não no Worker: repetição a cada 35 minutos (o Worker só cria ticket novo depois de 30).
resource "grafana_notification_policy" "root" {
  contact_point   = grafana_contact_point.worker_alerts.name
  group_by        = ["alert_id", "service_name", "deployment_environment"]
  group_wait      = "30s"
  group_interval  = "5m"
  repeat_interval = "35m"

  # A batida do heartbeat tem rota própria e não continua para o caminho de tickets
  policy {
    matcher {
      label = "heartbeat"
      match = "="
      value = "true"
    }
    contact_point   = grafana_contact_point.heartbeat.name
    group_by        = ["alert_id"]
    group_wait      = "0s"
    group_interval  = "1m"
    repeat_interval = "5m"
  }
}

# Regra sempre disparando: o Grafana Cloud repete a notificação a cada 5 minutos, e o Worker
# conta a ausência dessas batidas (mais de 15 minutos) como falha do caminho de alertas.
resource "grafana_rule_group" "heartbeat" {
  name             = "heartbeat"
  folder_uid       = grafana_folder.alerts.uid
  interval_seconds = 60

  rule {
    name           = "H00 Heartbeat"
    condition      = "C"
    for            = "0s"
    no_data_state  = "OK"
    exec_err_state = "OK"

    labels = {
      heartbeat              = "true"
      alert_id               = "H00"
      priority               = "P5"
      service_name           = "grafana-cloud"
      deployment_environment = var.environment
    }

    annotations = {
      summary     = "Heartbeat do Grafana Cloud"
      description = "Regra sempre ativa; a ausência da batida no worker-alerts abre o incidente H01."
    }

    data {
      ref_id         = "A"
      datasource_uid = "__expr__"

      relative_time_range {
        from = 600
        to   = 0
      }

      model = jsonencode({
        refId      = "A"
        type       = "math"
        expression = "1"
        datasource = { type = "__expr__", uid = "__expr__" }
      })
    }

    data {
      ref_id         = "C"
      datasource_uid = "__expr__"

      relative_time_range {
        from = 600
        to   = 0
      }

      model = jsonencode({
        refId      = "C"
        type       = "threshold"
        expression = "A"
        datasource = { type = "__expr__", uid = "__expr__" }
        conditions = [{
          evaluator = { type = "gt", params = [0] }
        }]
      })
    }
  }
}

resource "grafana_rule_group" "alerts" {
  for_each = local.rules

  name             = each.value.group
  folder_uid       = grafana_folder.alerts.uid
  interval_seconds = 60

  rule {
    name           = each.value.title
    condition      = "C"
    for            = each.value.for
    no_data_state  = "OK"
    exec_err_state = "OK"
    is_paused      = false

    labels = merge(
      {
        alert_id = each.key
        priority = each.value.priority
        category = each.value.category
      },
      lookup(each.value, "silence_on_pause", false) ? { silence_on_pause = "true" } : {}
    )

    annotations = {
      summary     = each.value.summary
      description = each.value.title
      impact      = each.value.impact
      first_steps = each.value.steps
      dashboard   = "/d/service-detail?var-environment=${var.environment}&var-service={{ $labels.service_name }}"
    }

    data {
      ref_id         = "A"
      datasource_uid = local.prometheus_uid

      relative_time_range {
        from = each.value.window
        to   = 0
      }

      model = jsonencode({
        refId         = "A"
        expr          = trimspace(each.value.expr)
        instant       = true
        range         = false
        intervalMs    = 1000
        maxDataPoints = 43200
        datasource    = { type = "prometheus", uid = local.prometheus_uid }
      })
    }

    data {
      ref_id         = "B"
      datasource_uid = "__expr__"

      relative_time_range {
        from = each.value.window
        to   = 0
      }

      model = jsonencode({
        refId      = "B"
        type       = "reduce"
        expression = "A"
        reducer    = "last"
        datasource = { type = "__expr__", uid = "__expr__" }
        settings   = { mode = "dropNN" }
      })
    }

    data {
      ref_id         = "C"
      datasource_uid = "__expr__"

      relative_time_range {
        from = each.value.window
        to   = 0
      }

      model = jsonencode({
        refId      = "C"
        type       = "threshold"
        expression = "B"
        datasource = { type = "__expr__", uid = "__expr__" }
        conditions = [{
          evaluator = { type = "gt", params = [each.value.threshold] }
        }]
      })
    }
  }
}
