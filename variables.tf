variable "gcp_project_id" {
  type        = string
  description = "Projeto GCP && Firebase"
  default     = "solaria-authenticator"
}

variable "gcp_region" {
  type        = string
  description = "Região do cluster GCP"
  default = "us-central1"
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
