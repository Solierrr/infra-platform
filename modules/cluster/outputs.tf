output "vpc_id" {
  value = google_compute_network.vpc.id
}

output "kong_ip" {
  description = "IP público do Kong, muda a cada recriação do cluster"
  value       = google_compute_address.kong_ip.address
}

output "name" {
  value = google_container_cluster.primary.name
}

output "endpoint" {
  value = google_container_cluster.primary.endpoint
}

output "ca_certificate" {
  value     = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
  sensitive = true
}

output "node_pool_id" {
  description = "Usado pelo módulo vault para só criar os Secrets depois que os nós existem"
  value       = google_container_node_pool.primary_nodes.id
}
