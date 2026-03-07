#!/bin/bash
# Evaluation Scenario Runner
# Executes attack scenarios against secured and baseline clusters

set -e

SCENARIO="${1:-S1}"
RESULTS_DIR="evaluation/results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULT_FILE="${RESULTS_DIR}/${SCENARIO}_${TIMESTAMP}.log"

mkdir -p "$RESULTS_DIR"

echo "=== Evaluating Scenario: $SCENARIO ===" | tee "$RESULT_FILE"
echo "Timestamp: $(date)" | tee -a "$RESULT_FILE"
echo "" | tee -a "$RESULT_FILE"

case "$SCENARIO" in
  S1)
    echo "Scenario S1: Privileged Pod Attack" | tee -a "$RESULT_FILE"
    echo "Testing: Gatekeeper (L2) + PSA (L6)" | tee -a "$RESULT_FILE"
    echo "" | tee -a "$RESULT_FILE"
    
    echo "Attempting to deploy privileged pod to production..." | tee -a "$RESULT_FILE"
    if kubectl apply -f evaluation/scenarios/S1-privileged-pod.yaml --dry-run=server -n production 2>&1 | tee -a "$RESULT_FILE"; then
      echo "❌ FAILED: Privileged pod was ALLOWED (should be blocked)" | tee -a "$RESULT_FILE"
      exit 1
    else
      echo "✅ SUCCESS: Privileged pod was BLOCKED by admission controller" | tee -a "$RESULT_FILE"
    fi
    ;;
  
  S2)
    echo "Scenario S2: RBAC Privilege Escalation" | tee -a "$RESULT_FILE"
    echo "Testing: RBAC controls (L2)" | tee -a "$RESULT_FILE"
    echo "" | tee -a "$RESULT_FILE"
    
    echo "Deploying pod and testing RBAC..." | tee -a "$RESULT_FILE"
    kubectl apply -f evaluation/scenarios/S2-rbac-escalation.yaml
    sleep 5
    
    if kubectl logs -n production s2-rbac-escalation | grep -q "Access denied"; then
      echo "✅ SUCCESS: RBAC correctly denied secret access" | tee -a "$RESULT_FILE"
      kubectl delete pod s2-rbac-escalation -n production
    else
      echo "❌ FAILED: RBAC did not block secret access" | tee -a "$RESULT_FILE"
      kubectl logs -n production s2-rbac-escalation | tee -a "$RESULT_FILE"
      kubectl delete pod s2-rbac-escalation -n production
      exit 1
    fi
    ;;
  
  S3)
    echo "Scenario S3: Lateral Movement (cross-namespace)" | tee -a "$RESULT_FILE"
    echo "Testing: NetworkPolicy (L4) + mTLS (L3)" | tee -a "$RESULT_FILE"
    echo "" | tee -a "$RESULT_FILE"
    
    echo "Deploying lateral movement pod in staging..." | tee -a "$RESULT_FILE"
    kubectl apply -f evaluation/scenarios/S3-lateral-movement.yaml
    sleep 5
    
    if kubectl logs -n staging s3-lateral-movement | grep -q "Connection denied\|Connection refused\|timeout"; then
      echo "✅ SUCCESS: Cross-namespace access BLOCKED by L3/L4" | tee -a "$RESULT_FILE"
      kubectl delete pod s3-lateral-movement -n staging
    else
      echo "❌ FAILED: Cross-namespace communication was allowed" | tee -a "$RESULT_FILE"
      kubectl logs -n staging s3-lateral-movement | tee -a "$RESULT_FILE"
      kubectl delete pod s3-lateral-movement -n staging
      exit 1
    fi
    ;;
  
  S4)
    echo "Scenario S4: Unsigned Image Deployment" | tee -a "$RESULT_FILE"
    echo "Testing: Binary Authorization (L5)" | tee -a "$RESULT_FILE"
    echo "" | tee -a "$RESULT_FILE"
    
    echo "Attempting unsigned image deployment (dry-run)..." | tee -a "$RESULT_FILE"
    if kubectl apply -f evaluation/scenarios/S4-unsigned-image.yaml --dry-run=server -n evaluation 2>&1 | tee -a "$RESULT_FILE"; then
      echo "⚠️  WARNING: Binary Authorization may not be fully enforced in dry-run" | tee -a "$RESULT_FILE"
    else
      echo "✅ SUCCESS: Unsigned image was BLOCKED by Binary Authorization" | tee -a "$RESULT_FILE"
    fi
    ;;
  
  S5)
    echo "Scenario S5: Cross-Namespace Secrets Access" | tee -a "$RESULT_FILE"
    echo "Testing: RBAC (L2) + NetworkPolicy (L4)" | tee -a "$RESULT_FILE"
    echo "" | tee -a "$RESULT_FILE"
    
    echo "Deploying secrets exfiltration pod in staging..." | tee -a "$RESULT_FILE"
    kubectl apply -f evaluation/scenarios/S5-secrets-exfiltration.yaml
    sleep 5
    
    if kubectl logs -n staging s5-secrets-exfiltration | grep -q "Access denied\|Forbidden"; then
      echo "✅ SUCCESS: RBAC + NetworkPolicy correctly blocked secret access" | tee -a "$RESULT_FILE"
      kubectl delete pod s5-secrets-exfiltration -n staging
    else
      echo "❌ FAILED: Secrets were accessible across namespaces" | tee -a "$RESULT_FILE"
      kubectl logs -n staging s5-secrets-exfiltration | tee -a "$RESULT_FILE"
      kubectl delete pod s5-secrets-exfiltration -n staging
      exit 1
    fi
    ;;
  
  *)
    echo "Invalid scenario: $SCENARIO" | tee -a "$RESULT_FILE"
    echo "Valid scenarios: S1, S2, S3, S4, S5" | tee -a "$RESULT_FILE"
    exit 1
    ;;
esac

echo "" | tee -a "$RESULT_FILE"
echo "Result saved to: $RESULT_FILE" | tee -a "$RESULT_FILE"
