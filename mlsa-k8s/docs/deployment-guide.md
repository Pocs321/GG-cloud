# MLSA-K8S Deployment Guide

## Prerequisites

### 1. Install Required Tools

**macOS (Homebrew):**
```bash
brew install kubectl helm terraform gcloud-sdk cosign trivy
```

**Windows (Chocolatey):**
```bash
choco install kubernetes-cli helm terraform gcloud-sdk
# For cosign and trivy, download from GitHub or use WSL
```

**Manual Installation:**
- **kubectl**: https://kubernetes.io/docs/tasks/tools/
- **Helm**: https://helm.sh/docs/intro/install/
- **Terraform**: https://www.terraform.io/downloads
- **gcloud CLI**: https://cloud.google.com/sdk/docs/install

### 2. Google Cloud Setup

```bash
# Authenticate with GCP
gcloud auth login

# Create a new project (or use existing)
gcloud projects create mlsa-k8s-capstone --name="MLSA K8S Capstone"

# Set project configuration
gcloud config set project mlsa-k8s-capstone
gcloud config set compute/region asia-southeast1
gcloud config set compute/zone asia-southeast1-a

# Enable required APIs
gcloud services enable \
  container.googleapis.com \
  compute.googleapis.com \
  iam.googleapis.com \
  cloudlogging.googleapis.com \
  cloudtrace.googleapis.com
```

### 3. Create GCS Bucket for Terraform State

```bash
gsutil mb gs://mlsa-k8s-tfstate
```

---

## Step 1: Initialize Terraform

```bash
cd infrastructure/terraform
terraform init

# Verify Terraform is ready
terraform version
```

---

## Step 2: Review and Plan Deployment

```bash
# Create deployment plan
terraform plan -out=tfplan

# Review the plan (shows what will be created)
```

**Expected resources:**
- 1x GKE Regional Cluster
- 3x Node Pools (system, workload, evaluation)
- 1x VPC Network
- 1x Subnet (with secondary IP ranges for Pods & Services)
- Cloud NAT for egress

---

## Step 3: Create GKE Cluster

```bash
# Apply Terraform configuration
terraform apply tfplan

# This will take ~10-15 minutes

# Get cluster credentials
gcloud container clusters get-credentials mlsa-k8s-cluster \
  --region asia-southeast1
```

**Verify cluster connectivity:**
```bash
kubectl cluster-info
kubectl get nodes
```

---

## Step 4: Bootstrap Security Components

```bash
# Run bootstrap script to install:
# - Namespaces
# - Cert-Manager
# - OPA Gatekeeper
# - Istio (optional)

bash infrastructure/scripts/bootstrap.sh

# Wait for all system pods to be ready
kubectl wait --for=condition=Ready pod \
  -l app=gatekeeper \
  --namespace gatekeeper \
  --timeout=300s
```

---

## Step 5: Deploy Security Layers

### Deploy Each Layer in Order:

```bash
# L2: Control Plane (RBAC + Admission Control)
kubectl apply -f kubernetes/L2-control-plane/rbac/
kubectl apply -f kubernetes/L2-control-plane/admission/

# Wait for Gatekeeper to be ready
sleep 10

# L3: Identity & Secrets (Istio, cert-manager)
kubectl apply -f kubernetes/L3-identity/

# L4: Network Segmentation (NetworkPolicies)
kubectl apply -f kubernetes/L4-network/

# L5: Supply Chain Security (Binary Authorization, Trivy)
kubectl apply -f kubernetes/L5-supply-chain/

# L6: Workload Protection (PSA, seccomp, Falco)
kubectl apply -f kubernetes/L6-workload/

# L7: Observability (Ingress, Prometheus, Loki, Grafana)
kubectl apply -f kubernetes/L7-observability/

# Deploy demo applications
kubectl apply -f kubernetes/apps/demo-app.yaml
kubectl apply -f kubernetes/apps/baseline-app.yaml
```

Or use the convenience command:
```bash
make deploy-all
```

---

## Step 6: Verify Deployment

