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
      cidr_block   = var.authorized_ip_cidr
      display_name = "solaria-machine"
    }
  }
}

resource "google_container_node_pool" "primary_nodes" {
  name     = "solaria-node-pool"
  cluster  = google_container_cluster.primary.name
  location = var.gcp_zone

  node_count = 4

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
      value = "argocd.${google_compute_address.kong_ip.address}.sslip.io"
    },
    {
      name  = "configs.secret.argocdServerAdminPassword"
      value = var.argocd_admin_password_hash
    },
    {
      name  = "configs.secret.argocdServerAdminPasswordMtime"
      value = "2026-09-01T00:00:00Z"
      # data fixa: só precisa mudar aqui se a senha for trocada de novo
    },
  ]

  depends_on = [google_container_node_pool.primary_nodes]
}

resource "google_compute_address" "kong_ip" {
  name   = "solaria-kong-ip"
  region = var.gcp_region
}

data "http" "kong_values_base" {
  url = "https://raw.githubusercontent.com/Solierrr/infra-gateway/main/helm/values-base.yaml"
}

data "http" "kong_values_dev" {
  url = "https://raw.githubusercontent.com/Solierrr/infra-gateway/main/helm/values-dev.yaml"
}

resource "helm_release" "kong" {
  name             = "kong"
  repository       = "https://charts.konghq.com"
  chart            = "kong"
  version          = "3.4.1" # Kong 3.9.3
  namespace        = "solier-dev"
  create_namespace = true

  values = [
    data.http.kong_values_base.response_body,
    data.http.kong_values_dev.response_body,
  ]

  set = [
    {
      name  = "proxy.type"
      value = "LoadBalancer"
    },
    {
      name  = "proxy.loadBalancerIP"
      value = google_compute_address.kong_ip.address
    },
    {
      name  = "proxy.tls.enabled"
      value = "true"
    },
  ]

  depends_on = [google_container_node_pool.primary_nodes]
}

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.16.2"
  namespace        = "cert-manager"
  create_namespace = true

  set = [
    {
      name  = "crds.enabled"
      value = "true"
    },
  ]

  depends_on = [google_container_node_pool.primary_nodes]
}

resource "kubernetes_secret" "cloudflare_api_token" {
  metadata {
    name      = "cloudflare-api-token"
    namespace = "cert-manager"
  }

  data = {
    api-token = var.cloudflare_api_token
  }

  type = "Opaque"

  depends_on = [helm_release.cert_manager]
}

resource "kubectl_manifest" "letsencrypt_prod_issuer" {
  yaml_body = <<-YAML
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: letsencrypt-prod
    spec:
      acme:
        server: https://acme-v02.api.letsencrypt.org/directory
        email: ${var.acme_email}
        privateKeySecretRef:
          name: letsencrypt-prod-account-key
        solvers:
          - dns01:
              cloudflare:
                apiTokenSecretRef:
                  name: cloudflare-api-token
                  key: api-token
  YAML

  depends_on = [helm_release.cert_manager, kubernetes_secret.cloudflare_api_token]
}

resource "kubectl_manifest" "letsencrypt_http01_issuer" {
  # Provisório: usado enquanto o domínio é um subdomínio gratuito (is-a.dev) sem
  # zona própria no Cloudflare. Quando trocar por domínio comprado, volta a usar
  # o letsencrypt_prod_issuer (DNS-01) e apaga este.
  yaml_body = <<-YAML
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: letsencrypt-prod-http01
    spec:
      acme:
        server: https://acme-v02.api.letsencrypt.org/directory
        email: ${var.acme_email}
        privateKeySecretRef:
          name: letsencrypt-prod-http01-account-key
        solvers:
          - http01:
              ingress:
                ingressClassName: kong
  YAML

  depends_on = [helm_release.cert_manager]
}
