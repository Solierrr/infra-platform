resource "google_compute_network" "vpc" {
  name                    = "solaria-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = "solaria-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.gcp_region
  network       = google_compute_network.vpc.id
}

resource "google_container_cluster" "primary" {
  name     = "solaria-gke"
  location = var.gcp_zone

  network    = google_compute_network.vpc.id
  subnetwork = google_compute_subnetwork.subnet.id

  # GKE requires a node pool at creation time, but we manage nodes via a
  # separate google_container_node_pool resource below - so we create the
  # required default pool with 1 node and remove it immediately.
  remove_default_node_pool = true
  initial_node_count       = 1

  # Lets `terraform destroy` actually delete the cluster; the provider
  # defaults to protecting clusters from deletion otherwise.
  deletion_protection = false
}

resource "google_container_node_pool" "primary_nodes" {
  name     = "solaria-node-pool"
  cluster  = google_container_cluster.primary.name
  location = var.gcp_zone

  node_count = 1

  node_config {
    machine_type = "e2-small"
    disk_size_gb = 30
    disk_type    = "pd-standard"

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }
}
