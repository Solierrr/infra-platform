output "zone_id" {
  value = data.cloudflare_zone.primary.zone_id
}

output "account_id" {
  value = data.cloudflare_zone.primary.account.id
}

output "argocd_oidc_issuer" {
  description = "Emissor OIDC do Cloudflare Access para o Argo CD (vazio com o Access desligado)"
  value       = local.access_enabled ? "https://${var.access_team_domain}/cdn-cgi/access/sso/oidc/${cloudflare_zero_trust_access_application.argocd_sso[0].saas_app.client_id}" : ""
}

output "argocd_oidc_client_id" {
  value = local.access_enabled ? cloudflare_zero_trust_access_application.argocd_sso[0].saas_app.client_id : ""
}

output "argocd_oidc_client_secret" {
  value     = local.access_enabled ? cloudflare_zero_trust_access_application.argocd_sso[0].saas_app.client_secret : ""
  sensitive = true
}
