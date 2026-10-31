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

variable "argocd_oidc_issuer" {
  type        = string
  description = "Emissor OIDC do Cloudflare Access para o login do Argo CD. Vazio mantém só o login por senha"
  default     = ""
}

variable "argocd_oidc_client_id" {
  type    = string
  default = ""
}

variable "argocd_oidc_client_secret" {
  type      = string
  default   = ""
  sensitive = true
}

variable "argocd_admin_emails" {
  type        = list(string)
  description = "E-mails que entram no Argo CD como administradores pelo SSO"
  default     = []
}

variable "kong_source_ranges" {
  type        = list(string)
  description = "Faixas de IP que podem chegar ao Kong (loadBalancerSourceRanges). Vazio deixa o Kong aberto a qualquer origem"
  default     = []
}
