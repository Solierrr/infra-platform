data "cloudflare_zone" "primary" {
  filter = {
    name = var.domain
  }
}

resource "cloudflare_dns_record" "wildcard" {
  zone_id = data.cloudflare_zone.primary.zone_id
  name    = "*.${var.domain}"
  type    = "A"
  content = var.kong_ip
  ttl     = 300
  proxied = false
}

# O domínio raiz (apex) é servido pelo Worker `worker-failover` por uma route (`solarianetwork.site/*`),
# não por um domínio personalizado do Worker. A route só recebe tráfego se o registro do apex existir e
# passar pelo proxy da Cloudflare; o conteúdo `100::` é o endereço de descarte que a Cloudflare indica
# para hosts atendidos só por Worker (o mesmo de docs e alerts). Sem este registro o site não resolve.
# Os subdomínios (argocd, api-auth etc.) são cobertos pelo wildcard acima.
resource "cloudflare_dns_record" "apex" {
  zone_id = data.cloudflare_zone.primary.zone_id
  name    = var.domain
  type    = "AAAA"
  content = "100::"
  ttl     = 1
  proxied = true
  comment = "Apex servido pelo worker-failover (route); proxied para a route receber o tráfego"
}

resource "cloudflare_dns_record" "api_recommendation" {
  zone_id = data.cloudflare_zone.primary.zone_id
  name    = "recommendation.${var.domain}"
  type    = "A"
  content = var.kong_ip
  ttl     = 1
  proxied = true
}

resource "cloudflare_ruleset" "api_recommendation_cache" {
  zone_id     = data.cloudflare_zone.primary.zone_id
  name        = "api-recommendation public feeds cache"
  description = "Cache dos feeds públicos do api-recommendation, respeitando o Cache-Control da origem"
  kind        = "zone"
  phase       = "http_request_cache_settings"

  rules = [{
    action      = "set_cache_settings"
    description = "Cacheia /public/feeds/* do api-recommendation"
    enabled     = true
    expression  = "(http.host eq \"recommendation.${var.domain}\" and starts_with(http.request.uri.path, \"/public/feeds/\"))"
    action_parameters = {
      cache       = true
      edge_ttl    = { mode = "respect_origin" }
      browser_ttl = { mode = "respect_origin" }
      serve_stale = { disable_stale_while_updating = false }
    }
  }]
}

# Faixas de IP da borda da Cloudflare, lidas da API oficial a cada plan. O Kong só
# aceita conexões delas (loadBalancerSourceRanges), então o Cloudflare Access passa
# a ser a única porta de entrada.
data "cloudflare_ip_ranges" "edge" {}

