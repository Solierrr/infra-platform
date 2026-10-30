# Argo CD atrás do Cloudflare Access: o host argocd passa pelo proxy da Cloudflare
# e só abre depois do login com código enviado por e-mail (one-time PIN) para um
# dos e-mails de var.argocd_access_emails. O login `admin` do Argo CD continua
# valendo como segunda camada. Sem e-mails na variável, nada abaixo é criado.
#
# Pré-requisitos fora do Terraform: ativar o Zero Trust na conta da Cloudflare
# (plano Free) e dar ao token do Infisical (/cloudflare) a permissão
# "Account > Access: Apps and Policies > Edit".

locals {
  argocd_access_enabled = length(var.argocd_access_emails) > 0
  argocd_host           = "argocd.${var.domain}"
}

# O registro próprio sobrepõe o wildcard (DNS-only) só para este host, como no
# api-recommendation: o Access só protege hosts que passam pelo proxy.
resource "cloudflare_dns_record" "argocd" {
  count   = local.argocd_access_enabled ? 1 : 0
  zone_id = data.cloudflare_zone.primary.zone_id
  name    = local.argocd_host
  type    = "A"
  content = google_compute_address.kong_ip.address
  ttl     = 1
  proxied = true
}

resource "cloudflare_zero_trust_access_policy" "argocd" {
  count      = local.argocd_access_enabled ? 1 : 0
  account_id = data.cloudflare_zone.primary.account.id
  name       = "argocd allowed emails"
  decision   = "allow"
  include = [for email in var.argocd_access_emails : {
    email = { email = email }
  }]
}

resource "cloudflare_zero_trust_access_application" "argocd" {
  count            = local.argocd_access_enabled ? 1 : 0
  account_id       = data.cloudflare_zone.primary.account.id
  name             = "Argo CD"
  domain           = local.argocd_host
  type             = "self_hosted"
  session_duration = "8h"
  policies = [{
    id         = cloudflare_zero_trust_access_policy.argocd[0].id
    precedence = 1
  }]

  depends_on = [cloudflare_dns_record.argocd]
}
