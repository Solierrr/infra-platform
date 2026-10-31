variable "infisical_project_id" {
  type        = string
  description = "Workspace ID do projeto Infisical"
}

variable "cluster_ready" {
  type        = string
  description = "ID do node pool: os Secrets só são criados depois que o cluster tem nós"
}

variable "grafana_admin_emails" {
  type        = list(string)
  description = "E-mails que entram no Grafana como administradores pelo Cloudflare Access; os demais entram como visualizadores"
}
