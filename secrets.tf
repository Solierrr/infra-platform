variable "api_messenger_mongo_uri" {
  type        = string
  description = "Connection string do MongoDB usado pelo api-messenger (spring.mongodb.uri)"
  sensitive   = true
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
