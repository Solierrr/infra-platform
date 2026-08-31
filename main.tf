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

  remove_default_node_pool = true
  initial_node_count       = 1

  deletion_protection = false

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  private_cluster_config {
    enable_private_nodes    = false
    enable_private_endpoint = false
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "177.62.27.116/32"
      display_name = "solaria-machine"
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

  set = [
    {
      name  = "configs.params.server\\.insecure"
      value = "true"
    },
    {
      name  = "server.ingress.enabled"
      value = "true"
    },
    {
      name  = "server.ingress.ingressClassName"
      value = "kong"
    },
    {
      name  = "server.ingress.hostname"
      value = "argocd.34.39.151.199.sslip.io"
    },
  ]

  depends_on = [google_container_node_pool.primary_nodes]
}

resource "google_compute_address" "kong_ip" {
  name   = "solaria-kong-ip"
  region = var.gcp_region
}

resource "helm_release" "kong" {
  name             = "kong"
  repository       = "https://charts.konghq.com"
  chart            = "kong"
  version          = "3.4.1" # Kong 3.9.3
  namespace        = "solier-dev"
  create_namespace = true

  values = [
    file("${path.module}/../infra-gateway/helm/values-base.yaml"),
    file("${path.module}/../infra-gateway/helm/values-dev.yaml"),
  ]

  set = [
    {
      name  = "proxy.type"
      value = "LoadBalancer"
    },
    {
      name  = "proxy.loadBalancerIP"
      value = google_compute_address.kong_ip.address
    }
  ]

  depends_on = [google_container_node_pool.primary_nodes]
}
