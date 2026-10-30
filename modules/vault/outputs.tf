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
