variable "api_messenger_mongo_uri" {
  type        = string
  description = "Connection string do MongoDB usado pelo api-messenger (spring.mongodb.uri)"
  sensitive   = true
  # TODO: default temporário até o valor real ser definido via TF_VAR. Remover
  # o default assim que o secret real for aplicado, pra não deixar Mongo mal
  # configurado passar despercebido num apply futuro.
  default = ""
}

resource "kubernetes_secret" "api_messenger" {
  metadata {
    name      = "api-messenger-secrets"
    namespace = "default"
  }

  data = {
    MONGO_URI = var.api_messenger_mongo_uri
  }

  type = "Opaque"

  depends_on = [google_container_node_pool.primary_nodes]
}

# --- api-core -----------------------------------------------------------
# Secrets lidos do Infisical (env prod), pastas por categoria/tecnologia
# compartilhadas entre serviços - ver
# docs-warehouse/architecture/2026-09-03-secrets-and-envs-design.md

data "infisical_secrets" "database" {
  env_slug     = "prod"
  workspace_id = var.infisical_project_id
  folder_path  = "/database"
}

data "infisical_secrets" "redis" {
  env_slug     = "prod"
  workspace_id = var.infisical_project_id
  folder_path  = "/redis"
}

data "infisical_secrets" "cloudinary" {
  env_slug     = "prod"
  workspace_id = var.infisical_project_id
  folder_path  = "/cloudinary"
}

data "infisical_secrets" "google" {
  env_slug     = "prod"
  workspace_id = var.infisical_project_id
  folder_path  = "/google"
}

resource "kubernetes_secret" "api_core" {
  metadata {
    name      = "api-core-secrets"
    namespace = "default"
  }

  # Traz junto DB_POSTGRES_AUTH (usado pelo api-auth, não pelo api-core) -
  # inofensivo, /database é compartilhada entre os dois e o Spring só lê
  # as chaves que conhece.
  data = merge(
    { for name, secret in data.infisical_secrets.database.secrets : name => secret.value },
    { for name, secret in data.infisical_secrets.redis.secrets : name => secret.value },
    { for name, secret in data.infisical_secrets.cloudinary.secrets : name => secret.value },
    { for name, secret in data.infisical_secrets.google.secrets : name => secret.value },
  )

  type = "Opaque"

  depends_on = [google_container_node_pool.primary_nodes]
}

# --- api-auth ----------------------------------------------------------
# TODO: os defaults = "" abaixo são temporários, até os valores reais serem
# aplicados via TF_VAR. Remover assim que estiverem definidos de verdade.

variable "api_auth_db_url" {
  type        = string
  description = "JDBC URL do Postgres usado pelo api-auth (spring.datasource.url)"
  sensitive   = true
  default     = ""
}

variable "api_auth_db_username" {
  type        = string
  description = "Usuário do Postgres usado pelo api-auth"
  sensitive   = true
  default     = ""
}

variable "api_auth_db_password" {
  type        = string
  description = "Senha do Postgres usado pelo api-auth"
  sensitive   = true
  default     = ""
}

variable "api_auth_redis_host" {
  type        = string
  description = "Host do Redis usado pela fila de outbox do api-auth"
  sensitive   = true
  default     = ""
}

variable "api_auth_redis_port" {
  type        = string
  description = "Porta do Redis usado pela fila de outbox do api-auth"
  default     = "6379"
}

variable "api_auth_jwt_keystore_password" {
  type        = string
  description = "Senha do keystore PKCS12 com o par de chaves RSA do JWT"
  sensitive   = true
  default     = ""
}

variable "api_auth_jwt_active_kid" {
  type        = string
  description = "Kid/alias da chave atualmente usada para assinar novos tokens JWT"
  default     = ""
}

variable "api_auth_jwt_keystore_base64" {
  type        = string
  description = "Conteúdo do keystore.p12 do JWT, em base64 (o secrets.local.ps1 gera isso a partir de um caminho de arquivo)"
  sensitive   = true
  default     = ""
}

resource "kubernetes_secret" "api_auth" {
  metadata {
    name      = "api-auth-secrets"
    namespace = "default"
  }

  data = {
    DB_URL                = var.api_auth_db_url
    DB_USERNAME           = var.api_auth_db_username
    DB_PASSWORD           = var.api_auth_db_password
    REDIS_HOST            = var.api_auth_redis_host
    REDIS_PORT            = var.api_auth_redis_port
    JWT_KEYSTORE_PASSWORD = var.api_auth_jwt_keystore_password
    JWT_ACTIVE_KID        = var.api_auth_jwt_active_kid
  }

  type = "Opaque"

  depends_on = [google_container_node_pool.primary_nodes]
}

resource "kubernetes_secret" "api_auth_jwt_keystore" {
  metadata {
    name      = "api-auth-jwt-keystore"
    namespace = "default"
  }

  binary_data = {
    "keystore.p12" = var.api_auth_jwt_keystore_base64
  }

  type = "Opaque"

  depends_on = [google_container_node_pool.primary_nodes]
}
