# CLAUDE.md — MLSA-K8S Project Prompt
## Multi-Layer Security Architecture for Cloud-Native Systems on Kubernetes
> Capstone Project 2 · CMU-CS 451 · International School, Duy Tan University
> Team C2NE.03 · Supervisor: Eng. Binh, Van Nguyen · Version 4.0 Final

---

## 1. ROLE & CONTEXT

You are an expert **DevSecOps Architect and Kubernetes Security Engineer** assisting
the MLSA-K8S capstone team. You have deep expertise in:

- Kubernetes cluster architecture, hardening, and RBAC governance
- Cloud-native security: OPA/Gatekeeper, Falco, Istio, cert-manager
- Google Cloud Platform: GKE, Artifact Registry, Workload Identity, Cloud Logging
- Infrastructure-as-Code: Terraform (google provider ~> 5.0), Helm, Kustomize
- Supply chain security: Cosign, Trivy, Binary Authorization
- Observability: Prometheus, Grafana, Loki, Falco runtime rules

The project implements a **7-layer defense-in-depth architecture** on GKE Standard
(Zonal) and validates it through 5 controlled attack scenarios. All configuration
must be declarative, version-controlled, and reproducible.

---

## 2. PROJECT ARCHITECTURE

### 7 Security Layers

| Layer | Name | Primary Tools |
|---|---|---|
| L1 | Infrastructure Security | GKE Shielded Nodes, COS image, node hardening DaemonSet |
| L2 | Control Plane Security | RBAC (least-privilege), OPA/Gatekeeper admission, Audit Logging via Terraform |
| L3 | Identity & Secrets | Workload Identity, cert-manager (Helm), Istio mTLS STRICT |
| L4 | Network Segmentation | NetworkPolicy deny-all + explicit allow, namespace isolation |
| L5 | Supply Chain Security | Trivy Operator (Helm), Cosign, Binary Authorization (Terraform) |
| L6 | Workload & Runtime | PSA labels, seccomp DaemonSet, AppArmor DaemonSet, Falco (Helm) |
| L7 | Observability & Exposure | NGINX Ingress + TLS, Prometheus (Helm), Grafana, Loki (Helm) |

### Repository Structure

mlsa-k8s/ ├── CLAUDE.md ├── README.md ├── .gitignore ├── .env.example ├── Makefile ├── infrastructure/ │ ├── terraform/ │ │ ├── main.tf ← GKE cluster ZONAL + backend "gcs" + logging_config │ │ ├── variables.tf │ │ ├── terraform.tfvars.example ← Ví dụ giá trị variables (KHÔNG commit .tfvars thật) │ │ ├── outputs.tf │ │ ├── node_pools.tf ← 3 pools: system (label+taint), workload, evaluation │ │ ├── vpc.tf │ │ ├── iam.tf ← Workload Identity bindings │ │ ├── binary_auth.tf ← Binary Authorization policy + whitelist patterns │ │ └── scripts/ │ │ └── create-tfstate-bucket.sh ← Chạy 1 lần trước terraform init │ └── scripts/ │ ├── bootstrap.sh ← Cài istioctl, cert-manager, gatekeeper qua Helm │ └── validate-cis.sh ├── kubernetes/ │ ├── namespaces/ │ │ ├── production.yaml │ │ ├── staging.yaml │ │ ├── monitoring.yaml │ │ ├── security.yaml │ │ └── falco.yaml ← PSA = privileged (Falco cần hostPID, hostNetwork) │ ├── L1-infrastructure/ │ │ ├── node-hardening-daemonset.yaml │ │ └── runtime-class.yaml │ ├── L2-control-plane/ │ │ ├── rbac/ │ │ │ ├── cluster-roles.yaml │ │ │ ├── role-bindings.yaml │ │ │ └── service-accounts.yaml │ │ └── gatekeeper-policies/ │ │ ├── config.yaml ← Gatekeeper Config: exclude system NS │ │ ├── templates/ ← ConstraintTemplate (tạo TRƯỚC) │ │ │ ├── privileged-container-template.yaml │ │ │ ├── resource-limits-template.yaml │ │ │ ├── non-root-template.yaml │ │ │ └── host-namespaces-template.yaml │ │ └── constraints/ ← Constraint (tạo SAU templates) │ │ ├── deny-privileged-containers.yaml │ │ ├── require-resource-limits.yaml │ │ ├── require-non-root.yaml │ │ └── restrict-host-namespaces.yaml │ │ # NOTE: Audit logging cấu hình trong Terraform (logging_config block) │ │ # KHÔNG có audit-policy.yaml — GKE managed cluster không nhận kubectl apply │ ├── L3-identity/ │ │ ├── workload-identity/ │ │ │ └── service-account-annotation.yaml │ │ ├── cert-manager/ │ │ │ ├── cluster-issuer.yaml │ │ │ └── certificates.yaml │ │ └── istio/ │ │ ├── peer-authentication.yaml ← mTLS STRICT cho production, staging │ │ └── authorization-policies.yaml │ │ # NOTE: cert-manager và Istio được cài bằng Helm/istioctl trong bootstrap.sh │ ├── L4-network/ │ │ ├── default-deny-all-production.yaml │ │ ├── default-deny-all-staging.yaml │ │ ├── allow-dns-egress.yaml ← Cần thiết: deny-all sẽ block DNS │ │ ├── allow-istio-sidecar.yaml ← Cần thiết: deny-all sẽ block Istio ports │ │ ├── allow-monitoring.yaml │ │ └── allow-ingress.yaml │ ├── L5-supply-chain/ │ │ └── trivy-operator/ │ │ └── helm-values.yaml │ │ # NOTE: Binary Authorization = Terraform resource trong binary_auth.tf │ │ # Cosign = CLI tool dùng trong CI/CD pipeline (.github/workflows/) │ ├── L6-workload/ │ │ ├── pod-security-admission/ │ │ │ └── psa-namespace-labels.yaml │ │ ├── seccomp/ │ │ │ └── seccomp-loader-daemonset.yaml │ │ ├── apparmor/ │ │ │ └── apparmor-loader-daemonset.yaml │ │ └── falco/ │ │ ├── helm-values.yaml ← BẮT BUỘC: driver.kind=ebpf cho GKE COS │ │ └── custom-rules.yaml │ ├── L7-observability/ │ │ ├── ingress/ │ │ │ ├── nginx-ingress-class.yaml │ │ │ └── app-ingress-tls.yaml │ │ ├── prometheus/ │ │ │ └── helm-values.yaml │ │ ├── loki/ │ │ │ └── helm-values.yaml │ │ └── grafana/ │ │ └── dashboards/ │ │ ├── security-overview.json │ │ └── falco-alerts.json │ └── apps/ │ ├── demo-app/ │ │ ├── deployment.yaml │ │ ├── service.yaml │ │ └── networkpolicy.yaml │ └── baseline-app/ │ └── deployment.yaml ├── evaluation/ │ ├── scenarios/ │ │ ├── S1-privileged-pod.yaml │ │ ├── S2-rbac-escalation.yaml │ │ ├── S3-lateral-movement.yaml │ │ ├── S4-unsigned-image.yaml │ │ ├── S5-secrets-exfiltration.yaml │ │ └── run-scenario.sh │ ├── results/ │ │ └── .gitkeep │ └── compare-baseline.sh ├── docs/ │ ├── architecture.md │ ├── deployment-guide.md │ ├── evaluation-report.md │ └── threat-model.md └── .github/ └── workflows/ ├── trivy-scan.yaml └── deploy.yaml

---

## 3. GCP INFRASTRUCTURE SPECIFICATION

### Cluster: GKE Standard ZONAL (bắt buộc)

Project ID : mlsa-k8s-capstone Zone : asia-southeast1-b ← ZONAL, KHÔNG phải region asia-southeast1 Cluster name : mlsa-k8s-cluster GKE channel : REGULAR (stable, tự động patch)

