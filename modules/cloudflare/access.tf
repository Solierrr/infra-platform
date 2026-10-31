# Ferramentas de infra e documentação das APIs atrás do Cloudflare Access, com
# login pelo Google (provedor criado no painel do Zero Trust) e restrito aos
# e-mails do cadastro DEVS (Infisical, pasta /team). Sem e-mails no cadastro, nada abaixo é
# criado.
#
# - Host inteiro: Argo CD e Grafana.
# - Só a documentação: o Swagger (Spring) e o /docs, /redoc e /openapi.json
#   (FastAPI) de cada API. O resto de cada API segue aberto, porque o front
#   chama esses hosts direto do navegador.
#
# Pré-requisitos fora do Terraform: Zero Trust ativo na conta, o provedor Google
# cadastrado e o token do Infisical (/cloudflare) com a permissão "Account >
# Access: Apps and Policies > Edit". Para adotar o que já existe no painel,
# importe a política e o app antes do primeiro apply (comandos em docs/).

locals {
  access_enabled = length(var.access_allowed_emails) > 0

  access_full_hosts = ["argocd", "grafana"]

  access_docs_paths = {
    auth           = ["/swagger-ui*", "/v3/api-docs*"]
    core           = ["/swagger-ui*", "/v3/api-docs*"]
    messenger      = ["/swagger-ui*", "/v3/api-docs*"]
    notify         = ["/docs*", "/openapi.json*"]
    recommendation = ["/docs*", "/redoc*", "/openapi.json*"]
    accessibility  = ["/docs*", "/redoc*", "/openapi.json*"]
    assistant      = ["/docs*", "/redoc*", "/openapi.json*"]
    geographic     = ["/docs*", "/redoc*", "/openapi.json*"]
    operational    = ["/docs*", "/redoc*", "/openapi.json*"]
    validation     = ["/docs*", "/redoc*", "/openapi.json*"]
  }

  # Hosts inteiros que não são do Kong: o portal do sandbox, hospedado no Render (QA) com o domínio
  # personalizado qa. O servidor do sandbox confere o JWT do Access (ver README dele).
  access_external_hosts = ["qa"]

  access_destinations = concat(
    [for host in concat(local.access_full_hosts, local.access_external_hosts) : "${host}.${var.domain}"],
    flatten([
      for host, paths in local.access_docs_paths : [
        for path in paths : "${host}.${var.domain}${path}"
      ]
    ])
  )

  # O Access só protege hosts que passam pelo proxy da Cloudflare. O wildcard é
  # DNS-only, então cada host protegido ganha um registro próprio. O
  # recommendation já tem o seu em main.tf.
  access_proxied_hosts = toset(concat(
    local.access_full_hosts,
    [for host in keys(local.access_docs_paths) : host if host != "recommendation"]
  ))
}

resource "cloudflare_dns_record" "access_proxied" {
  for_each = local.access_enabled ? local.access_proxied_hosts : toset([])
  zone_id  = data.cloudflare_zone.primary.zone_id
  name     = "${each.value}.${var.domain}"
  type     = "A"
  content  = var.kong_ip
  ttl      = 1
  proxied  = true
}

resource "cloudflare_dns_record" "qa" {
  count   = local.access_enabled ? 1 : 0
  zone_id = data.cloudflare_zone.primary.zone_id
  name    = "qa.${var.domain}"
  type    = "CNAME"
  content = var.sandbox_origin
  ttl     = 1
  proxied = true
}

resource "cloudflare_zero_trust_access_policy" "gateway" {
  count      = local.access_enabled ? 1 : 0
  account_id = data.cloudflare_zone.primary.account.id
  name       = "gateway allowed emails"
  decision   = "allow"
  include = [for email in var.access_allowed_emails : {
    email = { email = email }
  }]
}

resource "cloudflare_zero_trust_access_application" "gateway" {
  count                     = local.access_enabled ? 1 : 0
  account_id                = data.cloudflare_zone.primary.account.id
  name                      = "gateway"
  type                      = "self_hosted"
  domain                    = "argocd.${var.domain}"
  allowed_idps              = var.access_idp_ids
  auto_redirect_to_identity = true
  app_launcher_visible      = true
  session_duration          = var.access_session_duration
  destinations = [for uri in local.access_destinations : {
    type = "public"
    uri  = uri
  }]
  policies = [{
    id         = cloudflare_zero_trust_access_policy.gateway[0].id
    precedence = 1
  }]

  depends_on = [cloudflare_dns_record.access_proxied, cloudflare_dns_record.api_recommendation, cloudflare_dns_record.qa]
}

# Login único no Argo CD: este app SaaS faz o Cloudflare Access agir como
# provedor OIDC do Argo CD. Quem já passou pelo Access (Google) entra no Argo CD
# sem digitar usuário e senha.
resource "cloudflare_zero_trust_access_application" "argocd_sso" {
  count        = local.access_enabled ? 1 : 0
  account_id   = data.cloudflare_zone.primary.account.id
  name         = "argocd-sso"
  type         = "saas"
  allowed_idps = var.access_idp_ids

  saas_app = {
    auth_type     = "oidc"
    redirect_uris = ["https://argocd.${var.domain}/auth/callback"]
    grant_types   = ["authorization_code"]
    scopes        = ["openid", "email", "profile"]
  }

  policies = [{
    id         = cloudflare_zero_trust_access_policy.gateway[0].id
    precedence = 1
  }]
}
