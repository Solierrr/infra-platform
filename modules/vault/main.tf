# Secrets lidos do Infisical (env prod), pastas por categoria/tecnologia
# compartilhadas entre serviços - ver
# docs-warehouse/architecture/2026-09-03-secrets-and-envs-design.md

# Credenciais do próprio infra-platform (não de nenhum serviço de app).
# Único valor que ainda precisa ser manual/local é a Machine Identity que
# autentica aqui (infisical_client_id/secret em variables.tf) - o resto
# vem todo do Infisical.
data "infisical_secrets" "cloudflare" {
  env_slug     = "prod"
  workspace_id = var.infisical_project_id
  folder_path  = "/cloudflare"
}

data "infisical_secrets" "terraform" {
  env_slug     = "prod"
  workspace_id = var.infisical_project_id
  folder_path  = "/terraform"
}

data "infisical_secrets" "database" {
  env_slug     = "prod"
  workspace_id = var.infisical_project_id
  folder_path  = "/database"
}

# URLs internas de serviço, consumidas por quem chama outro serviço da
# organização (JWKS, base URLs de auth/persistence/messenger/mcp).
data "infisical_secrets" "service_urls" {
  env_slug     = "prod"
  workspace_id = var.infisical_project_id
  folder_path  = "/service-urls"
}

data "infisical_secrets" "service_keys" {
  env_slug     = "prod"
  workspace_id = var.infisical_project_id
  folder_path  = "/service-keys"
}

# Telemetria: endereço do coletor OpenTelemetry e atributos do ambiente,
# consumidos pelos serviços que exportam métricas, traces e logs.
data "infisical_secrets" "otel" {
  env_slug     = "prod"
  workspace_id = var.infisical_project_id
  folder_path  = "/otel"
}

# Credenciais do FCM (Firebase Cloud Messaging), consumidas pelo api-notify.
data "infisical_secrets" "fcm" {
  env_slug     = "prod"
  workspace_id = var.infisical_project_id
  folder_path  = "/fcm"
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
      SERVICE_KEY = data.infisical_secrets.service_keys.secrets["SERVICE_KEY_API_MESSENGER"].value
    },
    {
      for name, secret in data.infisical_secrets.service_keys.secrets :
      name => secret.value
      if contains(["SERVICE_KEY_AI_ASSISTANT", "SERVICE_KEY_AI_OPERATIONAL", "SERVICE_KEY_AI_GEOGRAPHIC"], name)
    },
    {
      for name, secret in data.infisical_secrets.service_urls.secrets :
      name => secret.value
      if contains(["JWT_JWK_SET_URI", "AUTH_SERVICE_URL", "PERSISTENCE_BASE_URL"], name)
    },
    # Telemetria: sem o endereço do coletor o serviço exporta para localhost:4318 e falha.
    { for name, secret in data.infisical_secrets.otel.secrets : name => secret.value },
    {
      for name, secret in data.infisical_secrets.broker.secrets :
      name => secret.value
      if contains(["RABBITMQ_USER", "RABBITMQ_PASSWORD"], name)
    },
    {
      for name, secret in data.infisical_secrets.auth.secrets :
      name => secret.value
      if contains(["SERVICE_JWT_SECRET", "SERVICE_CLIENT_SECRET"], name)
    },
    # Redis da presença: usa o usuário próprio do messenger quando ele existir
    # no Infisical e, até lá, o da mesma instância Upstash do api-core.
    {
      UPSTASH_MESSENGER_HOST     = try(data.infisical_secrets.redis.secrets["UPSTASH_MESSENGER_HOST"].value, data.infisical_secrets.redis.secrets["UPSTASH_CORE_HOST"].value)
      UPSTASH_MESSENGER_PORT     = try(data.infisical_secrets.redis.secrets["UPSTASH_MESSENGER_PORT"].value, data.infisical_secrets.redis.secrets["UPSTASH_CORE_PORT"].value)
      UPSTASH_MESSENGER_USERNAME = try(data.infisical_secrets.redis.secrets["UPSTASH_MESSENGER_USERNAME"].value, data.infisical_secrets.redis.secrets["UPSTASH_CORE_USERNAME"].value)
      UPSTASH_MESSENGER_PASSWORD = try(data.infisical_secrets.redis.secrets["UPSTASH_MESSENGER_PASSWORD"].value, data.infisical_secrets.redis.secrets["UPSTASH_CORE_PASSWORD"].value)
    },
  )

  type = "Opaque"

  depends_on = [var.cluster_ready]
}

