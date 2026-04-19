output "gcs_bucket_name" {
  description = "Name des GCS Data Lake Buckets"
  value       = google_storage_bucket.data_lake.name
}

output "gcs_bucket_url" {
  description = "GCS URL (für Kestra flow config)"
  value       = "gs://${google_storage_bucket.data_lake.name}"
}

output "bq_raw_dataset" {
  description = "BigQuery Raw Dataset ID"
  value       = google_bigquery_dataset.smard_raw.dataset_id
}

output "bq_dbt_dataset" {
  description = "BigQuery dbt Dataset ID"
  value       = google_bigquery_dataset.smard_dbt.dataset_id
}

output "service_account_email" {
  description = "Service Account Email (für dbt profiles.yml)"
  value       = var.service_account_email
}
