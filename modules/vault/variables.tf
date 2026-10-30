variable "infisical_project_id" {
  type        = string
  description = "Workspace ID do projeto Infisical"
}

variable "cluster_ready" {
  type        = string
  description = "ID do node pool: os Secrets só são criados depois que o cluster tem nós"
}
