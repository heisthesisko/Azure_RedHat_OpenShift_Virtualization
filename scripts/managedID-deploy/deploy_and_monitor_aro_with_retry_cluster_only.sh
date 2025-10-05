#!/bin/bash

DEPLOY_SCRIPT="./deploy_aro_cluster_managedid_preview_ver_001.sh"
MAX_RETRIES=3
RETRY_DELAY=60  # in seconds
LOG_FILE="aro_deployment_$(date +%Y%m%d_%H%M%S).log"

touch "$LOG_FILE"

attempt=1
success=0

while [ $attempt -le $MAX_RETRIES ]; do
  echo "🚀 [Attempt $attempt/$MAX_RETRIES] Starting ARO deployment..." | tee -a "$LOG_FILE"
  bash "$DEPLOY_SCRIPT" 2>&1 | tee -a "$LOG_FILE" &
  DEPLOY_PID=$!

  # Monitor progress
  while kill -0 $DEPLOY_PID 2>/dev/null; do
    echo "⌛ Deployment in progress... $(date)" | tee -a "$LOG_FILE"
    sleep 60
  done

  # Check if the deployment succeeded (ARO cluster exists and is ready)
  CLUSTER_STATUS=$(az aro show -g AroVirtL300 -n aro-cluster --query "provisioningState" -o tsv 2>/dev/null)

  if [[ "$CLUSTER_STATUS" == "Succeeded" ]]; then
    echo "✅ Deployment completed successfully on attempt $attempt." | tee -a "$LOG_FILE"
    success=1
    break
  else
    echo "❌ Deployment attempt $attempt failed. Status: $CLUSTER_STATUS" | tee -a "$LOG_FILE"
    ((attempt++))
    if [ $attempt -le $MAX_RETRIES ]; then
      echo "🔁 Retrying in $RETRY_DELAY seconds..." | tee -a "$LOG_FILE"
      sleep $RETRY_DELAY
    fi
  fi
done

if [ $success -eq 1 ]; then
  echo "🎉 Deployment verification complete. See log: $LOG_FILE"
else
  echo "❌ All $MAX_RETRIES deployment attempts failed. Check log for errors: $LOG_FILE"
  exit 1
fi