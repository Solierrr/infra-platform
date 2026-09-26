variable "gcp_project_id" {
  type        = string
  description = "Projeto GCP && Firebase"
  default     = "solaria-authenticator"
}

variable "gcp_region" {
  type        = string
  description = "Região do cluster GCP"
  default     = "us-central1"
}

variable "gcp_zone" {
  type        = string
  description = "Zona do cluster GCP"
  default     = "us-central1-a"
}

variable "authorized_ip_cidr" {
  type        = string
  description = "IP público (formato CIDR, ex: 1.2.3.4/32) autorizado a acessar o control plane do GKE. Muda conforme a rede/máquina de quem roda o apply"
  default     = "189.57.250.90/32"
}

variable "domain" {
  type        = string
  description = "Domínio raiz na Cloudflare (zona DNS) usado pelo Ingress público e pelo desafio DNS-01"
  default     = "solarianetwork.site"
}

variable "infisical_client_id" {
  type        = string
  description = "Client ID da Machine Identity gke-sync do Infisical (Universal Auth)"
  sensitive   = true
}

variable "infisical_client_secret" {
  type        = string
  description = "Client Secret da Machine Identity gke-sync do Infisical (Universal Auth)"
  sensitive   = true
}

variable "infisical_project_id" {
  type        = string
  description = "Workspace ID do projeto Infisical (dashboard do Infisical -> Project Settings)"
  default     = "2296d19c-5f3b-41e1-afa3-fcde39966a71"
}