# DESIGN AND IMPLEMENTATION OF A DEFENSE-IN-DEPTH 
SECURITY ARCHITECTURE FOR KUBERNETES 
ENVIRONMENTS 

Capstone Project 2 | CMU-CS 451 | International School, Duy Tan University  
Team C2NE.03 | Supervisor: Eng. Binh, Van Nguyen

## Quick Start

### Prerequisites
```bash
# Install required tools
brew install kubectl helm terraform cosign trivy
# Or on Windows with Chocolatey:
# choco install kubernetes-cli helm terraform cosign trivy

# Authenticate with Google Cloud
gcloud auth login
gcloud config set project mlsa-k8s-capstone
```

### Setup (4 Steps)

```bash
# 1. Provision GKE Cluster
cd infrastructure/terraform
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# 2. Get kubeconfig credentials
gcloud container clusters get-credentials mlsa-k8s-cluster \
  --zone asia-southeast1-b \
  --project mlsa-k8s-capstone

# 3. Bootstrap cluster
bash ../scripts/bootstrap.sh

# 4. Deploy security layers
make deploy-all
```

## Architecture

7 Security Layers:

| Layer | Name | Tools |
|---|---|---|
| L1 | Infrastructure Security | CIS Benchmark, containerd |
| L2 | Control Plane Security | RBAC, OPA/Gatekeeper, Audit Logging |
| L3 | Identity & Secrets | Workload Identity, cert-manager, mTLS (Istio) |
| L4 | Network Segmentation | NetworkPolicy (Calico), namespace isolation |
| L5 | Supply Chain Security | Trivy, Cosign, Binary Authorization |
| L6 | Workload & Runtime | PSA, seccomp, AppArmor, Falco |
| L7 | Application Exposure | NGINX Ingress + TLS, Loki, Prometheus, Grafana |

## Directory Structure

```
mlsa-k8s/
├── CLAUDE.md                          # Full project specification
├── README.md
├── .env.example
├── Makefile
├── infrastructure/
│   ├── terraform/
│   │   ├── main.tf                    # GKE cluster definition + node pools
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── vpc.tf
│   │   └── iam.tf
│   └── scripts/
│       ├── bootstrap.sh               # Post-cluster setup
│       └── validate-cis.sh
├── kubernetes/
│   ├── namespaces/
│   ├── L2-control-plane/              # RBAC, admission control, audit
│   ├── L3-identity/                   # Workload Identity, cert-manager, Istio mTLS
│   ├── L4-network/                    # NetworkPolicy
│   ├── L5-supply-chain/               # Binary Authorization, Trivy
│   ├── L6-workload/                   # PSA, seccomp, Falco
│   ├── L7-observability/              # Ingress, Prometheus, Loki, Grafana
│   └── apps/                          # Demo apps
├── evaluation/
│   ├── scenarios/                     # Attack simulation scripts
│   └── results/
└── docs/
```

## Common Commands

```bash
make init              # Initialize Terraform
make deploy-all        # Deploy entire stack
make evaluate          # Run attack scenarios
make pause-eval        # Pause evaluation pool (cost saving)
make clean            # Delete cluster (CAUTION!)

# Verify deployments
kubectl get pods -A
kubectl get networkpolicies -A
kubectl logs -n falco -l app=falco --tail=50
```

## Cost Estimation

**Monthly estimate (asia-southeast1)**: ~$132
- System pool (2x e2-standard-2): ~$48
- Workload pool (2x e2-standard-2): ~$48
- Evaluation pool (1x e2-standard-2, 4h/day): ~$8
- Storage, networking, monitoring: ~$28

**Optimize costs**:
- Use GCP Free Credit ($300 for new accounts) = ~2.3 months free
- Pause evaluation pool when not in use: `make pause-eval`
- Scale down nodes during inactive periods

## Deployment Steps

See [deployment-guide.md](docs/deployment-guide.md) for detailed walkthrough.

## Evaluation

Run controlled attack scenarios against both secured and baseline clusters:

```bash
bash evaluation/scenarios/S1-privileged-pod-escape.sh
bash evaluation/scenarios/S2-rbac-privilege-escalation.sh
bash evaluation/scenarios/S3-lateral-movement.sh
bash evaluation/scenarios/S4-supply-chain-injection.sh
bash evaluation/scenarios/S5-secrets-exfiltration.sh
```

Results saved to `evaluation/results/`

## Team Assignment

- **Huynh Chi Trung**: L2 Control Plane + Architecture
- **Truong Tran Manh**: L3 Identity + L4 Network + L6 Workload
- **Nguyen Hoang Son**: L1 Infrastructure + L5 Supply Chain + L7 Observability

## License

Educational use only - CMU Capstone Project 2025-2026

