# MLSA-K8S Architecture Overview

## 7-Layer Security Model

```
┌───────────────────────────────────────────────────────── ┐
│              APPLICATION (Demo App)                      │
├───────────────────────────────────────────────────────── ┤
│ L7: Observability & Exposure                             │
│     • NGINX Ingress Controller + TLS                     │
│     • Prometheus metrics scraping                        │
│     • Grafana dashboards                                 │
│     • Loki log aggregation                               │
├───────────────────────────────────────────────────────── ┤
│ L6: Workload & Runtime Protection                        │
│     • Pod Security Admission (PSA) - restricted mode     │
│     • seccomp profiles                                   │
│     • AppArmor (if available)                            │
│     • Falco runtime monitoring                           │
├───────────────────────────────────────────────────────── ┤
│ L5: Supply Chain Security                                │
│     • Binary Authorization (image verification)          │
│     • Trivy vulnerability scanning                       │
│     • Cosign image signing (optional)                    │
│     • Container Registry (GCR)                           │
├───────────────────────────────────────────────────────── ┤
│ L4: Network Segmentation                                 │
│     • NetworkPolicy: default deny-all                    │
│     • Namespace isolation                                │
│     • Calico network plugin                              │
│     • Service-to-service mTLS (Istio)                    │
├───────────────────────────────────────────────────────── ┤
│ L3: Identity & Secrets Management                        │
│     • Workload Identity (KSA ↔ GSA binding)              │
│     • cert-manager for certificate rotation              │
│     • Istio mutual TLS (mTLS) in STRICT mode             │
│     • Secret encryption at rest                          │
├───────────────────────────────────────────────────────── ┤
│ L2: Control Plane Security                               │
│     • RBAC: Role-based access control                    │
│     • OPA/Gatekeeper admission policies                  │
│     • Kubernetes audit logging                           │
│     • Webhook access control                             │
├───────────────────────────────────────────────────────── ┤
│ L1: Infrastructure Security                              │
│     • CIS Benchmark compliance                           │
│     • Shielded GKE nodes                                 │
│     • Node hardening                                     │
│     • Secure Boot + Integrity Monitoring                 │
├───────────────────────────────────────────────────────── ┤
│              KUBERNETES CONTROL PLANE (Managed)          │
│              Kubernetes API Server, etcd, etc.           │
├───────────────────────────────────────────────────────── ┤
│              GOOGLE CLOUD INFRASTRUCTURE (L0)            │
│              VPC, IAM, Cloud Logging, Cloud Monitoring   │
└───────────────────────────────────────────────────────── ┘
```

## GKE Cluster Architecture

