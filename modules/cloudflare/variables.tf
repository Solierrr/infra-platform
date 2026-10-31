variable "domain" {
  type        = string
  description = "Domínio raiz na Cloudflare (zona DNS) usado pelo Ingress público e pelo desafio DNS-01"
  default     = "solarianetwork.site"
}

variable "access_allowed_emails" {
  type        = list(string)
  description = "E-mails autorizados a abrir as ferramentas de infra e a documentação das APIs pelo Cloudflare Access. Vazio não cria nenhum recurso do Access"
  default     = []
}

variable "access_idp_ids" {
  type        = list(string)
  description = "IDs dos provedores de identidade do Zero Trust aceitos no login (hoje, o Google criado no painel)"
  default     = ["ea1907c3-68d2-4132-8d22-5731327d53ff"]
}

variable "access_session_duration" {
  type        = string
  description = "Duração da sessão do Cloudflare Access depois do login"
  default     = "8h"
}

variable "kong_ip" {
  type        = string
  description = "IP público do Kong para onde os registros DNS apontam"
}

variable "access_team_domain" {
  type        = string
  description = "Domínio da equipe do Zero Trust, usado no emissor OIDC do Argo CD"
  default     = "long-hat-66b3.cloudflareaccess.com"
}

variable "sandbox_origin" {
  type        = string
  description = "Hostname do Render que serve o portal do sandbox (QA); o registro sandbox aponta para ele"
  default     = "web-sandbox-qa.onrender.com"
}
