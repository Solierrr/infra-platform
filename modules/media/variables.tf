variable "gcp_project_id" {
  type        = string
  description = "Projeto GCP onde o bucket e a conta de serviço são criados"
}

variable "bucket_location" {
  type        = string
  description = "Região do bucket de mídia, a mesma do cluster para não pagar tráfego entre regiões"
}

variable "bucket_name" {
  type        = string
  description = "Nome do bucket de mídia das mensagens (único no mundo)"
  default     = "solier-messenger-media"
}

variable "retention_days" {
  type        = number
  description = "Idade em dias a partir da qual o ciclo de vida apaga o arquivo. A retenção exata de 7 dias é do api-messenger (MEDIA_TTL); o ciclo conta em dias e apaga em até cerca de 24 horas, por isso fica um dia acima"
  default     = 8
}

variable "cors_origins" {
  type        = list(string)
  description = "Origens web autorizadas a enviar e baixar direto do bucket com o link assinado"
  default     = ["https://solarianetwork.site"]
}

variable "cluster_ready" {
  type        = string
  description = "ID do node pool: o Secret só é criado depois que o cluster tem nós"
}
