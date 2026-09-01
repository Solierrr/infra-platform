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