```
GCP Project: mlsa-k8s-capstone
Region: asia-southeast1 (Singapore)

┌──────────────────────────────────────────────────────────────────┐
│             GKE CLUSTER: mlsa-k8s-cluster (REGIONAL)             │
│                      Kubernetes 1.29+                             │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │          CONTROL PLANE (Managed by Google)               │    │
│  │          • Kubernetes API Server                         │    │
│  │          • Scheduler                                     │    │
│  │          • Controller Manager                            │    │
│  │          • etcd (encrypted)                              │    │
│  │          • Cloud Logging integration                     │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                   │
│  ┌──────────────────────┬──────────────────────┬────────────┐   │
│  │   System Node Pool   │  Workload Node Pool  │  Eval Pool │   │
│  │   (dedicated)        │                      │ (optional) │   │
│  │                      │                      │            │   │
│  │  ┌────────────────┐  │  ┌────────────────┐  │  ┌──────┐  │   │
│  │  │  Node-1        │  │  │  Node-3        │  │  │Node-5│  │   │
│  │  │ e2-standard-2  │  │  │ e2-standard-2  │  │  │ (pre)│  │   │
│  │  │  2vCPU, 8GB    │  │  │  2vCPU, 8GB    │  │  │      │  │   │
│  │  └────────────────┘  │  └────────────────┘  │  └──────┘  │   │
│  │        ⬆ Tainted     │         ⬆ Free       │  ⬆ Scales  │   │
│  │        system pods   │         Application  │   down     │   │
│  │                      │                      │            │   │
│  │  ┌────────────────┐  │  ┌────────────────┐  │            │   │
│  │  │  Node-2        │  │  │  Node-4        │  │            │   │
│  │  │ e2-standard-2  │  │  │ e2-standard-2  │  │            │   │
│  │  │  2vCPU, 8GB    │  │  │  2vCPU, 8GB    │  │            │   │
│  │  └────────────────┘  │  └────────────────┘  │            │   │
│  │                      │                      │            │   │
│  └──────────────────────┴──────────────────────┴────────────┘   │
│                                                                   │
│  Pods Running:                                                    │
│  • kube-system: coreDNS, kube-proxy, network-policy-controller  │
│  • cert-manager: webhook, controller                             │
│  • gatekeeper: audit, controller                                 │
│  • istio-system: ingressgateway, egressgateway, pilot           │
│  • monitoring: prometheus, grafana, loki                         │
│  • production: demo-app (2 replicas)                             │
│  • staging: baseline-app (1 replica)                             │
│  • falco: runtime monitoring daemon                              │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
                              ⬇ Network
┌──────────────────────────────────────────────────────────────────┐
│                      VPC: mlsa-k8s-vpc                           │
│                  10.0.0.0/8 (CIDR range)                         │
│                                                                   │
│  Subnet: mlsa-k8s-subnet                                         │
│  Primary: 10.0.0.0/20 (Nodes)                                    │
│  Secondary:                                                       │
│    • Pods: 10.4.0.0/14 (256K IPs for Pods)                       │
│    • Services: 10.0.0.0/20 (4K IPs for Services)                 │
│                                                                   │
│  Firewalls:                                                       │
│    • Allow SSH (22/tcp)                                          │
│    • Allow API access (443/tcp)                                  │
│    • Allow health checks (35.191.0.0/16, 130.211.0.0/22)        │
│                                                                   │
│  Cloud NAT:                                                       │
│    • Egress traffic masqueraded through NAT IP                   │
│    • Logging enabled                                              │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
                              ⬇ Observability
┌──────────────────────────────────────────────────────────────────┐
│                  Google Cloud Logging & Monitoring                │
│                                                                   │
│  • Kubernetes cluster logs (API server, kubelet)                 │
│  • Pod logs (via Stackdriver adapter)                            │
│  • System metrics (CPU, memory, network)                         │
│  • Custom metrics (Prometheus scrapes)                           │
│  • Cloud Trace for distributed tracing                           │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

## Data Flow: Request to Application

```
┌──────────────────┐
│  External User   │
│  (Internet)      │
└────────┬─────────┘
         │ HTTPS
         ⬇
┌──────────────────────────────────────┐
│   NGINX Ingress Controller (L7)      │
│   • TLS Termination (cert-manager)   │
│   • DDoS mitigation (optional)       │
│   • Rate limiting                    │
└────────┬─────────────────────────────┘
         │ HTTP (internal mTLS)
         ⬇
┌──────────────────────────────────────┐
│   Istio Ingress Gateway (L3)         │
│   • mTLS enforcement (STRICT)        │
│   • Authorization policies           │
│   • Circuit breaking                 │
└────────┬─────────────────────────────┘
         │ Service-to-Service (mTLS)
         ⬇
┌──────────────────────────────────────┐
│  NetworkPolicy Check (L4)            │
│  • Namespace isolation               │
│  • Port-level rules                  │
└────────┬─────────────────────────────┘
         │
         ⬇
┌──────────────────────────────────────┐
│  Pod: demo-app                       │
│  • Running as non-root (UID 1000)    │
│  • Read-only root filesystem         │
│  • No unsafe capabilities            │
│  • seccomp profile applied           │
└──────────────────────────────────────┘
         │
         ⬇
