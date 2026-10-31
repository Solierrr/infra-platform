output "vpc_id" {
  value = module.cluster.vpc_id
}

output "kong_ip" {
  description = "IP público do Kong - muda a cada recriação do cluster, usado pra atualizar os hosts sslip.io no infra-gitops"
  value       = module.cluster.kong_ip
}

output "gke_cluster_name" {
  value = module.cluster.name
}

output "gke_cluster_endpoint" {
  value = module.cluster.endpoint
}

output "kubectl_config_command" {
  description = "Run this to point kubectl at the new cluster"
  value       = "gcloud container clusters get-credentials ${module.cluster.name} --zone ${var.gcp_zone} --project ${var.gcp_project_id}"
}

output "argocd_admin_password_command" {
  description = "Run this to read the ArgoCD initial admin password"
  value       = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}

output "argocd_port_forward_command" {
  description = "Run this to reach the ArgoCD UI at https://localhost:8080"
  value       = "kubectl -n argocd port-forward svc/argocd-server 8080:443"
}

output "grafana_admin_password" {
  description = "Senha do usuário admin do Grafana (infra-grafana), gerada pelo Terraform"
  value       = module.vault.grafana_admin_password
  sensitive   = true
}

output "nat_ip" {
  description = "IP fixo de saída dos pods do cluster"
  value       = module.cluster.nat_ip
}

output "workers_deploy_token" {
  description = "Token de publicação dos Workers (terraform output -raw workers_deploy_token)"
  value       = module.cloudflare_token.workers_deploy_token
  sensitive   = true
}

output "gateway_access_aud" {
  description = "AUD do aplicativo gateway do Access (ACCESS_AUD do sandbox)"
  value       = module.cloudflare.gateway_access_aud
}
