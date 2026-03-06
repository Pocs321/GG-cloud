#!/bin/bash
# Compare evaluation results between secured and baseline clusters

RESULTS_DIR="evaluation/results"

echo "=== MLSA-K8S Evaluation Results Summary ===" 
echo "Generated: $(date)"
echo ""

if [ ! -d "$RESULTS_DIR" ]; then
  echo "No results directory found. Run evaluation/scenarios/run-scenario.sh first."
  exit 1
fi

echo "Results found in: $RESULTS_DIR"
echo ""

# Summary table
echo "Scenario | Expected (Secured) | Result | Status"
echo "---------|-------------------|--------|--------"

for scenario in S1 S2 S3 S4 S5; do
  latest=$(ls -t "$RESULTS_DIR"/${scenario}_*.log 2>/dev/null | head -1)
  if [ -f "$latest" ]; then
    if grep -q "✅ SUCCESS" "$latest"; then
      status="PASS"
    else
      status="FAIL"
    fi
    echo "$scenario  | BLOCKED by L2/L3/L4/L5 | $status | $status"
  else
    echo "$scenario  | BLOCKED by L2/L3/L4/L5 | UNKNOWN | NOT RUN"
  fi
done

echo ""
echo "Legend:"
echo "  ✅ Attacks blocked by security controls (desired)"
echo "  ❌ Attacks succeeded (security issue detected)"
echo ""
