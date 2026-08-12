# ---------------------------------------------------------------------------
# OCI account/auth (from https://cloud.oracle.com -> Profile -> API keys)
# ---------------------------------------------------------------------------

variable "tenancy_ocid" {
  description = "OCID of your OCI tenancy (root of your account)."
  type        = string
}

variable "user_ocid" {
  description = "OCID of the OCI user Terraform authenticates as."
  type        = string
}

variable "fingerprint" {
  description = "Fingerprint of the API signing key uploaded to your OCI user."
  type        = string
}

variable "private_key_path" {
  description = "Local path to the PEM private key that matches the uploaded API key."
  type        = string
}

variable "region" {
  description = "OCI region, e.g. sa-saopaulo-1."
  type        = string
}

variable "compartment_ocid" {
  description = "OCID of the compartment to create resources in. If you never created a sub-compartment, use the same value as tenancy_ocid."
  type        = string
}

# ---------------------------------------------------------------------------
# Access to the VM
# ---------------------------------------------------------------------------

variable "ssh_public_key_path" {
  description = "Path to your SSH public key (e.g. ~/.ssh/id_ed25519.pub), used for the 'ubuntu' user on the VM."
  type        = string
}

variable "my_ip_override" {
  description = "CIDR allowed to reach SSH (22) and the Kubernetes API (6443). Leave null to auto-detect your current public IP on every apply."
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------
# VM sizing (Always Free tier: up to 4 OCPUs / 24GB RAM total on Ampere A1)
# ---------------------------------------------------------------------------

variable "instance_ocpus" {
  description = "Number of OCPUs for the Ampere A1 instance."
  type        = number
  default     = 2
}

variable "instance_memory_gb" {
  description = "Amount of RAM (GB) for the Ampere A1 instance."
  type        = number
  default     = 12
}

variable "boot_volume_size_gb" {
  description = "Boot volume size in GB (Always Free tier allows up to 200GB total across volumes)."
  type        = number
  default     = 50
}

# ---------------------------------------------------------------------------
# Databases (Postgres/MongoDB run as plain Docker containers on the VM,
# outside the k3s cluster - see docs/superpowers/specs/2026-08-11-k8s-argocd-terraform-design.md)
# ---------------------------------------------------------------------------

variable "postgres_password" {
  description = "Password for the 'postgres' superuser created by the docker-compose stack on the VM."
  type        = string
  sensitive   = true
}

variable "mongo_root_password" {
  description = "Password for the MongoDB root user created by the docker-compose stack on the VM."
  type        = string
  sensitive   = true
}
