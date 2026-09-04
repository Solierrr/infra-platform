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

data "infisical_secrets" "auth" {
  env_slug     = "prod"
  workspace_id = var.infisical_project_id
  folder_path  = "/auth"
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

# --- api-auth -------------------------------------------------------------
# Secrets lidos do Infisical (env prod) - reusa os data sources /database e
# /redis já declarados acima (mesma instância Postgres/Upstash do api-core,
# só muda DB_POSTGRES_AUTH em vez de DB_POSTGRES_CORE) + /auth.

resource "kubernetes_secret" "api_auth" {
  metadata {
    name      = "api-auth-secrets"
    namespace = "default"
  }

  # Traz junto chaves que o api-auth não usa (DB_POSTGRES_CORE,
  # UPSTASH_CORE_USERNAME/PASSWORD, SERVICE_JWT_SECRET, etc.) - inofensivo,
  # as pastas são compartilhadas e o Spring só lê o que conhece.
  data = merge(
    { for name, secret in data.infisical_secrets.database.secrets : name => secret.value },
    { for name, secret in data.infisical_secrets.redis.secrets : name => secret.value },
    { for name, secret in data.infisical_secrets.auth.secrets : name => secret.value },
  )

  type = "Opaque"

  depends_on = [google_container_node_pool.primary_nodes]
}

resource "kubernetes_secret" "api_auth_jwt_keystore" {
  metadata {
    name      = "api-auth-jwt-keystore"
    namespace = "default"
  }

  binary_data = {
    "keystore.p12" = data.infisical_secrets.auth.secrets["JWT_KEYSTORE_BASE64"].value
  }

  type = "Opaque"

  depends_on = [google_container_node_pool.primary_nodes]
}
