output "zone_id" {
  value = data.cloudflare_zone.primary.zone_id
}

output "account_id" {
  value = data.cloudflare_zone.primary.account.id
}
