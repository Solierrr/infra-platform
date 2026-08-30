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