┌──────────────────────────────────────┐
│  Falco Runtime Monitoring (L6)       │
│  • Detect suspicious syscalls        │
│  • Alert on policy violations        │
└──────────────────────────────────────┘
         │
         ⬇
┌──────────────────────────────────────┐
│  Cloud Logging & Monitoring (L7)     │
│  • Log centralization                │
│  • Metrics collection (Prometheus)   │
│  • Dashboard visualization           │
└──────────────────────────────────────┘
```

## Security Policy Enforcement Chain

```
Admission Control Pipeline:
┌─────────┐
│ Request │
└────┬────┘
     │
     ⬇
┌──────────────────────────┐
│ Authentication (GKE KSA) │  ← Workload Identity validated
└────┬─────────────────────┘
     │
     ⬇
┌──────────────────────────┐
│ RBAC (L2)                │  ← Service account permissions checked
└────┬─────────────────────┘
     │
     ⬇
┌──────────────────────────┐
│ MutatingWebhooks (L3)    │  ← cert-manager, Istio inject
└────┬─────────────────────┘
     │
     ⬇
┌──────────────────────────┐
│ Pod Security Admission   │  ← PSA restricted mode enforced (L6)
│ (L6)                     │
└────┬─────────────────────┘
     │
     ⬇
┌──────────────────────────┐
│ ValidatingWebhooks (L2)  │  ← OPA Gatekeeper policies
│ OPA Gatekeeper           │
│ Constraints:             │
│  - require-resource-limits
│  - deny-privileged-containers
│  - require-non-root
│  - deny-host-namespace
│  - require-allowed-repos
└────┬─────────────────────┘
     │
     ⬇
┌──────────────────────────┐
│ Binary Authorization     │  ← Image signature verification (L5)
│ (GKE built-in)           │
└────┬─────────────────────┘
     │
     ⬇
┌──────────────────────────┐
│ Audit Log (L2)           │  ← Request logged to Cloud Logging
└────┬─────────────────────┘
     │
     ⬇
┌──────────────────────────┐
│ ACCEPTED & CREATED       │
└──────────────────────────┘
```

## Technology Stack

| Layer | Component | Purpose | Version |
|-------|-----------|---------|---------|
| L1 | GKE Shielded Nodes | Node security | Latest |
| L2 | OPA Gatekeeper | Policy enforcement | v3.13+ |
| L2 | Kubernetes RBAC | Access control | Built-in |
| L3 | cert-manager | Certificate management | v1.13+ |
| L3 | Istio | Service mesh & mTLS | v1.18+ |
| L4 | Calico | Network policies | Built-in |
| L5 | Binary Authorization | Image verification | GKE built-in |
| L5 | Trivy | Vulnerability scanning | v0.45+ |
| L6 | PSA | Pod security | Built-in |
| L6 | Falco | Runtime monitoring | v0.36+ |
| L7 | NGINX Ingress | Reverse proxy | v1.8+ |
| L7 | Prometheus | Metrics collection | v2.45+ |
| L7 | Grafana | Visualization | v10+ |
| L7 | Loki | Log aggregation | v2.8+ |

## Cost Structure

**Monthly Estimate (asia-southeast1):**

| Component | Cost |
|-----------|------|
| System pool (2 nodes) | $48 |
| Workload pool (2 nodes) | $48 |
| Evaluation pool (1 node, 4h/day) | $8 |
| Persistent Storage (100GB SSD) | $17 |
| Container Registry (5GB) | $3 |
| Cloud Logging | $5 |
| Cloud Monitoring | $3 |
| Network egress | $3 |
| **Total** | **$135** |

**Savings:**
- GCP Free Credit ($300): ~2.3 months free
- Evaluation pool pause during off-hours: ~$8/month
- Automatic node scaling: +2-5% variance

See [README.md](../README.md) for more details.
