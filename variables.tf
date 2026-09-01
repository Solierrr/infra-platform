variable "gcp_project_id" {
  type        = string
  description = "Projeto GCP && Firebase"
  default     = "solaria-authenticator"
}

variable "gcp_region" {
  type        = string
  description = "Região do cluster GCP"
  default = "us-central1"
}

variable "gcp_zone" {
  type        = string
  description = "Zona do cluster GCP"
  default     = "us-central1-a"
}