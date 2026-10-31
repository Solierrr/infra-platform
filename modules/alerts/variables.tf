variable "account_id" {
  type        = string
  description = "ID da conta Cloudflare onde o worker-alerts roda"
}

variable "worker_name" {
  type        = string
  description = "Nome do script do Worker na Cloudflare"
  default     = "worker-alerts"
}

variable "webhook_url" {
  type        = string
  description = "URL pública que o Grafana chama (rota /grafana do Worker)"
  default     = "https://alerts.solarianetwork.site/grafana"
}

variable "cloudflare_api_token" {
  type        = string
  sensitive   = true
  description = "Token da Cloudflare com Workers Scripts Write, usado para gravar os segredos do Worker"
}

variable "worker_secrets" {
  type        = map(string)
  sensitive   = true
  description = "Segredos do Worker que vêm do Infisical (/alerts), por nome. O WEBHOOK_TOKEN é gerado aqui"
}

variable "grafana_url" {
  type        = string
  description = "Grafana com os dashboards, base dos links dos tickets"
  default     = "https://grafana.solarianetwork.site"
}

variable "environment" {
  type        = string
  description = "Ambiente que gera alerta (rótulo deployment_environment)"
  default     = "prod"
}
