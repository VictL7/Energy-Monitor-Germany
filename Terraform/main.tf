terraform {
  required_version = ">= 1.6"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  credentials = file(var.credentials_path)
  project = var.project_id
  region  = var.region
}

# ── GCS Bucket (Data Lake) ─────────────────────────────────────────────────────
resource "google_storage_bucket" "data_lake" {
  name          = "${var.project_id}-smard-lake"
  location      = var.region
  force_destroy = false                # Schutz: verhindert versehentliches Löschen

  uniform_bucket_level_access = true

  versioning {
    enabled = true                     # Parquet-Dateien versioniert → sicherer Upsert
  }

  lifecycle_rule {
    condition {
      age = 90                         # rolling/ Partitionen älter als 90 Tage → Nearline
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  labels = {
    project     = "energiewende-monitor"
    environment = "production"
    managed_by  = "terraform"
  }
}

# ── GCS Ordnerstruktur (Platzhalter-Objekte) ───────────────────────────────────
resource "google_storage_bucket_object" "raw_prefix" {
  name    = "raw/smard/.keep"
  bucket  = google_storage_bucket.data_lake.name
  content = "managed by terraform"
}

resource "google_storage_bucket_object" "rolling_prefix" {
  name    = "raw/smard/rolling/.keep"
  bucket  = google_storage_bucket.data_lake.name
  content = "managed by terraform"
}

# ── BigQuery Dataset (Raw) ─────────────────────────────────────────────────────
resource "google_bigquery_dataset" "smard_raw" {
  dataset_id                 = "smard_raw"
  friendly_name              = "SMARD Raw Data"
  description                = "Rohdaten: Stromerzeugung, Verbrauch, Preise (SMARD API)"
  location                   = var.region
  delete_contents_on_destroy = false   # Schutz: Tabellen bleiben beim terraform destroy

  labels = {
    project    = "energiewende-monitor"
    managed_by = "terraform"
  }
}

# ── BigQuery Dataset (dbt transformiert) ──────────────────────────────────────
resource "google_bigquery_dataset" "smard_dbt" {
  dataset_id                 = "smard_dbt"
  friendly_name              = "SMARD dbt Transformed"
  description                = "dbt Modelle: staging, marts, reports"
  location                   = var.region
  delete_contents_on_destroy = false

  labels = {
    project    = "energiewende-monitor"
    managed_by = "terraform"
  }
}

# ── BigQuery Tabellen mit Partition + Clustering ───────────────────────────────
# Warum PARTITION BY DATE(timestamp_utc)?
#   → Queries filtern fast immer nach Zeitraum (letzte 30 Tage, Jahr 2022 etc.)
#   → Partition reduziert den Bytes-Scan um ~95% gegenüber Full Table Scan
#
# Warum CLUSTER BY energy_type, category?
#   → Zweithäufigster Filter: "nur Solar", "nur erneuerbar"
#   → Clustering reduziert Scan zusätzlich um ~60% bei typischen Dashboard-Queries

resource "google_bigquery_table" "electricity_generation" {
  dataset_id          = google_bigquery_dataset.smard_raw.dataset_id
  table_id            = "electricity_generation"
  deletion_protection = false

  time_partitioning {
    type  = "DAY"
    field = "timestamp_utc"
  }

  clustering = ["energy_type", "category"]

  schema = jsonencode([
    { name = "timestamp_utc", type = "TIMESTAMP", mode = "REQUIRED",
      description = "UTC-Zeitstempel (aus CET/CEST konvertiert)" },
    { name = "energy_type",   type = "STRING",    mode = "REQUIRED",
      description = "Energieträger: solar, wind_onshore, lignite ..." },
    { name = "value_mwh",     type = "FLOAT64",   mode = "NULLABLE",
      description = "Erzeugung in MWh (15-Min-Intervall). Pumpspeicher kann negativ sein." },
    { name = "category",      type = "STRING",    mode = "NULLABLE",
      description = "renewable | fossil | other" },
    { name = "date",          type = "STRING",    mode = "NULLABLE",
      description = "Lokales Datum Europe/Berlin (für einfache Filter)" },
  ])

  labels = {
    managed_by = "terraform"
  }
}

resource "google_bigquery_table" "grid_consumption" {
  dataset_id          = google_bigquery_dataset.smard_raw.dataset_id
  table_id            = "grid_consumption"
  deletion_protection = false

  time_partitioning {
    type  = "DAY"
    field = "timestamp_utc"
  }

  clustering = ["timestamp_utc"]

  schema = jsonencode([
    { name = "timestamp_utc",  type = "TIMESTAMP", mode = "REQUIRED" },
    { name = "grid_load",      type = "FLOAT64",   mode = "NULLABLE",
      description = "Netzlast in MWh" },
    { name = "residual_load",  type = "FLOAT64",   mode = "NULLABLE",
      description = "Residuallast = Netzlast - Wind - Solar (SMARD-Berechnung)" },
    { name = "date",           type = "STRING",    mode = "NULLABLE" },
  ])

  labels = { managed_by = "terraform" }
}

resource "google_bigquery_table" "electricity_prices" {
  dataset_id          = google_bigquery_dataset.smard_raw.dataset_id
  table_id            = "electricity_prices"
  deletion_protection = false

  time_partitioning {
    type  = "DAY"
    field = "timestamp_utc"
  }

  clustering = ["price_type"]

  schema = jsonencode([
    { name = "timestamp_utc",    type = "TIMESTAMP", mode = "REQUIRED" },
    { name = "price_eur_mwh",    type = "FLOAT64",   mode = "NULLABLE",
      description = "Day-ahead oder Spot-Preis in EUR/MWh" },
    { name = "price_type",       type = "STRING",    mode = "NULLABLE",
      description = "actual | day_ahead" },
    { name = "date",             type = "STRING",    mode = "NULLABLE" },
  ])

  labels = { managed_by = "terraform" }
}

# ── Service Account IAM Rollen ────────────────────────────────────────────────
# Diese Rollen müssen MANUELL in GCP Console zugewiesen werden
# da der Service Account selbst keine IAM-Berechtigungen hat
#
# Für energiewende-pipeline-sa@zeta-medley-473321-r6.iam.gserviceaccount.com:
# - roles/bigquery.dataEditor
# - roles/bigquery.jobUser
# - roles/storage.objectAdmin (für den data_lake bucket)

# resource "google_project_iam_member" "sa_bigquery_editor" {
#   project = var.project_id
#   role    = "roles/bigquery.dataEditor"
#   member  = "serviceAccount:${var.service_account_email}"
# }

# resource "google_project_iam_member" "sa_bigquery_job" {
#   project = var.project_id
#   role    = "roles/bigquery.jobUser"
#   member  = "serviceAccount:${var.service_account_email}"
# }

resource "google_storage_bucket_iam_member" "sa_gcs_admin" {
  bucket = google_storage_bucket.data_lake.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${var.service_account_email}"
}