# --- api-notify -----------------------------------------------------------

resource "kubernetes_secret" "api_notify" {
  metadata {
    name      = "api-notify-secrets"
    namespace = "default"
  }

  data = merge(
    {
      for name, secret in data.infisical_secrets.database.secrets :
      name => secret.value
      if contains(["DB_MONGO_URI", "DB_MONGO_NOTIFY"], name)
    },
    {
      for name, secret in data.infisical_secrets.service_keys.secrets :
      name => secret.value
      if contains(["SERVICE_KEY_API_MESSENGER", "SERVICE_KEY_API_CORE"], name)
    },
    {
      for name, secret in data.infisical_secrets.fcm.secrets :
      name => secret.value
      if contains(["FCM_ENABLED", "FCM_CREDENTIALS_BASE64", "FIREBASE_PROJECT_ID"], name)
    },
    { for name, secret in data.infisical_secrets.otel.secrets : name => secret.value },
    {
      for name, secret in data.infisical_secrets.service_urls.secrets :
      name => secret.value
      if contains(["JWT_JWK_SET_URI"], name)
    },
  )

  type = "Opaque"

  depends_on = [var.cluster_ready]
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
    { for name, secret in data.infisical_secrets.otel.secrets : name => secret.value },
    {
      for name, secret in data.infisical_secrets.service_keys.secrets :
      name => secret.value
      if contains(["SERVICE_KEY_API_AUTH", "SERVICE_KEY_API_MESSENGER"], name)
    },
    {
      API_EMAIL_KEY = data.infisical_secrets.service_keys.secrets["SERVICE_KEY_API_EMAIL"].value
    },
    {
      for name, secret in data.infisical_secrets.service_urls.secrets :
      name => secret.value
      if contains(["JWT_JWK_SET_URI", "AUTH_SERVICE_URL"], name)
    },
  )

  type = "Opaque"

  depends_on = [var.cluster_ready]
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
    { for name, secret in data.infisical_secrets.otel.secrets : name => secret.value },
    {
      SERVICE_KEY = data.infisical_secrets.service_keys.secrets["SERVICE_KEY_API_AUTH"].value
      # chave que o api-auth manda ao api-email (o api-email a recebe como EMAIL_API_KEY)
      SERVICE_KEY_API_EMAIL = data.infisical_secrets.service_keys.secrets["SERVICE_KEY_API_EMAIL"].value
    },
    {
      for name, secret in data.infisical_secrets.service_urls.secrets :
      name => secret.value
      # api-email e os links dos e-mails de verificação e recuperação de senha
      if contains(["PERSISTENCE_BASE_URL", "EMAIL_SERVICE_URL", "AUTH_EMAIL_VERIFICATION_URL", "AUTH_EMAIL_RESET_URL"], name)
    },
  )

  type = "Opaque"

  depends_on = [var.cluster_ready]
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

  depends_on = [var.cluster_ready]
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
    {
      for name, secret in data.infisical_secrets.feeddb.secrets :
      name => secret.value
      if contains(["DB_NEO4J_URI", "DB_NEO4J_USER", "DB_NEO4J_PASSWORD", "DB_NEO4J_FEED"], name)
    },
  )

  type = "Opaque"

  depends_on = [var.cluster_ready]
}

# --- mcp-database (ex-api-mcp) ---------------------------------------------
# Reusa /database (Postgres "Negócio") e soma a pasta /mcp (chave de API
# própria do serviço).

data "infisical_secrets" "mcp" {
  env_slug     = "prod"
  workspace_id = var.infisical_project_id
  folder_path  = "/mcp"
}

