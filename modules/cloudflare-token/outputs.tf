output "workers_deploy_token" {
  description = "Token de publicação dos Workers; vai para os secrets CLOUDFLARE_API_TOKEN dos repositórios worker-*"
  value       = cloudflare_api_token.workers_deploy.value
  sensitive   = true
}
