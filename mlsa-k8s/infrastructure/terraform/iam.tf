# IAM and Workload Identity Configuration

# Service Account for demo-app (L3 - Workload Identity)
resource "google_service_account" "demo_app" {
  account_id   = "demo-app-sa"
  display_name = "Demo App Service Account"
  project      = var.project_id
}

# Binding: Kubernetes SA → Google Service Account
resource "google_service_account_iam_member" "demo_app_workload_identity" {
  service_account_id = google_service_account.demo_app.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[production/demo-app-sa]"
}

# IAM Policy: Allow demo-app to read from Artifact Registry
resource "google_artifact_registry_repository_iam_member" "demo_app" {
  location   = var.region
  repository = "mlsa-k8s"  # Artifact Registry repo name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.demo_app.email}"
}

# Locals for reference
locals {
  workload_identity_namespace = "production"
  workload_identity_ksa       = "demo-app-sa"
  workload_identity_gsa_email = google_service_account.demo_app.email
}
  member  = "serviceAccount:${google_service_account.demo_app.email}"


output "demo_app_service_account_email" {
  value = google_service_account.demo_app.email
}
