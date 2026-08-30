variable "gcp_project_id" {
  type        = string
  description = "GCP project"
  default     = "solaria-authenticator"
}

variable "gcp_region" {
  type        = string
  description = "GCP region"
  # us-central1/us-east1/us-west1 are priced identically (GCP's "Americas"
  # SKU tier) and ~37% cheaper than southamerica-east1 for e2-medium -
  # verified against the real Cloud Billing Catalog API, not just general
  # claims about US pricing being cheaper.
  default = "us-central1"
}

variable "gcp_zone" {
  type        = string
  description = "GCP zone"
  default     = "us-central1-a"
}