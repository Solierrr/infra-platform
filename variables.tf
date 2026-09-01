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

variable "argocd_admin_password_hash" {
  type        = string
  description = "Hash bcrypt da senha fixa do admin do ArgoCD (gere localmente com bcrypt, nunca a senha em texto puro)"
  sensitive   = true
}

variable "cloudflare_api_token" {
  type        = string
  description = "Token da API do Cloudflare (permissão Zone:DNS:Edit na zona solaria.com) usado pelo cert-manager no desafio DNS-01"
  sensitive   = true
}

variable "acme_email" {
  type        = string
  description = "E-mail usado para registrar a conta ACME no Let's Encrypt (avisos de expiração de certificado)"
}