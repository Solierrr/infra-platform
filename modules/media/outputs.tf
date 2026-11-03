output "bucket_name" {
  description = "Nome do bucket de mídia, o valor de MEDIA_BUCKET no api-messenger"
  value       = google_storage_bucket.media.name
}

output "service_account_email" {
  description = "Conta de serviço do api-messenger para a mídia"
  value       = google_service_account.messenger_media.email
}
