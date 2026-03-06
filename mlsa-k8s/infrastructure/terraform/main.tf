# ═══════════════════════════════════════════════════════════════════════
# main.tf — GKE Cluster + Backend + Provider
# ═══════════════════════════════════════════════════════════════════════

terraform {
  backend "gcs" {
    bucket = "mlsa-k8s-tfstate"
    prefix = "terraform/state"
  }

  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

resource "google_container_cluster" "mlsa" {
  name     = "mlsa-k8s-cluster"
  location = var.zone   # ZONAL

  # Xóa node pool default (sẽ tạo custom node pools riêng)
  remove_default_node_pool = true
  initial_node_count       = 1

  # Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # NOTE: enable_shielded_nodes KHÔNG cần — deprecated trong provider ~> 5.0
  # GKE mặc định bật shielded nodes. Config ở node_config level.

  # Network Policy — cần cả 2 blocks
  network_policy {
    enabled  = true
    provider = "CALICO"
  }
  addons_config {
    network_policy_config {
      disabled = false   # Bật Calico addon
    }
  }

  # Binary Authorization — policy chi tiết nằm trong binary_auth.tf
  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  # Audit Logging qua Terraform — KHÔNG dùng kubectl apply audit-policy.yaml
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS", "API_SERVER"]
  }

  # Restrict API server access
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = var.admin_cidr
      display_name = "team-access"
    }
  }

  # Private cluster — nodes không có public IP
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false   # Giữ public endpoint cho kubectl từ local
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  # Xóa default labels
  resource_labels = {
    "project"     = "mlsa-k8s"
    "team"        = "c2ne03"
    "cost-center" = "capstone"
  }
}
