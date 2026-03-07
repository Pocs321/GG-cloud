.PHONY: setup bootstrap deploy-l1 deploy-l2 deploy-l3 deploy-l4 \
        deploy-l5 deploy-l6 deploy-l7 deploy-app deploy-all \
        verify evaluate pause resume clean

# ── Khởi tạo ──────────────────────────────────────────────────────────
setup:
	bash infrastructure/terraform/scripts/create-tfstate-bucket.sh
	cd infrastructure/terraform && terraform init
	cd infrastructure/terraform && \
	  terraform apply -var="admin_cidr=$$(curl -s ifconfig.me)/32" -auto-approve
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
	  --set installCRDs=true --wait --timeout=5m
	istioctl install --set profile=default -y
	kubectl label namespace production istio-injection=enabled --overwrite
	kubectl label namespace staging istio-injection=enabled --overwrite
	helm install gatekeeper gatekeeper/gatekeeper \
	  --namespace gatekeeper-system --create-namespace --wait --timeout=5m

# ── Deploy layers ─────────────────────────────────────────────────────
deploy-l1:
	kubectl apply -f kubernetes/L1-infrastructure/ --recursive

deploy-l2:
	kubectl apply -f kubernetes/L2-control-plane/rbac/ --recursive
	kubectl wait --for=condition=Ready pod \
	  -l control-plane=controller-manager \
	  -n gatekeeper-system --timeout=180s
	kubectl apply -f kubernetes/L2-control-plane/gatekeeper-policies/ --recursive

deploy-l3:
	kubectl apply -f kubernetes/L3-identity/workload-identity/ --recursive
	kubectl apply -f kubernetes/L3-identity/cert-manager/      --recursive
	kubectl apply -f kubernetes/L3-identity/istio/             --recursive

deploy-l4:
	kubectl apply -f kubernetes/L4-network/default-deny-all-production.yaml
	kubectl apply -f kubernetes/L4-network/default-deny-all-staging.yaml
	kubectl apply -f kubernetes/L4-network/allow-dns-egress.yaml
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
	  --namespace ingress-nginx --create-namespace --wait --timeout=5m
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

# ── Verify & Evaluate ─────────────────────────────────────────────────
verify:
	kubectl auth can-i create pods \
	  --as=system:serviceaccount:production:default -n production
	kubectl get peerauthentication -A
	kubectl get constraintviolations -A
	kubectl get pods -A | grep -v Running | grep -v Completed

evaluate:
	bash evaluation/scenarios/run-scenario.sh S1
	bash evaluation/scenarios/run-scenario.sh S2
	bash evaluation/scenarios/run-scenario.sh S3
	bash evaluation/scenarios/run-scenario.sh S4
	bash evaluation/scenarios/run-scenario.sh S5
	bash evaluation/compare-baseline.sh

# ── Quản lý chi phí ───────────────────────────────────────────────────
pause:
	@echo "Tắt nodes để tiết kiệm chi phí..."
	gcloud container clusters resize mlsa-k8s-cluster \
	  --node-pool system-pool --num-nodes=0 \
	  --zone asia-southeast1-b --quiet
	gcloud container clusters resize mlsa-k8s-cluster \
	  --node-pool workload-pool --num-nodes=0 \
	  --zone asia-southeast1-b --quiet
	@echo "✅ Nodes đã tắt. Dùng 'make resume' để bật lại."

resume:
	@echo "Bật nodes..."
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