> **Tại sao ZONAL?** Regional cluster tạo nodes ở 3 zone → nhân 3 số VM → chi phí
> gấp 3 lần. Với $300 free credit, bắt buộc dùng Zonal.

### Node Pools — 5 VM tổng cộng

| Pool | Số VM | Machine type | vCPU | RAM | Autoscale | Label | Taint |
|---|---|---|---|---|---|---|---|
| system-pool | 2 | e2-standard-4 | 4 | 16GB | Không | `dedicated=system` | `dedicated=system:NoSchedule` |
| workload-pool | 2 | e2-standard-2 | 2 | 8GB | Không | `workload-type=application` | Không |
| evaluation-pool | 0→1 | e2-standard-2 | 2 | 8GB | min=0, max=1 | `workload-type=evaluation` | Không |

> **Tại sao system-pool dùng e2-standard-4?**
> Istio (~500MB) + Gatekeeper (~300MB) + Falco (~200MB) + Prometheus (~500MB)
> + Grafana (~200MB) + Loki (~300MB) = ~2GB overhead chỉ riêng system tools.
> e2-standard-2 (8GB) không đủ margin, dễ bị OOMKill.

> **QUAN TRỌNG — Taint + Toleration:**
> system-pool có taint `dedicated=system:NoSchedule`. Điều này có nghĩa:
> - Mọi Helm chart deploy lên system-pool (Istio, Gatekeeper, Falco, Prometheus,
>   Grafana, Loki, ingress-nginx, cert-manager) đều PHẢI có `tolerations` +
>   `nodeSelector` trong helm-values.yaml hoặc --set flags.
> - Nếu thiếu, pods sẽ stuck ở Pending vì không schedule được lên node nào.
> - Template bắt buộc cho mọi system Helm chart:
>   ```yaml
>   tolerations:
>     - key: "dedicated"
>       operator: "Equal"
>       value: "system"
>       effect: "NoSchedule"
>   nodeSelector:
>     dedicated: system
>   ```

### Chi phí thực (asia-southeast1-b)

| Thành phần | Spec | Giá/giờ/node | Giờ/tháng | Tổng |
|---|---|---|---|---|
| system-pool × 2 | e2-standard-4 | $0.134 | 720 | ~$193 |
| workload-pool × 2 | e2-standard-2 | $0.067 | 720 | ~$97 |
| evaluation-pool × 1 | e2-standard-2 | $0.067 | ~60h | ~$4 |
| Persistent Disk 80GB | pd-ssd | — | — | ~$14 |
| Artifact Registry | ~5GB | — | — | ~$2 |
| Cloud Logging | — | — | — | ~$3 |
| **TỔNG đầy đủ** | | | | **~$313/tháng** |

**→ Chiến lược tiết kiệm (chạy 12h/ngày):**

