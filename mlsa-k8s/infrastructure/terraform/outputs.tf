# ═══════════════════════════════════════════════════════════════════════
# outputs.tf
# ═══════════════════════════════════════════════════════════════════════

output "cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.mlsa.name
}

output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = google_container_cluster.mlsa.endpoint
  sensitive   = true
}

output "cluster_location" {
  description = "GKE cluster location (zone)"
  value       = google_container_cluster.mlsa.location
}

output "get_credentials_command" {
  description = "Command to get kubectl credentials"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.mlsa.name} --zone ${var.zone} --project ${var.project_id}"
}

