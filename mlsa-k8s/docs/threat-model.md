# MLSA-K8S Threat Model & Security Analysis

## Executive Summary

The MLSA-K8S project implements a **7-layer defense-in-depth architecture** on Google Kubernetes Engine (GKE) to protect cloud-native applications from known Kubernetes threats. This document outlines the threat model, identified vulnerabilities, and mitigation strategies.

---

## 1. Threat Taxonomy

### 1.1 Cluster-Level Threats

| Threat ID | Name | Severity | Layer | Mitigation |
|-----------|------|----------|-------|-----------|
| T-C-001 | Unauthorized API Access | CRITICAL | L2 | RBAC + audit logging |
| T-C-002 | Privilege Escalation | CRITICAL | L2, L6 | RBAC + PSA + Gatekeeper |
| T-C-003 | Node Compromise | HIGH | L1 | Shielded nodes, node hardening |
| T-C-004 | etcd Data Leakage | CRITICAL | L0 | Encryption at rest (GKE managed) |
| T-C-005 | Control Plane Compromise | CRITICAL | L0 | GKE managed, Cloud Audit Logs |

### 1.2 Application-Level Threats

| Threat ID | Name | Severity | Layer | Mitigation |
|-----------|------|----------|-------|-----------|
| T-A-001 | Container Escape | CRITICAL | L1, L6 | PSA, seccomp, AppArmor |
| T-A-002 | Lateral Movement | HIGH | L3, L4 | NetworkPolicy, mTLS |
| T-A-003 | Supply Chain Injection | CRITICAL | L5 | Binary Authorization, Trivy |
| T-A-004 | Secret Exfiltration | CRITICAL | L2, L3 | RBAC, Workload Identity |
| T-A-005 | Resource Exhaustion | MEDIUM | L2 | Resource limits, quotas |
| T-A-006 | Unauthorized Image Pull | HIGH | L5 | Image pull policies, registry auth |

### 1.3 Network-Level Threats

| Threat ID | Name | Severity | Layer | Mitigation |
|-----------|------|----------|-------|-----------|
| T-N-001 | Pod-to-Pod Sniffing | HIGH | L3, L4 | mTLS encryption, NetworkPolicy |
| T-N-002 | Service Mesh Bypass | MEDIUM | L3 | Istio mutual TLS (STRICT) |
| T-N-003 | DNS Spoofing | MEDIUM | L4 | CoreDNS hardening, NetworkPolicy |
| T-N-004 | Egress Data Exfiltration | HIGH | L4 | NetworkPolicy deny-all egress |

---

## 2. Attack Scenarios & Mitigations

### Scenario 1: Privileged Container Escape (T-A-001)

**Attack Path:**
```
1. Attacker deploys privileged container
2. Container gets access to host root filesystem
3. Attacker escapes to host kernel
4. Full cluster compromise
```

**Mitigations:**
- ✅ **L2 - Gatekeeper**: Blocks `privileged: true` containers
- ✅ **L6 - PSA (Restricted mode)**: Prevents privilege escalation
- ✅ **L6 - seccomp**: Restricts dangerous syscalls
- ✅ **L1 - Shielded Nodes**: UEFI Secure Boot + TPM

**Evaluation Script:** `S1-privileged-pod-escape.sh`

---

### Scenario 2: RBAC Privilege Escalation (T-C-002)

**Attack Path:**
```
1. Attacker gains access to application pod
2. Service account token mounted by default
3. Escalates to cluster-admin via weak RBAC
4. Full cluster compromise
```

**Mitigations:**
- ✅ **L2 - RBAC**: Service accounts have minimal permissions
- ✅ **L2 - Audit Logging**: All API access logged to Cloud Logging
- ✅ **No cluster-admin bindings**: Regular workloads use restricted roles
- ✅ **Automount control**: `automountServiceAccountToken: false`

**Evaluation Script:** `S2-rbac-privilege-escalation.sh`

---

### Scenario 3: Lateral Movement (T-A-002)

**Attack Path:**
```
1. Attacker gains access to app in namespace A
2. Service mesh trust domain not isolated
3. Attacker crafts mTLS certificates
4. Moves laterally to namespace B, database pod
5. Data exfiltration
```