### Check all pods are running:
```bash
kubectl get pods -A

# Expected namespaces:
# - kube-system (Kubernetes components)
# - gatekeeper (OPA Gatekeeper)
# - cert-manager (Certificate management)
# - istio-system (Istio service mesh)
# - monitoring (Prometheus, Grafana, Loki)
# - production (demo-app)
# - staging (baseline-app)
```

### Verify security policies:
```bash
# Check Gatekeeper policies
kubectl get constraintviolations -A

# Check NetworkPolicies
kubectl get networkpolicies -A

# Check RBAC
kubectl get rolebindings -A
kubectl get clusterrolebindings | grep -v system
```

### Test NetworkPolicy enforcement:
```bash
# Create test pods in different namespaces
kubectl run test-prod -n production --image=alpine:latest -- sleep 3600
kubectl run test-staging -n staging --image=alpine:latest -- sleep 3600

# Try to connect across namespaces (should fail)
kubectl exec -n staging test-staging -- wget http://test-prod.production.svc.cluster.local

# Expected: Connection refused or timeout
```

---

## Step 7: Run Security Evaluation

### Simulate attack scenarios:

```bash
# S1: Try to deploy privileged container
bash evaluation/scenarios/S1-privileged-pod-escape.sh

# S2: Test RBAC restrictions
bash evaluation/scenarios/S2-rbac-privilege-escalation.sh

# S3: Test lateral movement prevention
bash evaluation/scenarios/S3-lateral-movement.sh

# Run all scenarios
make evaluate
```

**Results saved to:** `evaluation/results/`

---

## Monitoring & Logging

### View demo app logs:
```bash
kubectl logs -n production -l app=demo-app --tail=50 -f
```

### Check Gatekeeper logs:
```bash
kubectl logs -n gatekeeper -l app=gatekeeper --tail=50
```

### View security events:
```bash
# Kubernetes audit logs (if enabled)
gcloud logging read "resource.type=k8s_cluster" --limit 50 --format json

# Cloud Logging
gcloud logging read \
  --filter='resource.type="k8s_pod"' \
  --limit 50 \
  --format json
```

---

## Cost Optimization

### Pause evaluation pool when not in use:
```bash
# Stop evaluation node pool (saves ~$0.15/hour)
make pause-eval

# Resume when needed
make resume-eval
```

### Scale down cluster for extended breaks:
```bash
# Scale to zero (only API master remains)
gcloud container clusters resize mlsa-k8s-cluster \
  --node-pool system-pool \
  --num-nodes=0 \
  --region asia-southeast1
```

---

## Troubleshooting

### Pods stuck in Pending state:
```bash
# Check pod events
kubectl describe pod <pod-name> -n <namespace>

# Check node availability
kubectl get nodes
```

### Gatekeeper not blocking policies:
```bash
# Check Gatekeeper is running
kubectl get pods -n gatekeeper

# Check constraint violations
kubectl get constraintviolations -A

# Describe a violation
kubectl describe constraintviolation <name> -n <namespace>
```

### No ingress traffic:
```bash
# Check Ingress controller
kubectl get ingress -A

# Check NGINX controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
```

---

## Cleanup (Deletation)

### Delete the entire cluster:
```bash
make clean
# Or manually:
cd infrastructure/terraform
terraform destroy
```

**⚠️ WARNING: This will delete all resources and data!**

---

## Next Steps

1. **Customize RBAC**: Modify `kubernetes/L2-control-plane/rbac/` for your team
2. **Setup Ingress**: Configure DNS and TLS certificates
3. **Enable monitoring**: Deploy Prometheus, Grafana, Loki
4. **Implement GitOps**: Use ArgoCD or Flux for continuous deployment
5. **Document threat model**: See [threat-model.md](threat-model.md)

---

## Support & Team

- **Issues/Questions**: Check [README.md](../README.md)
- **Project**: MLSA-K8S Capstone (CMU-CS 451)
- **Team**: C2NE.03 | Duy Tan University
- **Supervisor**: Eng. Binh, Van Nguyen
