#!/bin/bash
# Bootstrap GKE cluster with security components via Helm
# Run this after: terraform apply + kubectl authentication setup

set -e

PROJECT_ID=${PROJECT_ID:-mlsa-k8s-capstone}
CLUSTER_NAME=${CLUSTER_NAME:-mlsa-k8s-cluster}
ZONE=${ZONE:-asia-southeast1-b}

echo "🔧 Bootstrapping MLSA-K8S cluster: $CLUSTER_NAME"
echo "Zone: $ZONE"
echo ""

# Verify kubectl connectivity
echo "✅ Testing cluster connection..."
kubectl cluster-info || { echo "❌ Not connected to cluster"; exit 1; }
echo ""

# Create namespaces (from kubernetes/namespaces/)
echo "📦 Creating namespaces..."
kubectl apply -f kubernetes/namespaces/ || echo "Namespaces already exist"
echo ""

# Add Helm repositories (all in one batch per CLAUDE.md section 5)
echo "📚 Adding Helm repositories..."
helm repo add jetstack https://charts.jetstack.io
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo add aqua https://aquasecurity.github.io/helm-charts/
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
echo "✅ Helm repos updated"
echo ""

# Install cert-manager (L3 prerequisite - must install BEFORE Istio)
echo "🔐 Installing cert-manager..."
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true \
  --wait \
  --timeout=5m
echo "✅ cert-manager installed"
echo ""

# Install Istio using istioctl (per CLAUDE.md - NOT helm)
echo "🔗 Installing Istio via istioctl..."
if ! command -v istioctl &> /dev/null; then
  echo "⚠️  istioctl not found. Download from https://istio.io/latest/docs/setup/getting-started/"
  echo "Then add to PATH and run: istioctl install --set profile=default -y"
else
  istioctl install --set profile=default -y
  kubectl label namespace production istio-injection=enabled --overwrite
  kubectl label namespace staging istio-injection=enabled --overwrite
  echo "✅ Istio installed with mTLS injection enabled"
fi
echo ""

# Install OPA Gatekeeper (L2 prerequisite - must install BEFORE applying policies)
echo "🚪 Installing OPA Gatekeeper..."
helm install gatekeeper gatekeeper/gatekeeper \
  --namespace gatekeeper-system \
  --create-namespace \
  --wait \
  --timeout=5m
echo "✅ Gatekeeper installed, waiting for webhook..."
kubectl wait --for=condition=Ready pod \
  -l control-plane=controller-manager \
  -n gatekeeper-system \
  --timeout=180s
echo ""

echo "✅ Bootstrap complete!"
echo ""
echo "Next steps:"
echo "  1. Deploy Kubernetes manifests: make deploy-all"
echo "  2. Verify cluster: make verify"
echo "  3. Run evaluation: make evaluate"
echo ""

