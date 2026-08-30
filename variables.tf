variable "gcp_project_id" {
  type        = string
  description = "GCP project"
  default     = "solaria-authenticator"
}

variable "gcp_region" {
  type        = string
  description = "GCP region"
  default     = "southamerica-east1"
}

variable "gcp_zone" {
  type        = string
  description = "GCP zone"
  default     = "southamerica-east1-a"
}