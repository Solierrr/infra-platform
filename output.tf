output "vpc_id" {
  value = google_compute_network.vpc.id
}

output "gke_cluster_name" {
  value = google_container_cluster.primary.name
}

output "gke_cluster_endpoint" {
  value = google_container_cluster.primary.endpoint
}

output "kubectl_config_command" {
  description = "Run this to point kubectl at the new cluster"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --zone ${var.gcp_zone} --project ${var.gcp_project_id}"
}

output "argocd_admin_password_command" {
  description = "Run this to read the ArgoCD initial admin password"
  value       = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}

output "argocd_port_forward_command" {
  description = "Run this to reach the ArgoCD UI at https://localhost:8080"
  value       = "kubectl -n argocd port-forward svc/argocd-server 8080:443"
}