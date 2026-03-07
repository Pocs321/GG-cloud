# MLSA-K8S Project Checklist

## Pre-Deployment

- [ ] GCP account created and free credit applied
- [ ] gcloud CLI installed and authenticated
- [ ] kubectl installed (`gcloud components install gke-gcloud-auth-plugin`)
- [ ] Terraform installed (v1.6.0+)
- [ ] Helm installed
- [ ] Trivy installed for image scanning
- [ ] GSutil configured for state management
- [ ] Project variables in `.env` configured

## Infrastructure Setup

- [ ] GCS bucket created: `mlsa-k8s-tfstate`
- [ ] Terraform initialized: `make init`
- [ ] Terraform plan reviewed: `make plan`
- [ ] GKE cluster deployed: `make apply`
- [ ] Cluster credentials configured: `gcloud container clusters get-credentials kluster`
- [ ] Cluster connectivity verified: `kubectl cluster-info`
- [ ] Node pools visible: `kubectl get nodes`

## Cluster Bootstrap

- [ ] Namespaces created
- [ ] Pod Security Admission labels applied
- [ ] Cert-manager installed and ready
- [ ] OPA Gatekeeper installed and ready
- [ ] Istio installed (optional)
- [ ] System pods in kube-system namespace running

## Security Layer Deployment

### L2: Control Plane
- [ ] RBAC bindings applied
- [ ] Service accounts created
- [ ] Gatekeeper constraints deployed
- [ ] Audit logging enabled
- [ ] Constraint violations checked

### L3: Identity
- [ ] cert-manager ClusterIssuers configured
- [ ] Istio mTLS policies applied
- [ ] PeerAuthentication set to STRICT
- [ ] Workload Identity annotations added to pods

### L4: Network
- [ ] NetworkPolicy default-deny applied to all namespaces
- [ ] Allow rules for monitoring traffic
- [ ] Namespace isolation tested
- [ ] Cross-namespace traffic blocked

### L5: Supply Chain
- [ ] Binary Authorization enabled
- [ ] Trivy scanning configured
- [ ] Image attestation process documented

### L6: Workload Protection
- [ ] Pod Security Admission enforced
- [ ] seccomp profiles applied
- [ ] Falco rules deployed
- [ ] Runtime monitoring working

### L7: Observability
- [ ] Ingress controller deployed
- [ ] Prometheus metrics scraping
- [ ] Grafana dashboards accessible
- [ ] Loki log aggregation working

## Application Deployment

- [ ] Demo app deployed successfully
  - [ ] Replicas running (check with `kubectl get pods -n production`)
  - [ ] Service accessible (`kubectl get svc -n production`)
  - [ ] Readiness/liveness probes passing
  - [ ] Resource limits enforced
  - [ ] Non-root user running
  - [ ] Read-only filesystem configured

- [ ] Baseline app deployed in staging (for comparison)
  - [ ] Deployment created
  - [ ] Pod running (potentially with violations)

## Evaluation Testing

- [ ] S1: Privileged pod escape blocked
  - [ ] Gatekeeper constraint violations exist
  - [ ] Pod fails to create
  - [ ] PSA rejects privileged containers

- [ ] S2: RBAC privilege escalation contained
  - [ ] Service accounts have minimal permissions
  - [ ] Default service account restricted
  - [ ] No suspicious RBAC bindings

- [ ] S3: Lateral movement prevented
  - [ ] Cross-namespace traffic denied
  - [ ] NetworkPolicies block inter-pod communication
  - [ ] Istio mTLS enforced

## Documentation

- [ ] CLAUDE.md reviewed
- [ ] README.md updated with team info
- [ ] deployment-guide.md followed
- [ ] architecture.md reviewed for understanding
- [ ] threat-model.md analyzed for risks
- [ ] Team aware of their layer assignments

## Cost Management

- [ ] Monthly budget understood (~$135/month)
- [ ] Free credit amount tracked
- [ ] Evaluation pool scaled down when not in use
- [ ] Cost alerts set up in GCP console (optional)
- [ ] Shut-down procedure documented

## Post-Deployment Verification

- [ ] Run `kubectl get pods -A` - all system pods running
- [ ] Run `kubectl get networkpolicies -A` - policies applied
- [ ] Run `kubectl get constraintviolations -A` - gatekeeper active
- [ ] Check logs: `kubectl logs -n gatekeeper -l app=gatekeeper`
- [ ] Verify ingress: `kubectl get ingress -A`
- [ ] Test connectivity: `kubectl exec -n production <pod> -- curl <service>`

## Team Handoff

- [ ] Code repositories configured
- [ ] GitHub Actions workflows tested
- [ ] Team members have access to GCP project
- [ ] Incident response contacts documented
- [ ] On-call rotation established
- [ ] Documentation shared with team

## Ongoing Maintenance

- [ ] Set up GKE cluster auto-upgrades
- [ ] Enable node pool auto-repair
- [ ] Configure backup strategy
- [ ] Monitor cluster costs monthly
- [ ] Review audit logs weekly
- [ ] Update security policies as threats evolve

## Closure (End of Capstone)

- [ ] Lessons learned documented
- [ ] Recommendations for production implementation noted
- [ ] Cluster destruction procedure verified (`make clean`)
- [ ] All temporary resources deleted
- [ ] Final report submitted

---

**Project:** MLSA-K8S Capstone  
**Checklist Version:** 1.0  
**Last Updated:** February 2026
