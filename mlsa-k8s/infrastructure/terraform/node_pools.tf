# ═══════════════════════════════════════════════════════════════════════
# node_pools.tf — 3 Node Pools: system, workload, evaluation
# ═══════════════════════════════════════════════════════════════════════

# ── System Pool: chạy infrastructure tools (Istio, Gatekeeper, Prometheus...) ──
resource "google_container_node_pool" "system" {
  name       = "system-pool"
  cluster    = google_container_cluster.mlsa.name
  location   = var.zone
  node_count = 2

  node_config {
    machine_type = "e2-standard-4"
    image_type   = "COS_CONTAINERD"   # Container-Optimized OS

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    workload_metadata_config {
      mode = "GKE_METADATA"   # Bật Workload Identity trên node
    }

    # QUAN TRỌNG: Cần CẢ labels VÀ taint
    # - label dùng cho nodeSelector (kéo pod vào)
    # - taint dùng để đẩy pod không có toleration ra
    labels = {
      "dedicated"   = "system"
      "cost-center" = "capstone-c2ne03"
    }

    taint {
      key    = "dedicated"
      value  = "system"
      effect = "NO_SCHEDULE"
    }
  }
}

# ── Workload Pool: chạy application pods ──
resource "google_container_node_pool" "workload" {
  name       = "workload-pool"
  cluster    = google_container_cluster.mlsa.name
  location   = var.zone
  node_count = 2

  node_config {
    machine_type = "e2-standard-2"
    image_type   = "COS_CONTAINERD"

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    labels = {
      "workload-type" = "application"
      "cost-center"   = "capstone-c2ne03"
    }
  }
}

# ── Evaluation Pool: autoscale min=0 để tắt khi không dùng ──
resource "google_container_node_pool" "evaluation" {
  name    = "evaluation-pool"
  cluster = google_container_cluster.mlsa.name
  location = var.zone

  autoscaling {
    min_node_count = 0
    max_node_count = 1
  }

  node_config {
    machine_type = "e2-standard-2"
    image_type   = "COS_CONTAINERD"

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    labels = {
      "workload-type" = "evaluation"
      "cost-center"   = "capstone-c2ne03"
    }
  }
}