resource "kubernetes_secret" "api_mcp" {
  metadata {
    name      = "mcp-database-secrets"
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

  depends_on = [var.cluster_ready]
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
    { for name, secret in data.infisical_secrets.otel.secrets : name => secret.value },
    # MONGO_URI (não DB_MONGO_URI) - settings.py aceita MONGO_URI/MONGODB_URI
    # via AliasChoices, nunca o prefixo DB_ usado na pasta compartilhada.
    {
      MONGO_URI = data.infisical_secrets.database.secrets["DB_MONGO_URI"].value
    },
    {
      for name, secret in data.infisical_secrets.database.secrets :
      name => secret.value
      if contains(["QDRANT_URL", "QDRANT_API_KEY"], name)
    },
    # UPSTASH_REDIS_* (não UPSTASH_AGENTS_*) - nome esperado por settings.py.
    {
      UPSTASH_REDIS_HOST     = data.infisical_secrets.redis.secrets["UPSTASH_AGENTS_HOST"].value
      UPSTASH_REDIS_PORT     = data.infisical_secrets.redis.secrets["UPSTASH_AGENTS_PORT"].value
      UPSTASH_REDIS_USERNAME = data.infisical_secrets.redis.secrets["UPSTASH_AGENTS_USERNAME"].value
      UPSTASH_REDIS_PASSWORD = data.infisical_secrets.redis.secrets["UPSTASH_AGENTS_PASSWORD"].value
    },
    {
      for name, secret in data.infisical_secrets.llm.secrets :
      name => secret.value
      if contains(["GEMINI_API_KEY", "GROQ_API_KEY", "OPENAI_API_KEY", "LLM_MODEL_OPENAI", "LLM_PROVIDER_ORDER"], name)
    },
    {
      for name, secret in data.infisical_secrets.mcp.secrets :
      name => secret.value
      if contains(["MCP_API_KEY"], name)
    },
    # JWT_JWKS_URL (não JWT_JWK_SET_URI) - nome esperado por settings.py.
    {
      API_MESSENGER_URL = data.infisical_secrets.service_urls.secrets["API_MESSENGER_URL"].value
      JWT_JWKS_URL      = data.infisical_secrets.service_urls.secrets["JWT_JWK_SET_URI"].value
      MCP_URL           = data.infisical_secrets.service_urls.secrets["MCP_URL"].value
    },
    {
      SERVICE_KEY = data.infisical_secrets.service_keys.secrets["SERVICE_KEY_AI_ASSISTANT"].value
    },
  )

  type = "Opaque"

  depends_on = [var.cluster_ready]
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

  depends_on = [var.cluster_ready]
}

# --- google-registry --------------------------------------------------------
# Chaves do Google (inclusive o OAuth do Calendar) e as URLs de auth para
# validar o JWT. Serviço interno (ClusterIP,
# sem Ingress), como o mcp-database. O serviço lê nomes próprios
# (GOOGLE_KEY_MAPS, GOOGLE_KEY_TRANSLATION, JWT_JWKS_URL, AUTH_BASE_URL), então
# o secret renomeia as chaves do Infisical em vez de duplicá-las.

resource "kubernetes_secret" "google_registry" {
  metadata {
    name      = "google-registry-secrets"
    namespace = "default"
  }

  data = merge(
    { for name, secret in data.infisical_secrets.google.secrets : name => secret.value },
    {
      GOOGLE_KEY_MAPS        = data.infisical_secrets.google.secrets["GOOGLE_MAPS_API_KEY"].value
      GOOGLE_KEY_TRANSLATION = data.infisical_secrets.google.secrets["GOOGLE_TRANSLATE_API_KEY"].value
      JWT_JWKS_URL           = data.infisical_secrets.service_urls.secrets["JWT_JWK_SET_URI"].value
      AUTH_BASE_URL          = data.infisical_secrets.service_urls.secrets["AUTH_SERVICE_URL"].value
    },
  )

  type = "Opaque"

  depends_on = [var.cluster_ready]
}

# --- feeddb e database-bootstrap ---------------------------------------------
# Neo4j self-hosted (grafo descartável) e o job que o reconstrói a partir do
# Postgres. /feeddb guarda só as credenciais do Neo4j; o Postgres vem de
# /database, restrito às chaves que o job lê.

data "infisical_secrets" "feeddb" {
  env_slug     = "prod"
  workspace_id = var.infisical_project_id
  folder_path  = "/feeddb"
}

resource "kubernetes_secret" "feeddb" {
  metadata {
    name      = "feeddb-secrets"
    namespace = "default"
  }

  data = {
    NEO4J_AUTH = "neo4j/${data.infisical_secrets.feeddb.secrets["DB_NEO4J_PASSWORD"].value}"
  }

  type = "Opaque"

  depends_on = [var.cluster_ready]
}