**Mitigations:**
- ✅ **L4 - NetworkPolicy**: Default deny-all ingress/egress
- ✅ **L3 - Istio mTLS (STRICT)**: All traffic encrypted + authenticated
- ✅ **L3 - Authorization Policies**: Explicit allow rules only
- ✅ **L4 - Namespace Isolation**: Labels restrict cross-namespace traffic

**Evaluation Script:** `S3-lateral-movement.sh`

---

### Scenario 4: Supply Chain Injection (T-A-003)

**Attack Path:**
```
1. Attacker compromises container registry
2. Pushes malicious image tag
3. Deployment pulls unsigned image
4. Malware spreads across cluster
```

**Mitigations:**
- ✅ **L5 - Binary Authorization**: Only signed images allowed
- ✅ **L5 - Trivy Scanning**: All images scanned for vulnerabilities
- ✅ **L5 - Image pull policy: Always**: Always re-verify on pull
- ✅ **L2 - Gatekeeper**: Whitelist allowed registries only

**Evaluation Script:** `S4-supply-chain-injection.sh` (future)

---

### Scenario 5: Secret Exfiltration (T-A-004)

**Attack Path:**
```
1. Attacker gets pod execution access
2. Service account token available in /var/run/secrets/
3. Queries Kubernetes API for secrets
4. Exfiltrates sensitive data
```

**Mitigations:**
- ✅ **L2 - RBAC**: Service accounts cannot read secrets from other namespaces
- ✅ **L3 - Workload Identity**: Pods use Google service accounts, not shared tokens
- ✅ **L2 - Audit Logging**: Secret access logged
- ✅ **L6 - Falco Rules**: Detects suspicious secret access patterns

**Evaluation Script:** `S5-secrets-exfiltration.sh` (future)

---

## 3. Threat Detection & Monitoring

### Kubernetes Audit Logging (L2)

**Monitored Events:**
- API authentication failures (repeated failures = intrusion)
- RBAC denial events
- Privilege escalation attempts
- Unusual API calls (e.g., exec into pods)
- Secret/ConfigMap access

**Log sink:** Google Cloud Logging
**Retention:** 30 days (configurable)

### Falco Runtime Monitoring (L6)

**Detection Rules:**
- Suspicious process execution (shell in containers)
- File system modifications (read-only violation)
- Network anomalies (unexpected egress)
- Privilege escalation syscalls
- Container escape attempts

**Actions:**
- Log to Cloud Logging
- Alert to incident response team
- Optional: Auto-kill malicious pods

### Metrics Collection (L7)

**Prometheus Metrics:**
- API request latency (detection: unusual slowness)
- Authentication failures (detection: brute force)
- Network policy violations
- Pod restart rates (detection: crashes from malware)

---

## 4. Residual Risks & Limitations

### Known Limitations

1. **Admitted Kubernetes vulnerabilities** (e.g., CVE-2024-XXXXX)
   - Mitigated by: Regular GKE version updates
   - Responsibility: Google (Managed Service)

2. **Source code vulnerabilities** in applications
   - Mitigated by: Trivy scanning (detects known vulns only)
   - Gap: Zero-day vulnerabilities not detected

3. **Insider threat** from legitimate users
   - Mitigated by: Audit logging + Falco
   - Gap: Trusted admins can bypass most controls

4. **Container image supply chain** before pushing to registry
   - Mitigated by: Trivy + Binary Authorization
   - Gap: Build system compromise not addressed

5. **Cloud account compromise** (e.g., service account stolen)
   - Mitigated by: Workload Identity (service accounts not exportable)
   - Gap: GCP IAM security is separate layer

### Recommendations for Production

1. **Incident Response Plan**
   - Define team, escalation path, communication
   - Document incident response runbooks for each scenario

2. **Threat Intelligence Feed**
   - Subscribe to Kubernetes CVE feeds
   - Auto-patch security issues

3. **Regular Penetration Testing**
   - External red team exercises quarterly
   - Document findings and improve controls

4. **Extra Layer: API Gateway**
   - Rate limiting, DDoS protection
   - WAF for application layer

5. **Secrets Management**
   - Use external secret manager (Google Secret Manager)
   - Don't store secrets in etcd directly

