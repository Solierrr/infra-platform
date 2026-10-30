variable "gcp_zone" {
  type        = string
  description = "Zona do cluster GKE"
}

variable "gcp_region" {
  type        = string
  description = "Região da rede e do IP público do Kong"
}

variable "authorized_ip_cidr" {
  type        = string
  description = "IP público (formato CIDR) autorizado a acessar o control plane do GKE"
}

variable "domain" {
  type        = string
  description = "Domínio raiz usado pelo Ingress do Argo CD"
}

variable "cloudflare_api_token" {
  type        = string
  description = "Token da Cloudflare para o desafio DNS-01 do cert-manager"
  sensitive   = true
}

variable "acme_email" {
  type        = string
  description = "E-mail da conta ACME usada pelos ClusterIssuers"
}

variable "argocd_admin_password_hash" {
  type        = string
  description = "Hash bcrypt da senha do admin do Argo CD"
  sensitive   = true
}
