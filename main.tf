# Composição dos módulos. Cada módulo cuida de uma área:
#   modules/cluster     rede, GKE, Kong, Argo CD e cert-manager
#   modules/vault       leitura do Infisical e Secrets do cluster
#   modules/cloudflare  DNS, cache e Cloudflare Access
#   modules/cloudflare-token  token operacional da Cloudflare (permissões)
# Os blocos moved no fim preservam o state de antes da divisão em módulos.

module "vault" {
  source               = "./modules/vault"
  infisical_project_id = var.infisical_project_id
  cluster_ready        = module.cluster.node_pool_id
}

module "cluster" {
  source                     = "./modules/cluster"
  gcp_zone                   = var.gcp_zone
  gcp_region                 = var.gcp_region
  authorized_ip_cidr         = var.authorized_ip_cidr
  domain                     = var.domain
  cloudflare_api_token       = module.vault.cloudflare_api_token
  acme_email                 = module.vault.acme_email
  argocd_admin_password_hash = module.vault.argocd_admin_password_hash
  argocd_oidc_issuer         = module.cloudflare.argocd_oidc_issuer
  argocd_oidc_client_id      = module.cloudflare.argocd_oidc_client_id
  argocd_oidc_client_secret  = module.cloudflare.argocd_oidc_client_secret
  argocd_admin_emails        = var.access_allowed_emails
  kong_source_ranges         = module.cloudflare.edge_ipv4_cidrs
}

module "cloudflare" {
  source                  = "./modules/cloudflare"
  domain                  = var.domain
  kong_ip                 = module.cluster.kong_ip
  access_allowed_emails   = var.access_allowed_emails
  access_idp_ids          = var.access_idp_ids
  access_session_duration = var.access_session_duration
}

module "cloudflare_token" {
  source     = "./modules/cloudflare-token"
  providers  = { cloudflare = cloudflare.manager }
  zone_id    = module.cloudflare.zone_id
  account_id = module.cloudflare.account_id
}

# Adota o token "Edit zone DNS" que já existia no painel (mesmo valor, que já
# está no Infisical). Depois do primeiro apply este bloco não faz mais nada.
import {
  to = module.cloudflare_token.cloudflare_api_token.operational
  id = "95b0714a82dc26c67af9297941786eae"
}

moved {
  from = google_compute_network.vpc
  to   = module.cluster.google_compute_network.vpc
}

moved {
  from = google_compute_subnetwork.subnet
  to   = module.cluster.google_compute_subnetwork.subnet
}

moved {
  from = google_container_cluster.primary
  to   = module.cluster.google_container_cluster.primary
}

moved {
  from = google_container_node_pool.primary_nodes
  to   = module.cluster.google_container_node_pool.primary_nodes
}

moved {
  from = helm_release.argocd
  to   = module.cluster.helm_release.argocd
}

moved {
  from = google_compute_address.kong_ip
  to   = module.cluster.google_compute_address.kong_ip
}

moved {
  from = helm_release.kong
  to   = module.cluster.helm_release.kong
}

moved {
  from = helm_release.cert_manager
  to   = module.cluster.helm_release.cert_manager
}

moved {
  from = kubernetes_secret.cloudflare_api_token
  to   = module.cluster.kubernetes_secret.cloudflare_api_token
}

moved {
  from = kubectl_manifest.letsencrypt_prod_issuer
  to   = module.cluster.kubectl_manifest.letsencrypt_prod_issuer
}

moved {
  from = kubectl_manifest.letsencrypt_http01_issuer
  to   = module.cluster.kubectl_manifest.letsencrypt_http01_issuer
}

moved {
  from = cloudflare_dns_record.wildcard
  to   = module.cloudflare.cloudflare_dns_record.wildcard
}

moved {
  from = cloudflare_dns_record.api_recommendation
  to   = module.cloudflare.cloudflare_dns_record.api_recommendation
}

moved {
  from = cloudflare_ruleset.api_recommendation_cache
  to   = module.cloudflare.cloudflare_ruleset.api_recommendation_cache
}

moved {
  from = kubernetes_secret.api_messenger
  to   = module.vault.kubernetes_secret.api_messenger
}

moved {
  from = kubernetes_secret.api_notify
  to   = module.vault.kubernetes_secret.api_notify
}

moved {
  from = kubernetes_secret.api_core
  to   = module.vault.kubernetes_secret.api_core
}

moved {
  from = kubernetes_secret.api_auth
  to   = module.vault.kubernetes_secret.api_auth
}

moved {
  from = kubernetes_secret.api_auth_jwt_keystore
  to   = module.vault.kubernetes_secret.api_auth_jwt_keystore
}

moved {
  from = kubernetes_secret.api_recommendation
  to   = module.vault.kubernetes_secret.api_recommendation
}

moved {
  from = kubernetes_secret.api_mcp
  to   = module.vault.kubernetes_secret.api_mcp
}

moved {
  from = kubernetes_secret.ai_assistant
  to   = module.vault.kubernetes_secret.ai_assistant
}

moved {
  from = kubernetes_secret.ai_validation
  to   = module.vault.kubernetes_secret.ai_validation
}

moved {
  from = kubernetes_secret.google_registry
  to   = module.vault.kubernetes_secret.google_registry
}

moved {
  from = kubernetes_secret.feeddb
  to   = module.vault.kubernetes_secret.feeddb
}

moved {
  from = kubernetes_secret.database_bootstrap
  to   = module.vault.kubernetes_secret.database_bootstrap
}

moved {
  from = kubernetes_secret.ai_accessibility
  to   = module.vault.kubernetes_secret.ai_accessibility
}

moved {
  from = kubernetes_secret.ai_geographic
  to   = module.vault.kubernetes_secret.ai_geographic
}

moved {
  from = kubernetes_secret.ai_operational
  to   = module.vault.kubernetes_secret.ai_operational
}

moved {
  from = kubernetes_secret.api_email
  to   = module.vault.kubernetes_secret.api_email
}

moved {
  from = kubernetes_secret.infra_broker
  to   = module.vault.kubernetes_secret.infra_broker
}

moved {
  from = random_password.grafana_admin
  to   = module.vault.random_password.grafana_admin
}

moved {
  from = kubernetes_secret.infra_grafana
  to   = module.vault.kubernetes_secret.infra_grafana
}
