# MLSA-K8S Project

## Overview
A 7-layer defense-in-depth Kubernetes security architecture on Google Kubernetes Engine (GKE), designed as a capstone project for CMU-CS 451, Team C2NE.03 at Duy Tan University.

## Project Structure
- `mlsa-k8s/` - Main project directory
  - `docs/` - Architecture, deployment guide, and threat model documentation
  - `infrastructure/` - Terraform configurations for GKE cluster provisioning
  - `kubernetes/` - Kubernetes manifests for all security layers
  - `evaluation/` - Security evaluation scenarios and scripts
  - `DEPLOYMENT_CHECKLIST.md` - Pre/post deployment verification checklist

## Running in Replit
Since this is an infrastructure-as-code project (not a runnable app), a Python documentation server has been added to present the project content:

- **`server.py`** - Simple HTTP server that renders project docs as a web interface
- **Port**: 5000 (bound to 0.0.0.0)
- **Workflow**: "Start application" → `python server.py`

## Dependencies
- Python 3.11
- `markdown` package (for rendering .md files)

## Deployment
- Target: autoscale
- Run command: `python server.py`

## Security Layers
| Layer | Component | Purpose |
|-------|-----------|---------|
| L1 | GKE Shielded Nodes | Node security |
| L2 | OPA Gatekeeper + RBAC | Policy enforcement |
| L3 | cert-manager + Istio | Identity & mTLS |
| L4 | Calico NetworkPolicy | Network segmentation |
| L5 | Binary Authorization + Trivy | Supply chain security |
| L6 | PSA + Falco | Workload protection |
| L7 | NGINX + Prometheus + Grafana | Observability |