resource "kubernetes_secret" "database_bootstrap" {
  metadata {
    name      = "database-bootstrap-secrets"
    namespace = "default"
  }

  data = merge(
    {
      for name, secret in data.infisical_secrets.database.secrets :
      name => secret.value
      if contains(["DB_POSTGRES_HOST", "DB_POSTGRES_PORT", "DB_POSTGRES_CORE", "DB_POSTGRES_USER", "DB_POSTGRES_PASSWORD", "DB_POSTGRES_SSLMODE"], name)
    },
    {
      for name, secret in data.infisical_secrets.feeddb.secrets :
      name => secret.value
      if contains(["DB_NEO4J_URI", "DB_NEO4J_USER", "DB_NEO4J_PASSWORD", "DB_NEO4J_FEED"], name)
    },
  )

  type = "Opaque"

  depends_on = [var.cluster_ready]
}

# --- ai-accessibility -------------------------------------------------------
# Só chaves de LLM e o token interno que o serviço exige no Bearer
# (INTERNAL_API_TOKEN recebe a service key do ai-accessibility), sem banco.

resource "kubernetes_secret" "ai_accessibility" {
  metadata {
    name      = "ai-accessibility-secrets"
    namespace = "default"
  }

  data = merge(
    { for name, secret in data.infisical_secrets.otel.secrets : name => secret.value },
    {
      for name, secret in data.infisical_secrets.llm.secrets :
      name => secret.value
      if contains(["GEMINI_API_KEY", "GROQ_API_KEY"], name)
    },
    {
      INTERNAL_API_TOKEN = data.infisical_secrets.service_keys.secrets["SERVICE_KEY_AI_ACCESSIBILITY"].value
      JWT_JWKS_URL       = data.infisical_secrets.service_urls.secrets["JWT_JWK_SET_URI"].value
    },
  )

  type = "Opaque"

  depends_on = [var.cluster_ready]
}

# --- ai-geographic ----------------------------------------------------------
# Mesmo desenho do ai-assistant (Mongo, Redis dos agentes, chaves de LLM) mais
# o que é próprio do serviço: Maps (Grounding Lite), google-registry e a
# delegação A2A ao ai-assistant. Renomeia as chaves do Infisical para os nomes
# que o settings.py lê (MONGO_URI, UPSTASH_REDIS_*, JWT_JWKS_URL, SERVICE_KEY).

resource "kubernetes_secret" "ai_geographic" {
  metadata {
    name      = "ai-geographic-secrets"
    namespace = "default"
  }

  data = merge(
    { for name, secret in data.infisical_secrets.otel.secrets : name => secret.value },
    {
      MONGO_URI = data.infisical_secrets.database.secrets["DB_MONGO_URI"].value
    },
    {
      UPSTASH_REDIS_HOST     = data.infisical_secrets.redis.secrets["UPSTASH_AGENTS_HOST"].value
      UPSTASH_REDIS_PORT     = data.infisical_secrets.redis.secrets["UPSTASH_AGENTS_PORT"].value
      UPSTASH_REDIS_USERNAME = data.infisical_secrets.redis.secrets["UPSTASH_AGENTS_USERNAME"].value
      UPSTASH_REDIS_PASSWORD = data.infisical_secrets.redis.secrets["UPSTASH_AGENTS_PASSWORD"].value
    },
    {
      for name, secret in data.infisical_secrets.llm.secrets :
      name => secret.value
      if contains(["GEMINI_API_KEY", "GROQ_API_KEY", "OPENAI_API_KEY", "LLM_MODEL_GEMINI", "LLM_MODEL_OPENAI", "LLM_PROVIDER_ORDER"], name)
    },
    {
      for name, secret in data.infisical_secrets.google.secrets :
      name => secret.value
      if contains(["GOOGLE_MAPS_API_KEY", "MAPS_MCP_URL"], name)
    },
    {
      for name, secret in data.infisical_secrets.service_urls.secrets :
      name => secret.value
      if contains(["API_MESSENGER_URL", "A2A_ASSISTANT_URL", "GOOGLE_REGISTRY_URL", "REGISTRY_CONSUMER_TOKEN"], name)
    },
    {
      JWT_JWKS_URL = data.infisical_secrets.service_urls.secrets["JWT_JWK_SET_URI"].value
      SERVICE_KEY  = data.infisical_secrets.service_keys.secrets["SERVICE_KEY_AI_GEOGRAPHIC"].value
    },
  )

  type = "Opaque"

  depends_on = [var.cluster_ready]
}

