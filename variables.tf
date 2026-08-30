variable "gcp_project_id" {
  type        = string
  description = "GCP project where the cluster will be created"
  default     = "solaria-authenticator"
}

variable "gcp_region" {
  type        = string
  description = "GCP region for regional resources (network, subnetwork)"
  default     = "southamerica-east1"
}

variable "gcp_zone" {
  type        = string
  description = "GCP zone for the (zonal) GKE cluster and its node pool"
  default     = "southamerica-east1-a"
}