# Secrets lidos do Infisical (env prod), pastas por categoria/tecnologia
# compartilhadas entre serviços - ver
# docs-warehouse/architecture/2026-09-03-secrets-and-envs-design.md

data "infisical_secrets" "database" {
  env_slug     = "prod"
  workspace_id = var.infisical_project_id
  folder_path  = "/database"
}

# --- api-messenger --------------------------------------------------------

resource "kubernetes_secret" "api_messenger" {
  metadata {
    name      = "api-messenger-secrets"
    namespace = "default"
  }

  data = merge(
    {
      for name, secret in data.infisical_secrets.database.secrets :
      name => secret.value
      if contains(["DB_MONGO_URI", "DB_MONGO_MESSENGER"], name)
    },
    {
      for name, secret in data.infisical_secrets.auth.secrets :
      name => secret.value
      if contains(["SERVICE_JWT_SECRET", "SERVICE_CLIENT_SECRET"], name)
    },
  )

  type = "Opaque"

  depends_on = [google_container_node_pool.primary_nodes]
}

# --- api-core ---------------------------------------------------------

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

# --- api-recommendation ----------------------------------------------------
# Reusa /database (Postgres somente-leitura + Neo4j) e soma a pasta
# /recommendation (chaves de API do motor de recomendação, não são
# credencial de nenhuma tecnologia compartilhada).

data "infisical_secrets" "recommendation" {
  env_slug     = "prod"
  workspace_id = var.infisical_project_id
  folder_path  = "/recommendation"
}

resource "kubernetes_secret" "api_recommendation" {
  metadata {
    name      = "api-recommendation-secrets"
    namespace = "default"
  }

  data = merge(
    { for name, secret in data.infisical_secrets.database.secrets : name => secret.value },
    { for name, secret in data.infisical_secrets.recommendation.secrets : name => secret.value },
  )

  type = "Opaque"

  depends_on = [google_container_node_pool.primary_nodes]
}

# --- api-mcp (api-database-mcp) --------------------------------------------
# Reusa /database (Postgres "Negócio") e soma a pasta /mcp (chave de API
# própria do serviço).

data "infisical_secrets" "mcp" {
  env_slug     = "prod"
  workspace_id = var.infisical_project_id
  folder_path  = "/mcp"
}

resource "kubernetes_secret" "api_mcp" {
  metadata {
    name      = "api-mcp-secrets"
    namespace = "default"
  }

  data = merge(
    {
      for name, secret in data.infisical_secrets.database.secrets :
      name => secret.value
      if contains(["DB_POSTGRES_HOST", "DB_POSTGRES_PORT", "DB_POSTGRES_USER", "DB_POSTGRES_PASSWORD", "DB_POSTGRES_BUSINESS"], name)
    },
    { for name, secret in data.infisical_secrets.mcp.secrets : name => secret.value },
  )

  type = "Opaque"

  depends_on = [google_container_node_pool.primary_nodes]
}

# --- ai-assistant -----------------------------------------------------------
# Mongo (checkpointer de curto prazo), Redis próprio dos agentes (Upstash) e
# chaves de LLM.

data "infisical_secrets" "llm" {
  env_slug     = "prod"
  workspace_id = var.infisical_project_id
  folder_path  = "/llm"
}

resource "kubernetes_secret" "ai_assistant" {
  metadata {
    name      = "ai-assistant-secrets"
    namespace = "default"
  }

  data = merge(
    {
      for name, secret in data.infisical_secrets.database.secrets :
      name => secret.value
      if contains(["DB_MONGO_URI", "DB_MONGO_AGENTS"], name)
    },
    {
      for name, secret in data.infisical_secrets.redis.secrets :
      name => secret.value
      if contains(["UPSTASH_AGENTS_HOST", "UPSTASH_AGENTS_PORT", "UPSTASH_AGENTS_USERNAME", "UPSTASH_AGENTS_PASSWORD"], name)
    },
    {
      for name, secret in data.infisical_secrets.llm.secrets :
      name => secret.value
      if contains(["GOOGLE_API_KEY", "GROQ_API_KEY"], name)
    },
  )

  type = "Opaque"

  depends_on = [google_container_node_pool.primary_nodes]
}

# --- ai-validation ----------------------------------------------------------
# Só chaves de LLM, sem banco/cache próprio.

resource "kubernetes_secret" "ai_validation" {
  metadata {
    name      = "ai-validation-secrets"
    namespace = "default"
  }

  data = { for name, secret in data.infisical_secrets.llm.secrets : name => secret.value }

  type = "Opaque"

  depends_on = [google_container_node_pool.primary_nodes]
}

# --- web-app ------------------------------------------------------------
# Propositalmente sem kubernetes_secret: web-app é uma SPA estática (Vite +
# nginx) - as VITE_* são embutidas no bundle em build time (npm run build),
# não lidas em runtime pelo container. A wiring com o Infisical acontece no
# passo de build da imagem Docker (CI), não aqui no Terraform. Ver Fase 4/5
# do plano em docs-warehouse/architecture.