# --- ai-operational ---------------------------------------------------------
# Mesmo desenho do ai-assistant, com o MCP do mcp-database (a MCP_URL vem do
# Deployment, porque o valor do Infisical ainda usa o nome antigo api-mcp) e o
# api-core, cuja URL também é fixada no Deployment.

resource "kubernetes_secret" "ai_operational" {
  metadata {
    name      = "ai-operational-secrets"
    namespace = "default"
  }

  data = merge(
    { for name, secret in data.infisical_secrets.otel.secrets : name => secret.value },
    {
      MONGO_URI = data.infisical_secrets.database.secrets["DB_MONGO_URI"].value
    },
    {
      UPSTASH_REDIS_HOST     = data.infisical_secrets.redis.secrets["UPSTASH_AGENTS_HOST"].value
      UPSTASH_REDIS_PORT     = data.infisical_secrets.redis.secrets["UPSTASH_AGENTS_PORT"].value
      UPSTASH_REDIS_USERNAME = data.infisical_secrets.redis.secrets["UPSTASH_AGENTS_USERNAME"].value
      UPSTASH_REDIS_PASSWORD = data.infisical_secrets.redis.secrets["UPSTASH_AGENTS_PASSWORD"].value
    },
    {
      for name, secret in data.infisical_secrets.llm.secrets :
      name => secret.value
      if contains(["GEMINI_API_KEY", "GROQ_API_KEY", "OPENAI_API_KEY", "LLM_MODEL_GEMINI", "LLM_MODEL_OPENAI", "LLM_PROVIDER_ORDER"], name)
    },
    {
      for name, secret in data.infisical_secrets.mcp.secrets :
      name => secret.value
      if contains(["MCP_API_KEY"], name)
    },
    {
      API_MESSENGER_URL = data.infisical_secrets.service_urls.secrets["API_MESSENGER_URL"].value
      JWT_JWKS_URL      = data.infisical_secrets.service_urls.secrets["JWT_JWK_SET_URI"].value
      SERVICE_KEY       = data.infisical_secrets.service_keys.secrets["SERVICE_KEY_AI_OPERATIONAL"].value
    },
  )

  type = "Opaque"

  depends_on = [var.cluster_ready]
}

# --- api-email --------------------------------------------------------------
# Serviço interno (ClusterIP, sem Ingress). A pasta /email guarda o provedor
# (Brevo) e o remetente; a chave interna que os backends enviam em X-API-Key é a
# service key do api-email, que o serviço lê como EMAIL_API_KEY.

data "infisical_secrets" "email" {
  env_slug     = "prod"
  workspace_id = var.infisical_project_id
  folder_path  = "/email"
}

resource "kubernetes_secret" "api_email" {
  metadata {
    name      = "api-email-secrets"
    namespace = "default"
  }

  data = merge(
    {
      for name, secret in data.infisical_secrets.email.secrets :
      name => secret.value
      if contains(["BREVO_API_KEY", "EMAIL_FROM"], name)
    },
    {
      EMAIL_API_KEY = data.infisical_secrets.service_keys.secrets["SERVICE_KEY_API_EMAIL"].value
    },
  )

  type = "Opaque"

  depends_on = [var.cluster_ready]
}

# --- infra-broker -----------------------------------------------------------
# RabbitMQ com STOMP, relay do WebSocket do api-messenger. A pasta /broker tem
# o usuário e a senha, que o api-messenger usa iguais; a imagem lê o usuário
# inicial de RABBITMQ_DEFAULT_USER e RABBITMQ_DEFAULT_PASS.

data "infisical_secrets" "broker" {
  env_slug     = "prod"
  workspace_id = var.infisical_project_id
  folder_path  = "/broker"
}

resource "kubernetes_secret" "infra_broker" {
  metadata {
    name      = "infra-broker-secrets"
    namespace = "default"
  }

  data = {
    RABBITMQ_DEFAULT_USER = data.infisical_secrets.broker.secrets["RABBITMQ_USER"].value
    RABBITMQ_DEFAULT_PASS = data.infisical_secrets.broker.secrets["RABBITMQ_PASSWORD"].value
  }

  type = "Opaque"

  depends_on = [var.cluster_ready]
}