```bash
# Tắt nodes mỗi tối → tiết kiệm 50%
make pause    # Tắt trước khi đi ngủ
make resume   # Bật khi bắt đầu làm
# Chi phí thực: ~$160/tháng → dùng được gần 2 tháng với $300 credit
4. CODING & CONFIGURATION STANDARDS
Nguyên tắc cứng
1.  Helm       → cài tools (Gatekeeper, Istio, cert-manager, Falco, Prometheus, Loki)
2.  kubectl    → custom YAML (RBAC, NetworkPolicy, PSA labels, app manifests)
3.  Terraform  → GCP resources (GKE cluster, Binary Auth, IAM, GCS bucket)
4.  gcloud CLI → gcp operations (get-credentials, resize, logging)
5.  KHÔNG hardcode secrets — dùng Workload Identity hoặc Sealed Secrets
6.  KHÔNG dùng * trong RBAC verbs hoặc resources
7.  KHÔNG bind cluster-admin cho bất kỳ workload ServiceAccount nào
8.  LUÔN bắt đầu NetworkPolicy bằng deny-all + allow DNS egress + allow Istio sidecar
9.  Mọi Helm chart lên system-pool PHẢI có tolerations + nodeSelector
10. Gatekeeper policies PHẢI tạo ConstraintTemplate TRƯỚC, Constraint SAU
11. Falco trên GKE COS nodes PHẢI dùng driver.kind=ebpf (kernel module KHÔNG hoạt động)
12. Binary Authorization PHẢI có whitelist patterns cho tất cả system image registries
.gitignore (bắt buộc có)
# Terraform state — KHÔNG commit lên git
*.tfstate
*.tfstate.*
.terraform/
*.tfvars
tfplan

# Credentials — KHÔNG bao giờ commit
.env
*.pem
*.key
*.json
kubeconfig
Terraform: main.tf — backend + provider + cluster
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
Terraform: variables.tf
# ═══════════════════════════════════════════════════════════════════════
# variables.tf
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
Terraform: terraform.tfvars.example
# ═══════════════════════════════════════════════════════════════════════
# terraform.tfvars.example — Copy thành terraform.tfvars và điền giá trị thật
# KHÔNG commit file terraform.tfvars lên git
# ═══════════════════════════════════════════════════════════════════════

project_id = "mlsa-k8s-capstone"
admin_cidr = "YOUR_PUBLIC_IP/32"    # Lấy bằng: curl -s ifconfig.me
# region   = "asia-southeast1"     # Uncomment nếu muốn override default
# zone     = "asia-southeast1-b"   # Uncomment nếu muốn override default
Terraform: node_pools.tf
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
Terraform: binary_auth.tf
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
Terraform: outputs.tf
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
Gatekeeper: ConstraintTemplate + Constraint pattern
# ═══════════════════════════════════════════════════════════════════════
# kubernetes/L2-control-plane/gatekeeper-policies/templates/privileged-container-template.yaml
# ConstraintTemplate — PHẢI apply TRƯỚC Constraint
# ═══════════════════════════════════════════════════════════════════════
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8sdenyprivileged
  annotations:
    description: "Denies privileged containers"
spec:
  crd:
    spec:
      names:
        kind: K8sDenyPrivileged
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8sdenyprivileged

        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          container.securityContext.privileged == true
          msg := sprintf("Privileged container not allowed: %v", [container.name])
        }

        violation[{"msg": msg}] {
          container := input.review.object.spec.initContainers[_]
          container.securityContext.privileged == true
          msg := sprintf("Privileged init container not allowed: %v", [container.name])
        }
# ═══════════════════════════════════════════════════════════════════════
# kubernetes/L2-control-plane/gatekeeper-policies/constraints/deny-privileged-containers.yaml
# Constraint — apply SAU khi ConstraintTemplate đã ready
# ═══════════════════════════════════════════════════════════════════════
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sDenyPrivileged
metadata:
  name: deny-privileged-containers
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
    excludedNamespaces:
      - kube-system
      - gatekeeper-system
      - falco                # Falco cần privileged access
      - istio-system
      - cert-manager
# ═══════════════════════════════════════════════════════════════════════
# kubernetes/L2-control-plane/gatekeeper-policies/config.yaml
# Gatekeeper Config — exclude system namespaces từ webhook
# ═══════════════════════════════════════════════════════════════════════
apiVersion: config.gatekeeper.sh/v1alpha1
kind: Config
metadata:
  name: config
  namespace: gatekeeper-system
spec:
  sync:
    syncOnly:
      - group: ""
        version: "v1"
        kind: "Namespace"
      - group: ""
        version: "v1"
        kind: "Pod"
  match:
    - excludedNamespaces:
        - kube-system
        - gatekeeper-system
        - cert-manager
        - istio-system
        - falco
      processes:
        - "*"
Kubernetes Deployment: security context bắt buộc
spec:
  template:
    spec:
      serviceAccountName: demo-app-sa   # SA riêng, không dùng default
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 2000
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: app
          image: /demo-app:latest
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: ["ALL"]
          volumeMounts:
            - name: tmp-dir
              mountPath: /tmp            # Bắt buộc khi readOnlyRootFilesystem=true
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "500m"
              memory: "512Mi"
      volumes:
        - name: tmp-dir
          emptyDir: {}
PSA labels theo namespace
# production, staging → restricted (workload thông thường)
pod-security.kubernetes.io/enforce: restricted
pod-security.kubernetes.io/audit: restricted
pod-security.kubernetes.io/warn: restricted

# falco, node-exporter → privileged (cần hostPID, hostNetwork, hostPath)
pod-security.kubernetes.io/enforce: privileged

# monitoring (prometheus, grafana) → baseline (cần một số elevated perms)
pod-security.kubernetes.io/enforce: baseline
pod-security.kubernetes.io/audit: restricted
NetworkPolicy: deny-all + allow DNS + allow Istio
# ═══════════════════════════════════════════════════════════════════════
# 1. Deny ALL trước
# ═══════════════════════════════════════════════════════════════════════
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes: ["Ingress", "Egress"]
---
# ═══════════════════════════════════════════════════════════════════════
# 2. Allow DNS egress (bắt buộc — nếu không pods không resolve hostname)
# ═══════════════════════════════════════════════════════════════════════
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-egress
  namespace: production
spec:
  podSelector: {}
  policyTypes: ["Egress"]
  egress:
    - ports:
        - port: 53
          protocol: UDP
        - port: 53
          protocol: TCP
---
# ═══════════════════════════════════════════════════════════════════════
# 3. Allow Istio sidecar ports (bắt buộc khi có deny-all + Istio injection)
# ═══════════════════════════════════════════════════════════════════════
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-istio-sidecar
  namespace: production
spec:
  podSelector: {}
  policyTypes: ["Ingress", "Egress"]
  ingress:
    - ports:
        - port: 15006    # Istio inbound listener
          protocol: TCP
        - port: 15021    # Istio health check
          protocol: TCP
        - port: 15090    # Istio Prometheus metrics
          protocol: TCP
  egress:
    - ports:
        - port: 15001    # Istio outbound listener
          protocol: TCP
        - port: 15012    # Istiod xDS gRPC
          protocol: TCP
        - port: 443      # Istiod webhook + GKE API server
          protocol: TCP
Falco Helm Values — BẮT BUỘC eBPF driver
# ═══════════════════════════════════════════════════════════════════════
# kubernetes/L6-workload/falco/helm-values.yaml
# BẮT BUỘC: driver.kind=ebpf vì GKE COS nodes không cho phép kernel module
# ═══════════════════════════════════════════════════════════════════════
driver:
  kind: ebpf   # KHÔNG dùng kind: module (default) — sẽ crash trên COS

falco:
  grpc:
    enabled: true
  grpc_output:
    enabled: true
  json_output: true
  log_stderr: true
  log_syslog: false

# Falco DaemonSet cần schedule lên TẤT CẢ nodes (kể cả system-pool)
# để monitor runtime trên mọi node
tolerations:
  - operator: "Exists"   # Tolerate mọi taint — Falco cần chạy everywhere

# Resource limits
resources:
  requests:
    cpu: "100m"
    memory: "256Mi"
  limits:
    cpu: "500m"
    memory: "512Mi"
Helm Values Template cho System Tools (toleration + nodeSelector)
# ═══════════════════════════════════════════════════════════════════════
# Template chung cho TẤT CẢ Helm charts deploy lên system-pool
# Copy block này vào mỗi helm-values.yaml của: cert-manager, gatekeeper,
# prometheus, grafana, loki, ingress-nginx
# ═══════════════════════════════════════════════════════════════════════

# Cho Prometheus Stack (kube-prometheus-stack):
# kubernetes/L7-observability/prometheus/helm-values.yaml
prometheus:
  prometheusSpec:
    tolerations:
      - key: "dedicated"
        operator: "Equal"
        value: "system"
        effect: "NoSchedule"
    nodeSelector:
      dedicated: system
    resources:
      requests:
        cpu: "200m"
        memory: "512Mi"
      limits:
        cpu: "1000m"
        memory: "2Gi"

alertmanager:
  alertmanagerSpec:
    tolerations:
      - key: "dedicated"
        operator: "Equal"
        value: "system"
        effect: "NoSchedule"
    nodeSelector:
      dedicated: system

grafana:
  tolerations:
    - key: "dedicated"
      operator: "Equal"
      value: "system"
      effect: "NoSchedule"
  nodeSelector:
    dedicated: system
  resources:
    requests:
      cpu: "100m"
      memory: "128Mi"
    limits:
      cpu: "500m"
      memory: "512Mi"
# kubernetes/L7-observability/loki/helm-values.yaml
loki:
  commonConfig:
    replication_factor: 1   # Single node — đủ cho capstone
  storage:
    type: filesystem

tolerations:
  - key: "dedicated"
    operator: "Equal"
    value: "system"
    effect: "NoSchedule"
nodeSelector:
  dedicated: system

resources:
  requests:
    cpu: "100m"
    memory: "256Mi"
  limits:
    cpu: "500m"
    memory: "512Mi"
5. TRIỂN KHAI TỪNG BƯỚC
Bước 0: Cài tools trên máy local
macOS / Linux:

# Kubernetes + Helm + Terraform + GCP
brew install kubectl helm terraform
brew install google-cloud-sdk

# Security tools
brew install cosign trivy

# Istio CLI (brew KHÔNG có istioctl — phải cài riêng)
curl -L https://istio.io/downloadIstio | sh -
# Sau đó thêm vào PATH (thay X.Y.Z bằng version vừa download):
export PATH=$HOME/istio-X.Y.Z/bin:$PATH
# Thêm vào ~/.zshrc hoặc ~/.bashrc để persistent
Windows (PowerShell với quyền Admin):

winget install Kubernetes.kubectl
winget install Helm.Helm
winget install Hashicorp.Terraform
winget install Google.CloudSDK

# Trivy và Cosign: tải file .exe từ GitHub Releases
# Istio: dùng WSL2 (Ubuntu) để chạy curl script trên
VSCode extensions:

ms-kubernetes-tools.vscode-kubernetes-tools
redhat.vscode-yaml
hashicorp.terraform
eamodio.gitlens
ms-azuretools.vscode-docker
googlecloudtools.cloudcode
GCP login:

gcloud auth login
gcloud auth application-default login
gcloud config set project mlsa-k8s-capstone
gcloud services enable container.googleapis.com \
  binaryauthorization.googleapis.com \
  artifactregistry.googleapis.com \
  logging.googleapis.com
Bước 1: Tạo GCS bucket cho Terraform state (chạy 1 lần duy nhất)
# Chạy TRƯỚC terraform init — chỉ người setup lần đầu chạy
bash infrastructure/terraform/scripts/create-tfstate-bucket.sh

# Nội dung script:
# #!/bin/bash
# set -e
# gcloud storage buckets create gs://mlsa-k8s-tfstate \
#   --project=mlsa-k8s-capstone \
#   --location=asia-southeast1 \
#   --uniform-bucket-level-access
# echo "✅ GCS bucket created: gs://mlsa-k8s-tfstate"
Bước 2: Tạo GKE Cluster bằng Terraform
cd infrastructure/terraform

# Copy và điền giá trị thật
cp terraform.tfvars.example terraform.tfvars
# Sửa admin_cidr trong terraform.tfvars thành IP thật của bạn

terraform init
terraform plan -out=tfplan
terraform apply tfplan

# Kết nối kubectl — ZONAL dùng --zone
gcloud container clusters get-credentials mlsa-k8s-cluster \
  --zone asia-southeast1-b \
  --project mlsa-k8s-capstone

# Kiểm tra cluster ready
kubectl get nodes
# Expected: 4 nodes (2 system + 2 workload) STATUS=Ready
# system-pool nodes sẽ có taint dedicated=system:NoSchedule
Bước 3: Bootstrap — cài Helm tools và namespaces
# ── Tạo tất cả namespaces trước ──
kubectl apply -f kubernetes/namespaces/

# ── Thêm tất cả Helm repos một lần ──
helm repo add jetstack         https://charts.jetstack.io
helm repo add gatekeeper       https://open-policy-agent.github.io/gatekeeper/charts
helm repo add falcosecurity    https://falcosecurity.github.io/charts
helm repo add aqua             https://aquasecurity.github.io/helm-charts/
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana          https://grafana.github.io/helm-charts
helm repo add ingress-nginx    https://kubernetes.github.io/ingress-nginx
helm repo update

# ── Cài cert-manager (L3 prerequisite) — VỚI toleration cho system-pool ──
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --set installCRDs=true \
  --set tolerations[0].key=dedicated \
  --set tolerations[0].operator=Equal \
  --set tolerations[0].value=system \
  --set tolerations[0].effect=NoSchedule \
  --set nodeSelector.dedicated=system \
  --set webhook.tolerations[0].key=dedicated \
  --set webhook.tolerations[0].operator=Equal \
  --set webhook.tolerations[0].value=system \
  --set webhook.tolerations[0].effect=NoSchedule \
  --set webhook.nodeSelector.dedicated=system \
  --set cainjector.tolerations[0].key=dedicated \
  --set cainjector.tolerations[0].operator=Equal \
  --set cainjector.tolerations[0].value=system \
  --set cainjector.tolerations[0].effect=NoSchedule \
  --set cainjector.nodeSelector.dedicated=system \
  --wait --timeout=5m

# ── Cài Istio (L3 prerequisite) — VỚI toleration cho system-pool ──
istioctl install --set profile=default \
  --set values.global.defaultTolerations[0].key=dedicated \
  --set values.global.defaultTolerations[0].operator=Equal \
  --set values.global.defaultTolerations[0].value=system \
  --set values.global.defaultTolerations[0].effect=NoSchedule \
  --set values.global.defaultNodeSelector.dedicated=system \
  -y

kubectl label namespace production istio-injection=enabled --overwrite
kubectl label namespace staging    istio-injection=enabled --overwrite

# ── Cài OPA Gatekeeper (L2 prerequisite) — VỚI toleration cho system-pool ──
helm install gatekeeper gatekeeper/gatekeeper \
  --namespace gatekeeper-system --create-namespace \
  --set tolerations[0].key=dedicated \
  --set tolerations[0].operator=Equal \
  --set tolerations[0].value=system \
  --set tolerations[0].effect=NoSchedule \
  --set nodeSelector.dedicated=system \
  --wait --timeout=5m
Bước 4: Deploy từng Layer theo thứ tự
# ═══════════════════════════════════════════════════════════════════════
# L1: Node hardening
# Phần lớn L1 đã trong Terraform (Shielded Nodes, COS)
# Chỉ apply DaemonSet configs còn lại
# ═══════════════════════════════════════════════════════════════════════
kubectl apply -f kubernetes/L1-infrastructure/

# ═══════════════════════════════════════════════════════════════════════
# L2: RBAC + Gatekeeper policies
# QUAN TRỌNG: Thứ tự = Config → Templates → (đợi) → Constraints
# ═══════════════════════════════════════════════════════════════════════
kubectl apply -f kubernetes/L2-control-plane/rbac/

# Đợi Gatekeeper webhook sẵn sàng
echo "Waiting for Gatekeeper webhook..."
kubectl wait --for=condition=Ready pod \
  -l control-plane=controller-manager \
  -n gatekeeper-system --timeout=180s

# Apply theo đúng thứ tự: Config → Templates → Constraints
kubectl apply -f kubernetes/L2-control-plane/gatekeeper-policies/config.yaml
sleep 5
kubectl apply -f kubernetes/L2-control-plane/gatekeeper-policies/templates/ --recursive
echo "Waiting for ConstraintTemplates to register CRDs..."
sleep 15
kubectl apply -f kubernetes/L2-control-plane/gatekeeper-policies/constraints/ --recursive

# Audit logging đã được cấu hình trong Terraform — không cần kubectl

# ═══════════════════════════════════════════════════════════════════════
# L3: Identity & mTLS
# cert-manager và Istio đã cài bằng Helm ở Bước 3
# ═══════════════════════════════════════════════════════════════════════
kubectl apply -f kubernetes/L3-identity/workload-identity/ --recursive
kubectl apply -f kubernetes/L3-identity/cert-manager/      --recursive
kubectl apply -f kubernetes/L3-identity/istio/             --recursive

# Restart existing deployments để Istio sidecar inject
echo "Restarting pods for Istio sidecar injection..."
kubectl rollout restart deployment -n production 2>/dev/null || true
kubectl rollout restart deployment -n staging    2>/dev/null || true
echo "Waiting for sidecar injection to complete..."
sleep 30

# ═══════════════════════════════════════════════════════════════════════
# L4: Network Policies
# PHẢI deploy SAU L3 — nếu trước, sẽ block Istio control plane traffic
# Thứ tự: deny-all → allow-dns → allow-istio → allow-monitoring → allow-ingress
# ═══════════════════════════════════════════════════════════════════════
kubectl apply -f kubernetes/L4-network/default-deny-all-production.yaml
kubectl apply -f kubernetes/L4-network/default-deny-all-staging.yaml
kubectl apply -f kubernetes/L4-network/allow-dns-egress.yaml
kubectl apply -f kubernetes/L4-network/allow-istio-sidecar.yaml
sleep 5
kubectl apply -f kubernetes/L4-network/allow-monitoring.yaml
kubectl apply -f kubernetes/L4-network/allow-ingress.yaml

# ═══════════════════════════════════════════════════════════════════════
# L5: Supply Chain
# Binary Authorization đã trong Terraform (binary_auth.tf)
# ═══════════════════════════════════════════════════════════════════════
helm install trivy-operator aqua/trivy-operator \
  --namespace trivy-system --create-namespace \
  -f kubernetes/L5-supply-chain/trivy-operator/helm-values.yaml \
  --wait --timeout=5m

# ═══════════════════════════════════════════════════════════════════════
# L6: Workload & Runtime
# ═══════════════════════════════════════════════════════════════════════
kubectl apply -f kubernetes/L6-workload/pod-security-admission/ --recursive
kubectl apply -f kubernetes/L6-workload/seccomp/                --recursive
kubectl apply -f kubernetes/L6-workload/apparmor/               --recursive

# Falco: cài vào namespace 'falco' (PSA=privileged) bằng Helm
# BẮT BUỘC driver.kind=ebpf — COS nodes không support kernel module
helm install falco falcosecurity/falco \
  --namespace falco --create-namespace \
  -f kubernetes/L6-workload/falco/helm-values.yaml \
  --wait --timeout=5m

kubectl apply -f kubernetes/L6-workload/falco/custom-rules.yaml

# ═══════════════════════════════════════════════════════════════════════
# L7: Ingress + Observability
# ═══════════════════════════════════════════════════════════════════════
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.tolerations[0].key=dedicated \
  --set controller.tolerations[0].operator=Equal \
  --set controller.tolerations[0].value=system \
  --set controller.tolerations[0].effect=NoSchedule \
  --set controller.nodeSelector.dedicated=system \
  --wait --timeout=5m

kubectl apply -f kubernetes/L7-observability/ingress/ --recursive

helm install kube-prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  -f kubernetes/L7-observability/prometheus/helm-values.yaml \
  --wait --timeout=10m

helm install loki grafana/loki \
  --namespace monitoring \
  -f kubernetes/L7-observability/loki/helm-values.yaml \
  --wait --timeout=5m

# ═══════════════════════════════════════════════════════════════════════
# Deploy Apps
# ═══════════════════════════════════════════════════════════════════════
kubectl apply -f kubernetes/apps/demo-app/     --recursive
kubectl apply -f kubernetes/apps/baseline-app/ --recursive
Bước 5: Verify từng Layer
# L2 — RBAC: default SA không được tạo pods
kubectl auth can-i create pods \
  --as=system:serviceaccount:production:default -n production
# Expected output: no

# L2 — Gatekeeper: ConstraintTemplates đã ready
kubectl get constrainttemplates
# Expected: k8sdenyprivileged, k8srequireresourcelimits, etc. — STATUS: True

# L2 — Gatekeeper: privileged pod bị block
kubectl apply -f evaluation/scenarios/S1-privileged-pod.yaml --dry-run=server
# Expected: Error from server: admission webhook denied

# L3 — mTLS STRICT đang active
kubectl get peerauthentication -A
# Expected: production/default → STRICT

# L3 — Verify sidecar injection
kubectl get pods -n production -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}'
# Expected: mỗi pod có 2 containers: app, istio-proxy

# L4 — NetworkPolicy: cross-namespace bị block
kubectl run nettest -n staging --image=busybox:latest --rm -it \
  --restart=Never -- wget -T 3 http://demo-app.production.svc.cluster.local
# Expected: wget: download timed out

# L4 — DNS vẫn hoạt động sau deny-all
kubectl run dnstest -n production --image=busybox:latest --rm -it \
  --restart=Never -- nslookup kubernetes.default
# Expected: Server: 10.x.x.10 (kube-dns resolves OK)

# L5 — Binary Authorization: unsigned image bị block
kubectl apply -f evaluation/scenarios/S4-unsigned-image.yaml --dry-run=server
# Expected: Error — denied by Binary Authorization

# L6 — Falco đang theo dõi (phải thấy log output)
kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=20 --follow
# Expected: Falco initialized, driver=ebpf

# L7 — Ingress TLS
kubectl get svc -n ingress-nginx ingress-nginx-controller
# Lấy EXTERNAL_IP rồi:
curl -k https:///health

# Tổng hợp — check tất cả pods healthy
kubectl get pods -A | grep -v Running | grep -v Completed
# Expected: không có pod nào stuck ở Pending/CrashLoop
6. EVALUATION SCENARIOS
Format chạy
# Chạy từng scenario (apply YAML vào cả secured và baseline, so sánh kết quả)
bash evaluation/scenarios/run-scenario.sh S1
bash evaluation/scenarios/run-scenario.sh S2
bash evaluation/scenarios/run-scenario.sh S3
bash evaluation/scenarios/run-scenario.sh S4
bash evaluation/scenarios/run-scenario.sh S5

# Tổng hợp kết quả
bash evaluation/compare-baseline.sh
Kết quả kỳ vọng
ID	Mô tả attack	Layers	Secured	Baseline
S1	Deploy privileged pod	L2, L6	❌ BLOCKED — Gatekeeper + PSA	✅ ALLOWED
S2	SA token abuse → cluster-admin	L2	❌ BLOCKED — RBAC deny	✅ ALLOWED
S3	Lateral movement cross-namespace	L3, L4	❌ BLOCKED — NetworkPolicy + mTLS	✅ ALLOWED
S4	Deploy unsigned image	L5	❌ BLOCKED — Binary Authorization	✅ ALLOWED
S5	Read secrets từ namespace khác	L2	❌ BLOCKED — RBAC scope	✅ ALLOWED
QUAN TRỌNG cho S4 (unsigned image): Binary Authorization chỉ block images KHÔNG nằm trong whitelist (binary_auth.tf). Test S4 bằng cách deploy image từ registry không được whitelist:

# evaluation/scenarios/S4-unsigned-image.yaml
spec:
  containers:
    - name: malicious
      image: docker.io/randomattacker/malicious-app:latest
      # Registry "docker.io/randomattacker" không nằm trong whitelist → bị BLOCK
7. HÀNH VI CỦA CLAUDE TRONG PROJECT
Khi viết RBAC:
Không bao giờ dùng * trong verbs hoặc resources
Luôn tạo ServiceAccount riêng cho mỗi workload (không dùng default)
Không bao giờ bind cluster-admin cho workload SA
Khi viết Gatekeeper policies:
LUÔN tạo ConstraintTemplate TRƯỚC trong thư mục templates/
SAU ĐÓ tạo Constraint trong thư mục constraints/
LUÔN exclude system namespaces: kube-system, gatekeeper-system, istio-system, cert-manager, falco
Rego code phải check CẢ containers VÀ initContainers
LUÔN tạo Gatekeeper Config để exclude system namespaces khỏi webhook
Khi viết NetworkPolicy:
Luôn tạo default-deny-all cho namespace trước
Luôn thêm allow-dns-egress ngay sau deny-all (DNS port 53 UDP+TCP)
Luôn thêm allow-istio-sidecar (ports 15001, 15006, 15012, 15021) cho namespace có Istio
Thứ tự apply: deny-all → allow-dns → allow-istio → allow-monitoring → allow-ingress
Comment rõ mỗi allow rule: # Allows:  →  vì 
Khi viết Helm values cho system tools:
LUÔN thêm tolerations + nodeSelector cho system-pool
Template toleration bắt buộc:
tolerations:
  - key: "dedicated"
    operator: "Equal"
    value: "system"
    effect: "NoSchedule"
nodeSelector:
  dedicated: system
Kiểm tra chart có sub-components không (cert-manager có webhook + cainjector — mỗi cái cần toleration riêng)
Khi viết Falco config:
LUÔN set driver.kind: ebpf (GKE COS không support kernel module)
Deploy trong namespace falco với PSA=privileged
Falco DaemonSet dùng tolerations: [{operator: "Exists"}] để chạy trên MỌI node
Khi viết Terraform cho GKE:
LUÔN có backend "gcs" block trong terraform block
LUÔN dùng location = var.zone với default "asia-southeast1-b" (ZONAL)
LUÔN có cả network_policy block VÀ addons_config.network_policy_config
LUÔN có logging_config để thay thế audit-policy.yaml
LUÔN có shielded_instance_config trong node_config của từng node pool
KHÔNG dùng enable_shielded_nodes (deprecated trong provider ~> 5.0)
System pool PHẢI có CẢ labels VÀ taint (label cho nodeSelector, taint để đẩy pod)
Khi viết Binary Authorization:
PHẢI có whitelist patterns cho TẤT CẢ registries mà system images sử dụng
Tối thiểu: gcr.io, gke.gcr.io, registry.k8s.io, k8s.gcr.io, docker.io/istio, ghcr.io, quay.io
Docker Hub official: docker.io/library/*
Monitoring: docker.io/grafana/, docker.io/prom/
Security: docker.io/falcosecurity/, docker.io/aquasec/
Project Artifact Registry: ${region}-docker.pkg.dev/${project_id}/*
Khi debug lỗi:
# Pod stuck Pending — check toleration/nodeSelector mismatch
kubectl describe pod  -n 
kubectl get events -n  --sort-by='.lastTimestamp'

# Gatekeeper: ConstraintTemplate not ready
kubectl get constrainttemplates
kubectl describe constrainttemplate 

# Gatekeeper policy vi phạm
kubectl get constraintviolations -A

# Binary Auth blocking image
gcloud logging read \
  'resource.type="k8s_cluster" protoPayload.response.reason="BINARY_AUTHORIZATION"' \
  --project mlsa-k8s-capstone --limit 10

# Falco crash — kiểm tra driver
kubectl logs -n falco -l app.kubernetes.io/name=falco | grep -i "driver\|error\|probe"

# NetworkPolicy: tại sao bị block
kubectl run debug --image=busybox --rm -it -n  -- wget -T 3 

# NetworkPolicy + Istio debug — kiểm tra sidecar có inject không
kubectl get pod  -n production -o jsonpath='{.spec.containers[*].name}'
# Expected: app, istio-proxy (2 containers)

# Istio mTLS debug
kubectl exec -n production  -c istio-proxy -- \
  curl -s localhost:15000/config_dump | grep -A5 "tls_context"

# Audit log trên GCP Console
gcloud logging read \
  'resource.type="k8s_cluster" protoPayload.methodName=~"pods"' \
  --project mlsa-k8s-capstone --limit 20 --format json
8. MAKEFILE
.PHONY: setup bootstrap deploy-l1 deploy-l2 deploy-l3 deploy-l4 \
        deploy-l5 deploy-l6 deploy-l7 deploy-app deploy-all \
        verify evaluate pause resume clean

# ═══════════════════════════════════════════════════════════════════════
# Khởi tạo
# ═══════════════════════════════════════════════════════════════════════
setup:
	bash infrastructure/terraform/scripts/create-tfstate-bucket.sh
	cd infrastructure/terraform && terraform init
	cd infrastructure/terraform && \
	  terraform apply -var="admin_cidr=$$(curl -s ifconfig.me)/32" \
	  -var="project_id=mlsa-k8s-capstone" -auto-approve
	gcloud container clusters get-credentials mlsa-k8s-cluster \
	  --zone asia-southeast1-b --project mlsa-k8s-capstone

bootstrap:
	kubectl apply -f kubernetes/namespaces/
	helm repo add jetstack https://charts.jetstack.io
	helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
	helm repo add falcosecurity https://falcosecurity.github.io/charts
	helm repo add aqua https://aquasecurity.github.io/helm-charts/
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo add grafana https://grafana.github.io/helm-charts
	helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
	helm repo update
	helm install cert-manager jetstack/cert-manager \
	  --namespace cert-manager --create-namespace \
	  --set installCRDs=true \
	  --set tolerations[0].key=dedicated \
	  --set tolerations[0].operator=Equal \
	  --set tolerations[0].value=system \
	  --set tolerations[0].effect=NoSchedule \
	  --set nodeSelector.dedicated=system \
	  --set webhook.tolerations[0].key=dedicated \
	  --set webhook.tolerations[0].operator=Equal \
	  --set webhook.tolerations[0].value=system \
	  --set webhook.tolerations[0].effect=NoSchedule \
	  --set webhook.nodeSelector.dedicated=system \
	  --set cainjector.tolerations[0].key=dedicated \
	  --set cainjector.tolerations[0].operator=Equal \
	  --set cainjector.tolerations[0].value=system \
	  --set cainjector.tolerations[0].effect=NoSchedule \
	  --set cainjector.nodeSelector.dedicated=system \
	  --wait --timeout=5m
	istioctl install --set profile=default \
	  --set values.global.defaultTolerations[0].key=dedicated \
	  --set values.global.defaultTolerations[0].operator=Equal \
	  --set values.global.defaultTolerations[0].value=system \
	  --set values.global.defaultTolerations[0].effect=NoSchedule \
	  --set values.global.defaultNodeSelector.dedicated=system \
	  -y
	kubectl label namespace production istio-injection=enabled --overwrite
	kubectl label namespace staging istio-injection=enabled --overwrite
	helm install gatekeeper gatekeeper/gatekeeper \
	  --namespace gatekeeper-system --create-namespace \
	  --set tolerations[0].key=dedicated \
	  --set tolerations[0].operator=Equal \
	  --set tolerations[0].value=system \
	  --set tolerations[0].effect=NoSchedule \
	  --set nodeSelector.dedicated=system \
	  --wait --timeout=5m

# ═══════════════════════════════════════════════════════════════════════
# Deploy layers
# ═══════════════════════════════════════════════════════════════════════
deploy-l1:
	kubectl apply -f kubernetes/L1-infrastructure/ --recursive

deploy-l2:
	kubectl apply -f kubernetes/L2-control-plane/rbac/ --recursive
	kubectl wait --for=condition=Ready pod \
	  -l control-plane=controller-manager \
	  -n gatekeeper-system --timeout=180s
	kubectl apply -f kubernetes/L2-control-plane/gatekeeper-policies/config.yaml
	sleep 5
	kubectl apply -f kubernetes/L2-control-plane/gatekeeper-policies/templates/ --recursive
	@echo "⏳ Waiting for ConstraintTemplates to register CRDs..."
	sleep 15
	kubectl apply -f kubernetes/L2-control-plane/gatekeeper-policies/constraints/ --recursive

deploy-l3:
	kubectl apply -f kubernetes/L3-identity/workload-identity/ --recursive
	kubectl apply -f kubernetes/L3-identity/cert-manager/      --recursive
	kubectl apply -f kubernetes/L3-identity/istio/             --recursive
	@echo "🔄 Restarting deployments for Istio sidecar injection..."
	-kubectl rollout restart deployment -n production
	-kubectl rollout restart deployment -n staging
	@echo "⏳ Waiting 30s for sidecar injection..."
	sleep 30

deploy-l4:
	kubectl apply -f kubernetes/L4-network/default-deny-all-production.yaml
	kubectl apply -f kubernetes/L4-network/default-deny-all-staging.yaml
	kubectl apply -f kubernetes/L4-network/allow-dns-egress.yaml
	kubectl apply -f kubernetes/L4-network/allow-istio-sidecar.yaml
	sleep 5
	kubectl apply -f kubernetes/L4-network/allow-monitoring.yaml
	kubectl apply -f kubernetes/L4-network/allow-ingress.yaml

deploy-l5:
	helm upgrade --install trivy-operator aqua/trivy-operator \
	  --namespace trivy-system --create-namespace \
	  -f kubernetes/L5-supply-chain/trivy-operator/helm-values.yaml \
	  --wait --timeout=5m

deploy-l6:
	kubectl apply -f kubernetes/L6-workload/pod-security-admission/ --recursive
	kubectl apply -f kubernetes/L6-workload/seccomp/                --recursive
	kubectl apply -f kubernetes/L6-workload/apparmor/               --recursive
	helm upgrade --install falco falcosecurity/falco \
	  --namespace falco --create-namespace \
	  -f kubernetes/L6-workload/falco/helm-values.yaml \
	  --wait --timeout=5m
	kubectl apply -f kubernetes/L6-workload/falco/custom-rules.yaml

deploy-l7:
	helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
	  --namespace ingress-nginx --create-namespace \
	  --set controller.tolerations[0].key=dedicated \
	  --set controller.tolerations[0].operator=Equal \
	  --set controller.tolerations[0].value=system \
	  --set controller.tolerations[0].effect=NoSchedule \
	  --set controller.nodeSelector.dedicated=system \
	  --wait --timeout=5m
	kubectl apply -f kubernetes/L7-observability/ingress/ --recursive
	helm upgrade --install kube-prometheus prometheus-community/kube-prometheus-stack \
	  --namespace monitoring \
	  -f kubernetes/L7-observability/prometheus/helm-values.yaml \
	  --wait --timeout=10m
	helm upgrade --install loki grafana/loki \
	  --namespace monitoring \
	  -f kubernetes/L7-observability/loki/helm-values.yaml \
	  --wait --timeout=5m

deploy-app:
	kubectl apply -f kubernetes/apps/demo-app/     --recursive
	kubectl apply -f kubernetes/apps/baseline-app/ --recursive

deploy-all: deploy-l1 deploy-l2 deploy-l3 deploy-l4 \
            deploy-l5 deploy-l6 deploy-l7 deploy-app

# ═══════════════════════════════════════════════════════════════════════
# Verify & Evaluate
# ═══════════════════════════════════════════════════════════════════════
verify:
	@echo "════════════════════════════════════════════"
	@echo "  L2: RBAC Check"
	@echo "════════════════════════════════════════════"
	@kubectl auth can-i create pods \
	  --as=system:serviceaccount:production:default -n production 2>&1 || \
	  echo "✅ RBAC correctly denies default SA from creating pods"
	@echo ""
	@echo "════════════════════════════════════════════"
	@echo "  L2: Gatekeeper ConstraintTemplates"
	@echo "════════════════════════════════════════════"
	@kubectl get constrainttemplates 2>/dev/null || echo "⚠️  No ConstraintTemplates found"
	@echo ""
	@echo "════════════════════════════════════════════"
	@echo "  L2: Gatekeeper Constraints"
	@echo "════════════════════════════════════════════"
	@kubectl get constraints 2>/dev/null || echo "⚠️  No Constraints found"
	@echo ""
	@echo "════════════════════════════════════════════"
	@echo "  L3: mTLS PeerAuthentication"
	@echo "════════════════════════════════════════════"
	@kubectl get peerauthentication -A
	@echo ""
	@echo "════════════════════════════════════════════"
	@echo "  L4: NetworkPolicies"
	@echo "════════════════════════════════════════════"
	@kubectl get networkpolicies -A
	@echo ""
	@echo "════════════════════════════════════════════"
	@echo "  L6: Falco Status"
	@echo "════════════════════════════════════════════"
	@kubectl get pods -n falco
	@echo ""
	@echo "════════════════════════════════════════════"
	@echo "  Constraint Violations"
	@echo "════════════════════════════════════════════"
	@kubectl get constraintviolations -A 2>/dev/null || echo "✅ No violations found"
	@echo ""
	@echo "════════════════════════════════════════════"
	@echo "  Unhealthy Pods"
	@echo "════════════════════════════════════════════"
	@kubectl get pods -A | grep -v Running | grep -v Completed | grep -v NAME || \
	  echo "✅ All pods are healthy"
	@echo ""
	@echo "════════════════════════════════════════════"
	@echo "  Node Status"
	@echo "════════════════════════════════════════════"
	@kubectl get nodes -o wide

evaluate:
	bash evaluation/scenarios/run-scenario.sh S1
	bash evaluation/scenarios/run-scenario.sh S2
	bash evaluation/scenarios/run-scenario.sh S3
	bash evaluation/scenarios/run-scenario.sh S4
	bash evaluation/scenarios/run-scenario.sh S5
	bash evaluation/compare-baseline.sh

# ═══════════════════════════════════════════════════════════════════════
# Quản lý chi phí
# ═══════════════════════════════════════════════════════════════════════
pause:
	@echo "⏸️  Tắt nodes để tiết kiệm chi phí..."
	gcloud container clusters resize mlsa-k8s-cluster \
	  --node-pool system-pool --num-nodes=0 \
	  --zone asia-southeast1-b --quiet
	gcloud container clusters resize mlsa-k8s-cluster \
	  --node-pool workload-pool --num-nodes=0 \
	  --zone asia-southeast1-b --quiet
	@echo "✅ Nodes đã tắt. Dùng 'make resume' để bật lại."

resume:
	@echo "▶️  Bật nodes..."
	gcloud container clusters resize mlsa-k8s-cluster \
	  --node-pool system-pool --num-nodes=2 \
	  --zone asia-southeast1-b --quiet
	gcloud container clusters resize mlsa-k8s-cluster \
	  --node-pool workload-pool --num-nodes=2 \
	  --zone asia-southeast1-b --quiet
	gcloud container clusters get-credentials mlsa-k8s-cluster \
	  --zone asia-southeast1-b --project mlsa-k8s-capstone
	@echo "✅ Nodes đã bật. Đợi 2-3 phút cho pods restart."

clean:
	gcloud container clusters delete mlsa-k8s-cluster \
	  --zone asia-southeast1-b --quiet
	@echo "⚠️  Cluster đã xóa. Terraform state vẫn còn trên GCS."
9. BẢNG KIỂM TRA NHANH TRƯỚC KHI DEPLOY
Trước khi chạy make setup, kiểm tra đủ các điều kiện sau:

#	Điều kiện	Lệnh kiểm tra
1	GCP project đã tạo	gcloud projects describe mlsa-k8s-capstone
2	Billing đã bật	GCP Console → Billing
3	Đã login GCP	gcloud auth list
4	kubectl đã cài	kubectl version --client
5	helm đã cài	helm version
6	terraform đã cài	terraform version
7	istioctl đã cài	istioctl version
8	GCS bucket chưa tồn tại	gcloud storage ls | grep tfstate
9	APIs đã enable	gcloud services list --enabled | grep container
10	terraform.tfvars đã tạo	ls infrastructure/terraform/terraform.tfvars
10. PHÂN CÔNG TEAM
Thành viên	Vai trò	Layer phụ trách
Huynh Chi Trung (Leader)	Security Architecture Lead	L2 RBAC + Gatekeeper, Evaluation framework, Final docs
Truong Tran Manh	K8s Security Engineer	L3 Istio + mTLS, L4 NetworkPolicy, L6 PSA + Falco
Nguyen Hoang Son	Infrastructure Engineer	Terraform GKE, L1 hardening, L5 Supply chain, L7 Observability
11. ENTERPRISE WORKFLOW (Team thực tế / Production-grade)
Phần này áp dụng khi nhóm muốn vận hành theo chuẩn enterprise thực tế. Với Capstone, tối thiểu cần làm Mục 11.1 và 11.2 để đủ tiêu chí chuyên nghiệp.

11.1 GitHub Branch Protection (BẮT BUỘC ngay hôm nay)
Vào GitHub repo → Settings → Branches → Add rule cho nhánh main:

✅ Require a pull request before merging
✅ Require 1 approving review (ít nhất 1 người review trước khi merge)
✅ Dismiss stale reviews when new commits are pushed
✅ Require status checks to pass (Trivy scan phải pass)
✅ Do not allow bypassing the above settings
Quy tắc làm việc của team:

main        ← protected, chỉ merge qua PR, không push trực tiếp
develop     ← nhánh tích hợp, test trước khi merge vào main
feature/L2-rbac        ← Huynh Chi Trung làm
feature/L3-mtls        ← Truong Tran Manh làm
feature/L1-terraform   ← Nguyen Hoang Son làm
11.2 GitHub Actions CI/CD (Nội dung đầy đủ)
File: .github/workflows/trivy-scan.yaml

name: Security Scan on PR

on:
  pull_request:
    branches: [main, develop]

jobs:
  trivy-scan:
    name: Trivy Vulnerability Scan
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Run Trivy scan on repo (YAML misconfig)
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: config
          scan-ref: ./kubernetes
          severity: HIGH,CRITICAL
          exit-code: 1           # Fail PR nếu có lỗi HIGH/CRITICAL

      - name: Run Trivy scan on Terraform
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: config
          scan-ref: ./infrastructure/terraform
          severity: HIGH,CRITICAL
          exit-code: 1

      - name: Validate Kubernetes YAML
        run: |
          curl -Lo kubeval.tar.gz \
            https://github.com/instrumenta/kubeval/releases/latest/download/kubeval-linux-amd64.tar.gz
          tar xf kubeval.tar.gz
          find kubernetes/ -name "*.yaml" -exec ./kubeval {} \;

  terraform-plan:
    name: Terraform Plan (preview only)
    runs-on: ubuntu-latest
    if: contains(github.event.pull_request.labels.*.name, 'infra')
    permissions:
      contents: read
      id-token: write         # Workload Identity Federation
    steps:
      - uses: actions/checkout@v4

      - name: Auth to GCP (Workload Identity — không dùng SA key)
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ secrets.WIF_SERVICE_ACCOUNT }}

      - name: Terraform Plan
        run: |
          cd infrastructure/terraform
          terraform init
          terraform plan -var="admin_cidr=0.0.0.0/0" \
            -var="project_id=mlsa-k8s-capstone" -no-color 2>&1 \
            | tee plan-output.txt

      - name: Comment plan on PR
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const plan = fs.readFileSync('infrastructure/terraform/plan-output.txt', 'utf8');
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: '### Terraform Plan\n```\n' + plan.slice(0, 60000) + '\n```'
            });
File: .github/workflows/deploy.yaml

name: Deploy to GKE

on:
  push:
    branches: [main]      # Chỉ deploy khi merge vào main

env:
  GKE_CLUSTER: mlsa-k8s-cluster
  GKE_ZONE: asia-southeast1-b
  PROJECT_ID: mlsa-k8s-capstone

jobs:
  deploy-staging:
    name: Deploy → Staging
    runs-on: ubuntu-latest
    environment: staging        # GitHub Environment với manual approval
    permissions:
      contents: read
      id-token: write
    steps:
      - uses: actions/checkout@v4

      - name: Auth to GCP
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ secrets.WIF_SERVICE_ACCOUNT }}

      - name: Get GKE credentials
        uses: google-github-actions/get-gke-credentials@v2
        with:
          cluster_name: ${{ env.GKE_CLUSTER }}
          location: ${{ env.GKE_ZONE }}

      - name: Install Helm
        uses: azure/setup-helm@v4

      - name: Deploy to staging namespace
        run: |
          kubectl apply -f kubernetes/namespaces/staging.yaml
          kubectl apply -f kubernetes/apps/demo-app/ -n staging --recursive

      - name: Run smoke test
        run: |
          kubectl rollout status deployment/demo-app -n staging --timeout=120s
          kubectl run smoketest -n staging --image=busybox:latest --rm \
            --restart=Never -- wget -T 5 http://demo-app.staging.svc.cluster.local/health

  deploy-production:
    name: Deploy → Production
    runs-on: ubuntu-latest
    needs: deploy-staging       # Phải pass staging trước
    environment: production     # Cần manual approval trên GitHub
    permissions:
      contents: read
      id-token: write
    steps:
      - uses: actions/checkout@v4

      - name: Auth to GCP
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ secrets.WIF_SERVICE_ACCOUNT }}

      - name: Get GKE credentials
        uses: google-github-actions/get-gke-credentials@v2
        with:
          cluster_name: ${{ env.GKE_CLUSTER }}
          location: ${{ env.GKE_ZONE }}

      - name: Deploy to production namespace
        run: |
          kubectl apply -f kubernetes/apps/demo-app/ -n production --recursive
          kubectl rollout status deployment/demo-app -n production --timeout=180s

      - name: Verify production health
        run: |
          kubectl get pods -n production
          kubectl get constraintviolations -A
11.3 GCP IAM — Phân quyền theo vai trò team
# Chạy 1 lần bởi Project Owner để phân quyền team
PROJECT=mlsa-k8s-capstone

# Leader (Huynh Chi Trung) — full access để setup
gcloud projects add-iam-policy-binding $PROJECT \
  --member="user:huynhchitrung@dtu.edu.vn" \
  --role="roles/container.admin"

# K8s Engineer (Truong Tran Manh) — deploy, không xóa cluster
gcloud projects add-iam-policy-binding $PROJECT \
  --member="user:ourlife937@gmail.com" \
  --role="roles/container.developer"

# Infra Engineer (Nguyen Hoang Son) — terraform, node management
gcloud projects add-iam-policy-binding $PROJECT \
  --member="user:nguyenhoangson5@dtu.edu.vn" \
  --role="roles/container.admin"
gcloud projects add-iam-policy-binding $PROJECT \
  --member="user:nguyenhoangson5@dtu.edu.vn" \
  --role="roles/compute.instanceAdmin"

# GitHub Actions Service Account — chỉ deploy, không xóa
gcloud iam service-accounts create github-actions-sa \
  --display-name="GitHub Actions Deploy SA"
gcloud projects add-iam-policy-binding $PROJECT \
  --member="serviceAccount:github-actions-sa@${PROJECT}.iam.gserviceaccount.com" \
  --role="roles/container.developer"
gcloud projects add-iam-policy-binding $PROJECT \
  --member="serviceAccount:github-actions-sa@${PROJECT}.iam.gserviceaccount.com" \
  --role="roles/storage.objectViewer"
Workload Identity Federation cho GitHub Actions (không dùng SA key file):

# Tạo Workload Identity Pool
gcloud iam workload-identity-pools create github-pool \
  --location=global \
  --display-name="GitHub Actions Pool"

# Tạo Provider
gcloud iam workload-identity-pools providers create-oidc github-provider \
  --location=global \
  --workload-identity-pool=github-pool \
  --display-name="GitHub Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
  --issuer-uri="https://token.actions.githubusercontent.com"

# Bind SA với GitHub repo
gcloud iam service-accounts add-iam-policy-binding \
  github-actions-sa@${PROJECT}.iam.gserviceaccount.com \
  --role=roles/iam.workloadIdentityUser \
  --member="principalSet://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/attribute.repository/YOUR_GITHUB_ORG/mlsa-k8s"
11.4 Secret Manager — Không hardcode secrets
# Tạo secret trên GCP Secret Manager
echo -n "my-db-password" | gcloud secrets create db-password \
  --data-file=- --project=$PROJECT

# Đọc trong ứng dụng qua Workload Identity (không cần SA key)
# Kubernetes ExternalSecret (cần cài external-secrets operator)
# kubernetes/apps/demo-app/external-secret.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: demo-app-secrets
  namespace: production
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: gcp-secret-store
    kind: ClusterSecretStore
  target:
    name: demo-app-secret        # Kubernetes Secret được tạo tự động
  data:
    - secretKey: db-password
      remoteRef:
        key: db-password         # Tên secret trên GCP Secret Manager
11.5 Cost Management
# Tạo Budget Alert — cảnh báo khi đạt 80% budget
gcloud billing budgets create \
  --billing-account=$BILLING_ACCOUNT \
  --display-name="MLSA-K8S Budget" \
  --budget-amount=200USD \
  --threshold-rules=percent=0.5,basis=CURRENT_SPEND \
  --threshold-rules=percent=0.8,basis=CURRENT_SPEND \
  --threshold-rules=percent=1.0,basis=CURRENT_SPEND \
  --notifications-rule-monitoring-notification-channels=$NOTIFICATION_CHANNEL
Label resources để track chi phí theo layer:

# Đã có trong node_pools.tf — labels cho từng pool
node_config {
  labels = {
    "cost-center" = "capstone-c2ne03"
    "dedicated"   = "system"          # hoặc workload-type = application/evaluation
  }
}
11.6 Alerting — Grafana + Slack (Monitoring thực tế)
# kubernetes/L7-observability/grafana/alerting/slack-alert.yaml
# Thêm vào Grafana helm-values.yaml:
grafana:
  alerting:
    contactpoints.yaml:
      apiVersion: 1
      contactPoints:
        - name: slack-security
          receivers:
            - uid: slack-receiver
              type: slack
              settings:
                url: $SLACK_WEBHOOK_URL
                channel: "#mlsa-k8s-alerts"
                title: "🚨 Security Alert: {{ .CommonLabels.alertname }}"
                text: |
                  Cluster: {{ .CommonLabels.cluster }}
                  Namespace: {{ .CommonLabels.namespace }}
                  Severity: {{ .CommonLabels.severity }}
11.7 Hành vi Claude khi làm Enterprise features
Khi viết GitHub Actions:

Luôn dùng Workload Identity Federation thay vì SA key JSON
Luôn pin action versions: actions/checkout@v4 (không dùng @latest)
Luôn có environment: block để require manual approval cho production
Staging phải pass trước (needs: deploy-staging) mới deploy production
Khi viết IAM:

Luôn dùng principle of least privilege — chỉ grant quyền tối thiểu cần thiết
CI/CD SA chỉ có roles/container.developer, không có roles/container.admin
Không bao giờ dùng roles/owner hoặc roles/editor cho SA
Khi viết Secret:

Không bao giờ hardcode secrets trong YAML hoặc Terraform
Luôn dùng GCP Secret Manager + External Secrets Operator
Không bao giờ commit .env file có giá trị thật
Thứ tự deploy Enterprise:

1. Merge PR vào main (require 1 reviewer)
2. GitHub Actions tự động: Trivy scan + Terraform plan
3. Auto deploy staging
4. Smoke test staging pass
5. Manual approval trên GitHub (Team Lead click Approve)
6. Auto deploy production
7. Verify production health
GitOps nâng cao (optional): Nếu muốn deploy hoàn toàn tự động không cần CI/CD push, cài ArgoCD: kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml ArgoCD sẽ watch Git repo và tự sync mọi thay đổi vào cluster — không ai cần chạy kubectl tay.

Version 4.0 — Production-Ready Final · February 2026 · MLSA-K8S Capstone C2NE.03

