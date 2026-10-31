# Segredos do worker-alerts. A API de Workers da Cloudflare (provider v5) só grava segredo junto do
# script inteiro, o que brigaria com o `wrangler deploy` do repositório do Worker. Por isso cada
# segredo é gravado direto na API de segredos do script, que o deploy não apaga.
#
# O Worker não consulta o Infisical em execução: o Terraform copia o valor para a Cloudflare.

resource "random_password" "webhook" {
  length  = 48
  special = false
}

locals {
  secrets = merge(var.worker_secrets, {
    WEBHOOK_TOKEN     = random_password.webhook.result
    ALERT_GRAFANA_URL = var.grafana_url
  })
  secret_names = toset(concat(nonsensitive(keys(var.worker_secrets)), ["WEBHOOK_TOKEN", "ALERT_GRAFANA_URL"]))
}

resource "terraform_data" "worker_secret" {
  for_each = local.secret_names

  # Regrava quando o valor muda; só o hash fica no state além do próprio valor sensível
  triggers_replace = sha256(local.secrets[each.value])

  input = {
    name = each.value
  }

  lifecycle {
    precondition {
      condition     = can(regex("^[^\"\\\\\\n\\r]+$", local.secrets[each.value]))
      error_message = "O segredo ${each.value} tem aspas, barra invertida ou quebra de linha, que o corpo JSON da gravação não escapa."
    }
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      curl --fail-with-body --silent --show-error --request PUT \
        --url "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT/workers/scripts/$CF_SCRIPT/secrets" \
        --header "Authorization: Bearer $CF_TOKEN" \
        --header "Content-Type: application/json" \
        --data "{\"name\":\"$SECRET_NAME\",\"text\":\"$SECRET_VALUE\",\"type\":\"secret_text\"}" > /dev/null
    EOT
    environment = {
      CF_ACCOUNT   = var.account_id
      CF_SCRIPT    = var.worker_name
      CF_TOKEN     = var.cloudflare_api_token
      SECRET_NAME  = each.value
      SECRET_VALUE = local.secrets[each.value]
    }
  }
}
