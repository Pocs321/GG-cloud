# ═══════════════════════════════════════════════════════════════════════
# binary_auth.tf — Binary Authorization Policy
# Whitelist tất cả system image registries, deny mọi thứ khác
# ═══════════════════════════════════════════════════════════════════════

resource "google_binary_authorization_policy" "policy" {
  project = var.project_id

  # ── System image registries được phép ──
  # GKE system images
  admission_whitelist_patterns {
    name_pattern = "gcr.io/google-containers/*"
  }
  admission_whitelist_patterns {
    name_pattern = "gke.gcr.io/*"
  }
  admission_whitelist_patterns {
    name_pattern = "registry.k8s.io/*"
  }
  admission_whitelist_patterns {
    name_pattern = "k8s.gcr.io/*"
  }

  # Istio
  admission_whitelist_patterns {
    name_pattern = "docker.io/istio/*"
  }
  admission_whitelist_patterns {
    name_pattern = "gcr.io/istio-release/*"
  }

  # Security tools
  admission_whitelist_patterns {
    name_pattern = "ghcr.io/*"
  }
  admission_whitelist_patterns {
    name_pattern = "docker.io/falcosecurity/*"
  }
  admission_whitelist_patterns {
    name_pattern = "docker.io/aquasec/*"
  }

  # Monitoring tools
  admission_whitelist_patterns {
    name_pattern = "quay.io/*"
  }
  admission_whitelist_patterns {
    name_pattern = "docker.io/grafana/*"
  }
  admission_whitelist_patterns {
    name_pattern = "docker.io/prom/*"
  }

  # Base images
  admission_whitelist_patterns {
    name_pattern = "docker.io/library/*"
  }

  # Project's own Artifact Registry
  admission_whitelist_patterns {
    name_pattern = "${var.region}-docker.pkg.dev/${var.project_id}/*"
  }

  # ── Default rule: deny everything else ──
  default_admission_rule {
    evaluation_mode  = "ALWAYS_DENY"
    enforcement_mode = "ENFORCED_BLOCK_AND_AUDIT_LOG"
  }

  global_policy_evaluation_mode = "ENABLE"
}
