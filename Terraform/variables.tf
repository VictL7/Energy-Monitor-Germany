variable "project_id" {
  description = "GCP Project ID"
  type        = string
  # Wert kommt aus terraform.tfvars — nie hardcoden
}

variable "region" {
  description = "GCP Region für GCS und BigQuery"
  type        = string
  default     = "europe-west3"
}

variable "service_account_id" {
  description = "Account ID des bestehenden Service Accounts (ohne @...)"
  type        = string
  # Beispiel: 'kestra-smard-sa' (nicht die volle Email)
}

variable "credentials_path" {
  description = "Path to GCP service account JSON key"
  type        = string
}

variable "service_account_email" {
  description = "full Service Account email"
  type        = string
}