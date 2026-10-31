output "cloudflare_api_token" {
  description = "Token da Cloudflare lido da pasta /cloudflare"
  value       = data.infisical_secrets.cloudflare.secrets["CLOUDFLARE_API_TOKEN"].value
  sensitive   = true
}

output "acme_email" {
  value = data.infisical_secrets.terraform.secrets["ACME_EMAIL"].value
}

output "argocd_admin_password_hash" {
  value     = data.infisical_secrets.terraform.secrets["ARGOCD_ADMIN_PASSWORD_HASH"].value
  sensitive = true
}

output "grafana_admin_password" {
  description = "Senha do usuário admin do Grafana, gerada pelo Terraform"
  value       = random_password.grafana_admin.result
  sensitive   = true
}

output "cloudflare_token_manager" {
  description = "Token mestre da Cloudflare (API Tokens Edit), lido da pasta /infisical"
  value       = data.infisical_secrets.root_credentials.secrets["CLOUDFLARE_TOKEN_MANAGER"].value
  sensitive   = true
}

# nonsensitive: o e-mail não é segredo (só não vai ao repositório) e o Terraform não aceita valor
# sensível como chave de for_each, que é como o módulo cloudflare decide o que criar
output "dev_emails" {
  description = "E-mails de todos os desenvolvedores do cadastro DEVS (pasta /team): quem passa pelo Cloudflare Access"
  value       = nonsensitive(distinct(local.dev_emails))

  precondition {
    condition     = length(local.dev_admin_emails) > 0
    error_message = "O cadastro DEVS precisa ter pelo menos um desenvolvedor com \"admin\": true, senão ninguém administra o Argo CD e o Grafana."
  }
}

output "dev_admin_emails" {
  description = "E-mails marcados como admin no cadastro DEVS: administradores do Argo CD e do Grafana"
  value       = nonsensitive(distinct(local.dev_admin_emails))
}

output "dev_phones" {
  description = "Telefones (só dígitos, com DDI) de quem recebe alerta por WhatsApp"
  value       = distinct(local.dev_phones)
  sensitive   = true
}
