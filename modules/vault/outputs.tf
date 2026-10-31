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

output "access_extra_emails" {
  description = "E-mails extras do Cloudflare Access, lidos de ACCESS_EXTRA_EMAILS (separados por vírgula) na pasta /terraform. Ficam no Infisical para não irem a um repositório público"
  # nonsensitive: o e-mail não é segredo (só não vai ao repositório) e o Terraform não aceita
  # valor sensível como chave de for_each, que é como o módulo cloudflare decide o que criar
  value = nonsensitive([
    for email in split(",", try(data.infisical_secrets.terraform.secrets["ACCESS_EXTRA_EMAILS"].value, "")) :
    trimspace(email) if trimspace(email) != ""
  ])
}