# --- infra-grafana ----------------------------------------------------------
# Imagem oficial do Grafana. A senha do administrador é gerada aqui e fica só
# no state (terraform output -raw grafana_admin_password), porque a pasta do
# Grafana ainda não existe no Infisical; se for criada, troque o
# random_password por um data source dela.

resource "random_password" "grafana_admin" {
  length  = 32
  special = false
}

resource "kubernetes_secret" "infra_grafana" {
  metadata {
    name      = "infra-grafana-secrets"
    namespace = "default"
  }

  # Além do administrador, o Grafana recebe as credenciais de leitura do Grafana
  # Cloud (a pasta /grafana-cloud) para as fontes de dados prometheus, loki e tempo.
  # Só as chaves de leitura entram aqui, e não as de envio do coletor.
  data = merge(
    {
      GF_SECURITY_ADMIN_USER     = "admin"
      GF_SECURITY_ADMIN_PASSWORD = random_password.grafana_admin.result
    },
    {
      for name, secret in data.infisical_secrets.grafana_cloud.secrets :
      name => secret.value
      if contains([
        "GRAFANA_CLOUD_READ_TOKEN",
        "GRAFANA_CLOUD_PROMETHEUS_URL",
        "GRAFANA_CLOUD_PROMETHEUS_USER",
        "GRAFANA_CLOUD_LOKI_URL",
        "GRAFANA_CLOUD_LOKI_USER",
        "GRAFANA_CLOUD_TEMPO_URL",
        "GRAFANA_CLOUD_TEMPO_USER",
      ], name)
    },
  )

  type = "Opaque"

  depends_on = [var.cluster_ready]
}

# --- web-app ------------------------------------------------------------
# Propositalmente sem kubernetes_secret: web-app é uma SPA estática (Vite +
# nginx) - as VITE_* são embutidas no bundle em build time (npm run build),
# não lidas em runtime pelo container. A wiring com o Infisical acontece no
# passo de build da imagem Docker (CI), não aqui no Terraform. Ver Fase 4/5
# do plano em docs-warehouse/architecture.

# Credenciais de partida do Terraform. O token mestre da Cloudflare mora aqui,
# fora da pasta /cloudflare que o próprio Terraform administra.
data "infisical_secrets" "root_credentials" {
  env_slug     = "prod"
  workspace_id = var.infisical_project_id
  folder_path  = "/infisical"
}

# Credenciais do Grafana Cloud para o OpenTelemetry Collector (namespace solierrr,
# o mesmo que os serviços usam em OTEL_EXPORTER_OTLP_ENDPOINT). Ficam numa pasta
# própria, e não em /otel, porque /otel é copiada para o Secret de todos os serviços.
data "infisical_secrets" "grafana_cloud" {
  env_slug     = "prod"
  workspace_id = var.infisical_project_id
  folder_path  = "/grafana-cloud"
}

locals {
  grafana_cloud_ready = alltrue([
    for key in ["GRAFANA_CLOUD_OTLP_ENDPOINT", "GRAFANA_CLOUD_OTLP_AUTH"] :
    contains(keys(data.infisical_secrets.grafana_cloud.secrets), key)
  ])
}

resource "kubernetes_namespace" "solierrr" {
  metadata {
    name = "solierrr"
  }

  depends_on = [var.cluster_ready]
}

# Sem as duas chaves em /grafana-cloud, o Secret não é criado e o coletor fica
# esperando por ele (CreateContainerConfigError) sem derrubar o resto do apply.
resource "kubernetes_secret" "grafana_cloud_otlp" {
  count = local.grafana_cloud_ready ? 1 : 0

  metadata {
    name      = "grafana-cloud-otlp"
    namespace = kubernetes_namespace.solierrr.metadata[0].name
  }

  data = {
    GRAFANA_CLOUD_OTLP_ENDPOINT = data.infisical_secrets.grafana_cloud.secrets["GRAFANA_CLOUD_OTLP_ENDPOINT"].value
    GRAFANA_CLOUD_OTLP_AUTH     = data.infisical_secrets.grafana_cloud.secrets["GRAFANA_CLOUD_OTLP_AUTH"].value
  }

  type = "Opaque"
}

