# Composição dos módulos. Cada módulo cuida de uma área:
#   modules/cluster     rede, GKE, Kong, Argo CD e cert-manager
#   modules/vault       leitura do Infisical e Secrets do cluster
#   modules/cloudflare  DNS, cache e Cloudflare Access
#   modules/cloudflare-token  token operacional da Cloudflare (permissões)
# Os blocos moved no fim preservam o state de antes da divisão em módulos.

data "cloudflare_ip_ranges" "edge" {}

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
  argocd_oidc_issuer         = ""
  argocd_oidc_client_id      = ""
  argocd_oidc_client_secret  = ""
  argocd_admin_emails        = module.vault.dev_admin_emails
  kong_source_ranges         = data.cloudflare_ip_ranges.edge.ipv4_cidrs
}

module "cloudflare" {
  source                  = "./modules/cloudflare"
  domain                  = var.domain
  kong_ip                 = module.cluster.kong_ip
  access_allowed_emails   = module.vault.dev_emails
  access_idp_ids          = var.access_idp_ids
  access_session_duration = var.access_session_duration
}

module "alerts" {
  source               = "./modules/alerts"
  account_id           = module.cloudflare.account_id
  cloudflare_api_token = module.vault.cloudflare_api_token
  worker_secrets       = module.vault.alerts_worker_secrets

  # Os segredos do Worker são gravados com o token operacional, que ganha Workers Scripts Write no módulo abaixo
  depends_on = [module.cloudflare_token]
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
