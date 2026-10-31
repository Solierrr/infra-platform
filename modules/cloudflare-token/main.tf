# Token operacional da Cloudflare, o que o Terraform e o cert-manager usam no dia
# a dia (guardado pelo Infisical em /cloudflare/CLOUDFLARE_API_TOKEN). Este
# módulo só altera as permissões dele; o valor não muda, então o Infisical não é
# reescrito. Para rotacionar, apague o token no painel e recrie o recurso.
#
# Os IDs são os grupos de permissão da Cloudflare (GET /user/tokens/permission_groups).

locals {
  zone_permission_groups = {
    dns_write            = "4755a26eedb94da69e1066d98aa820be" # DNS Write
    zone_read            = "c8fed203ed3043cba015a93ad1616f1f" # Zone Read
    cache_settings_write = "9ff81cbbe65c400b97d92c3c1033cab6" # Cache Settings Write
    workers_routes_read  = "2072033d694d415a936eaeb94e6405b8" # Workers Routes Read
  }

  account_permission_groups = {
    access_apps_policies_write = "1e13c5124ca64b72b1969a67e8829049" # Access: Apps and Policies Write
    access_apps_policies_read  = "7ea222f6d5064cfa89ea366d7c1fee89" # Access: Apps and Policies Read
    access_idp_read            = "9c35051ed89842839a637f81448d8c7c" # Access: Identity Providers Read
    workers_scripts_read       = "1a71c399035b4950a1bd1466bbe4f420" # Workers Scripts Read
  }

  # Token só de publicação dos Workers (worker-failover, worker-docs e worker-alerts), usado pelos
  # workflows de deploy. Não lê nem escreve DNS fora do necessário para o domínio próprio do Worker.
  deploy_account_permission_groups = {
    workers_scripts_write = "e086da7e2179491d91ee5f35b3ca210a" # Workers Scripts Write
  }
  deploy_zone_permission_groups = {
    workers_routes_write = "28f4b596e7d643029c524985477ae49a" # Workers Routes Write
    dns_write            = "4755a26eedb94da69e1066d98aa820be" # DNS Write
    zone_read            = "c8fed203ed3043cba015a93ad1616f1f" # Zone Read
  }
}

resource "cloudflare_api_token" "operational" {
  name = "terraform-operational"

  policies = [
    {
      effect            = "allow"
      permission_groups = [for id in values(local.zone_permission_groups) : { id = id }]
      resources = jsonencode({
        "com.cloudflare.api.account.zone.${var.zone_id}" = "*"
      })
    },
    {
      effect            = "allow"
      permission_groups = [for id in values(local.account_permission_groups) : { id = id }]
      resources = jsonencode({
        "com.cloudflare.api.account.${var.account_id}" = "*"
      })
    },
  ]
}

resource "cloudflare_api_token" "workers_deploy" {
  name = "workers-deploy"

  policies = [
    {
      effect            = "allow"
      permission_groups = [for id in values(local.deploy_zone_permission_groups) : { id = id }]
      resources = jsonencode({
        "com.cloudflare.api.account.zone.${var.zone_id}" = "*"
      })
    },
    {
      effect            = "allow"
      permission_groups = [for id in values(local.deploy_account_permission_groups) : { id = id }]
      resources = jsonencode({
        "com.cloudflare.api.account.${var.account_id}" = "*"
      })
    },
  ]
}
