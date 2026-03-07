# ═══════════════════════════════════════════════════════════════════════
# variables.tf — Terraform Variables for MLSA-K8S Project
# Copy from terraform.tfvars.example and fill with actual values
# KHÔNG commit file terraform.tfvars lên git
# ═══════════════════════════════════════════════════════════════════════

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "admin_cidr" {
  description = "CIDR block cho phép truy cập GKE API server (IP máy tính team)"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "asia-southeast1"
}

variable "zone" {
  description = "GCP zone (ZONAL cluster — bắt buộc để tiết kiệm chi phí)"
  type        = string
  default     = "asia-southeast1-b"
}
