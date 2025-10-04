#!/bin/bash

LOG_FILE="aro_operator_health_20250619_163940.log"
echo "🔍 Starting ARO Operator Health Check - Logging to $LOG_FILE"

log() {
  echo "$1" | tee -a "$LOG_FILE"
}

log "Step 1: Wait for kubevirt-hyperconverged Subscription to be Available..."
oc wait --for=condition=CatalogSourcesUnhealthy=False subscription/kubevirt-hyperconverged -n openshift-cnv --timeout=600s || log "❌ kubevirt-hyperconverged subscription did not become healthy in time."

log "Step 2: Wait for MTV Subscription to be Available..."
oc wait --for=condition=CatalogSourcesUnhealthy=False subscription/migration-operator -n openshift-mtv --timeout=600s || log "❌ migration-operator subscription did not become healthy in time."

log "Step 3: Wait for HyperConverged CR to be Available..."
oc wait --for=condition=Available hyperconverged/kubevirt-hyperconverged -n openshift-cnv --timeout=600s || log "❌ kubevirt-hyperconverged CR did not become available in time."

log "Step 4: List ClusterServiceVersions (CSVs)..."
oc get csv -n openshift-cnv | tee -a "$LOG_FILE"
oc get csv -n openshift-mtv | tee -a "$LOG_FILE"

log "Step 5: Check pods for both operators..."
oc get pods -n openshift-cnv | tee -a "$LOG_FILE"
oc get pods -n openshift-mtv | tee -a "$LOG_FILE"

log "Step 6: Verifying MTV CRDs..."
EXPECTED_CRDS=(
  "virtmigrationplans.mtv.openshift.io"
  "migrationcontrollers.mtv.openshift.io"
  "plans.migration.openshift.io"
  "providers.migration.openshift.io"
)

for crd in "${EXPECTED_CRDS[@]}"; do
  if oc get crd "$crd" &>/dev/null; then
    log "✅ CRD exists: $crd"
  else
    log "❌ Missing MTV CRD: $crd"
  fi
done

log "✅ Operator health check completed. Review $LOG_FILE for full results."
