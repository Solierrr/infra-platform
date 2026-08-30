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

  # Explicit about what gets shipped to Cloud Logging - the provider default
  # only covers SYSTEM_COMPONENTS, silently leaving out application logs.
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  # Nodes/endpoint stay public (no Cloud NAT cost), but explicit rather than
  # relying on the provider's implicit default.
  private_cluster_config {
    enable_private_nodes    = false
    enable_private_endpoint = false
  }

  # Public endpoint, but only reachable from this IP - avoids the cost of a
  # fully private cluster while still closing the "anyone can reach it" gap.
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "177.62.27.116/32"
      display_name = "study-machine"
    }
  }
}

resource "google_container_node_pool" "primary_nodes" {
  name     = "solaria-node-pool"
  cluster  = google_container_cluster.primary.name
  location = var.gcp_zone

  node_count = 2

  node_config {
    machine_type = "e2-medium"
    disk_size_gb = 30
    disk_type    = "pd-standard"

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "10.4.2" # ArgoCD v3.5.2
  namespace        = "argocd"
  create_namespace = true

  depends_on = [google_container_node_pool.primary_nodes]
}

resource "helm_release" "kong" {
  name             = "kong"
  repository       = "https://charts.konghq.com"
  chart            = "kong"
  version          = "3.4.1" # Kong 3.9.3 (pinned via values-base.yaml image.tag)
  namespace        = "solier-dev"
  create_namespace = true

  # Values live in the infra-gateway repo (deploy-time config for that
  # service, same reasoning as everything else under services/ in
  # infra-gitops) - assumes it's checked out as a sibling directory, which
  # is a local-machine convenience, not something CI could rely on.
  values = [
    file("${path.module}/../infra-gateway/helm/values-base.yaml"),
    file("${path.module}/../infra-gateway/helm/values-dev.yaml"),
  ]

  # Override just for this study cluster, so the proxy gets a public IP
  # instead of needing kubectl port-forward. Kept out of values-dev.yaml on
  # purpose - that file documents ClusterIP as the intended default for a
  # real dev environment.
  set = [
    {
      name  = "proxy.type"
      value = "LoadBalancer"
    }
  ]

  depends_on = [google_container_node_pool.primary_nodes]
}