6. **Compliance**
   - CIS Kubernetes Benchmark (automated checks)
   - PCI-DSS, SOC2, GDPR alignment if applicable

---

## 5. Incident Response Playbooks

### Playbook: Suspicious Pod Activity (Detected by Falco)

```
1. DETECT: Falco alert triggered
   └─ Action: Team notified (Slack, PagerDuty)

2. INVESTIGATE:
   └─ Check pod logs: kubectl logs <pod>
   └─ Check parent process: kubectl exec <pod> ps aux
   └─ Check network connections: kubectl exec <pod> ss -tnop
   └─ Check file modifications: fsck audit logs

3. CONTAINMENT:
   └─ Option A (Soft): Isolate pod with NetworkPolicy
   └─ Option B (Hard): Delete pod immediately

4. ERADICATION:
   └─ Delete compromised pod
   └─ Force new deployment (triggers image scanning)
   └─ Scan image in registry for malware

5. RECOVERY:
   └─ Monitor for re-infection attempts
   └─ Update Falco rules if needed

6. POST-INCIDENT:
   └─ Post-mortem analysis
   └─ Update defenses
   └─ Document lessons learned
```

### Playbook: Unauthorized API Access (Audit Log Alert)

```
1. DETECT: Audit log shows repeated 403 Forbidden
   └─ Source: Service account X
   └─ Action: Attempting to list secrets

2. INVESTIGATE:
   └─ Who owns this service account?
   └─ Recent pod deployments using this service account?
   └─ Legitimate business reason for secret access?

3. CONTAINMENT:
   └─ Remove RBAC permissions immediately
   └─ Alert workload owner

4. ERADICATION:
   └─ Scan pod for malware/compromise
   └─ Review pod logs for suspicious activity

5. RECOVERY:
   └─ Redeploy pod with fixed permissions

6. POST-INCIDENT:
   └─ Review RBAC role design
   └─ Add more restrictive rules
```

---

## 6. Compliance Alignment

### CIS Kubernetes Benchmark

| CIS Section | Benchmark | MLSA Implementation | Status |
|-------------|-----------|-------------------|--------|
| 1.x | Control Plane | GKE managed | ✅ |
| 2.x | etcd | Encryption at rest | ✅ |
| 3.x | Control Plane Configs | Audit logging enabled | ✅ |
| 4.x | Worker Nodes | Shielded nodes, hardening | ✅ |
| 5.x | K8s Policies | RBAC + Gatekeeper | ✅ |
| 6.x | General Policies | PSA, NetworkPolicy | ✅ |

### NIST Cybersecurity Framework

| Function | Activity | MLSA Layer |
|----------|----------|-----------|
| Identify | Asset inventory | Cloud Logging |
| Protect | Access control | L2 (RBAC) + L3 (mTLS) |
| Protect | Data protection | L3 (mTLS) + L5 (encryption) |
| Detect | Anomaly detection | L7 (Falco) + L7 (Metrics) |
| Respond | Incident handling | Audit logs + manual SOC |
| Recover | Disaster recovery | Backup strategy (external) |

---

## 7. Future Improvements

1. **GitOps Security**: ArgoCD with policy-as-code (Kustomize)
2. **Advanced Threat Detection**: Anomaly ML detection in Falco
3. **Zero-Trust Networking**: Service mesh with fine-grained policies
4. **Secrets Rotation**: Automated cert rotation, secret key rolling
5. **Compliance Automation**: CIS/PCI/SOC2 compliance checks in CI/CD
6. **Disaster Recovery**: Backup + restore procedures for etcd
7. **Multi-cluster Security**: Service mesh across clusters
8. **Cloud Security Posture Management**: AWS Security Hub integration

---

## References

- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/)
- [CIS Kubernetes Benchmark v1.7.0](https://www.cisecurity.org/benchmark/kubernetes)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
- [Falco Rules Documentation](https://falco.org/docs/rules/)
- [OPA/Gatekeeper Policies](https://open-policy-agent.org/docs/latest/kubernetes-introduction/)
- [Istio Security](https://istio.io/latest/docs/concepts/security/)

---

**Document:** MLSA-K8S Threat Model  
**Version:** 1.0  
**Last Updated:** February 2026  
**Author:** Team C2NE.03
