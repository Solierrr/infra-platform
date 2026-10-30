# Ferramentas de infra e documentação das APIs atrás do Cloudflare Access, com
# login pelo Google (provedor criado no painel do Zero Trust) e restrito aos
# e-mails de var.access_allowed_emails. Sem e-mails na variável, nada abaixo é
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

  access_destinations = concat(
    [for host in local.access_full_hosts : "${host}.${var.domain}"],
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
  content  = google_compute_address.kong_ip.address
  ttl      = 1
  proxied  = true
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

  depends_on = [cloudflare_dns_record.access_proxied, cloudflare_dns_record.api_recommendation]
}
