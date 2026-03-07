#!/bin/bash
# CIS Kubernetes Benchmark validation
# Run this to check security posture against CIS Benchmark

echo "🔍 Running CIS Kubernetes Benchmark checks..."

# Check Kubernetes version
echo "📌 Kubernetes Version:"
kubectl version --short

# Check API server flags
echo "📌 API Server Security Flags:"
gcloud container clusters describe mlsa-k8s-cluster --region asia-southeast1 --format="value(masterAuth)"

# Check RBAC
echo "📌 RBAC Role Bindings:"
kubectl get clusterrolebindings -o wide | grep -v "system:" | head -10

# Check Network Policies
echo "📌 Network Policies Active:"
kubectl get networkpolicies -A

# Check Pod Security Policies (if using older K8s)
echo "📌 Pod Security Admission Labels:"
kubectl get namespaces -L pod-security.kubernetes.io/enforce

# Check RBAC for service accounts
echo "📌 Service Accounts with Elevated Privileges:"
kubectl get clusterrolebindings -o json | jq '.items[] | select(.roleRef.name | IN("cluster-admin", "edit", "admin")) | .subjects[] | select(.kind=="ServiceAccount")'

# Check audit logging
echo "📌 Audit Logging Status:"
kubectl get pods -n kube-system -l component=kube-apiserver

echo "✅ CIS Benchmark validation complete!"
echo "📚 See https://www.cisecurity.org/cis-benchmarks/ for full benchmark details"
