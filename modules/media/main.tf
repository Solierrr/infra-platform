# Mídia das mensagens do api-messenger. Os bytes não passam pela API: o aparelho envia e retira direto do bucket
# com links assinados, e o arquivo some sozinho pela regra de ciclo de vida.

resource "google_storage_bucket" "media" {
  name     = var.bucket_name
  project  = var.gcp_project_id
  location = var.bucket_location

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true

  lifecycle_rule {
    condition {
      age = var.retention_days
    }
    action {
      type = "Delete"
    }
  }

  # O navegador envia com PUT e lê com GET usando o link assinado.
  cors {
    origin          = var.cors_origins
    method          = ["GET", "HEAD", "PUT"]
    response_header = ["Content-Type", "Content-Length", "x-goog-content-length-range", "x-goog-meta-conversation-id", "x-goog-meta-uploader"]
    max_age_seconds = 3600
  }
}

resource "google_service_account" "messenger_media" {
  account_id   = "api-messenger-media"
  display_name = "api-messenger: mídia das mensagens"
  project      = var.gcp_project_id
}

# Só neste bucket: criar, ler os metadados e apagar objetos. Não vê nenhum outro recurso do projeto.
resource "google_storage_bucket_iam_member" "messenger_media" {
  bucket = google_storage_bucket.media.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.messenger_media.email}"
}

# shortcut: chave de conta de serviço montada no pod, porque o cluster ainda não usa Workload Identity.
# Evoluir para Workload Identity quando o pool de nós for recriado com GKE_METADATA; a chave sai do state e do Secret.
resource "google_service_account_key" "messenger_media" {
  service_account_id = google_service_account.messenger_media.name
}

resource "kubernetes_secret" "messenger_media_key" {
  metadata {
    name      = "api-messenger-media-key"
    namespace = "default"
  }

  data = {
    "key.json" = base64decode(google_service_account_key.messenger_media.private_key)
  }

  depends_on = [var.cluster_ready]
}
