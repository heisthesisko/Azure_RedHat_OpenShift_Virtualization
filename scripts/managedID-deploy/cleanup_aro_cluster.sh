#!/bin/bash
set -e

read -p "Enter Resource Group name to clean up: " RESOURCE_GROUP
read -p "Enter Cluster name: " CLUSTER_NAME

echo "🗑️ Deleting ARO cluster $CLUSTER_NAME..."
az aro delete --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" --yes --no-wait

echo "⏳ Waiting for cluster to be deleted..."
az aro wait --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" --deleted

echo "🗑️ Deleting storage accounts in resource group $RESOURCE_GROUP..."
STORAGE_ACCOUNTS=$(az storage account list --resource-group "$RESOURCE_GROUP" --query "[].name" -o tsv)
for sa in $STORAGE_ACCOUNTS; do
  echo "🗑️ Deleting storage account $sa..."
  az storage account delete --name "$sa" --resource-group "$RESOURCE_GROUP" --yes
done

if az network vnet show --resource-group "$RESOURCE_GROUP" --name "aro-vnet" >/dev/null 2>&1; then
  echo "🗑️ Deleting VNet aro-vnet..."
  az network vnet delete --resource-group "$RESOURCE_GROUP" --name "aro-vnet"
fi

OPERATOR_IDENTITIES=(aro-cluster cloud-controller-manager ingress machine-api disk-csi-driver file-csi-driver cloud-network-config image-registry aro-operator)

for ID_NAME in "${OPERATOR_IDENTITIES[@]}"; do
  if az identity show --resource-group "$RESOURCE_GROUP" --name "$ID_NAME" >/dev/null 2>&1; then
    echo "🗑️ Deleting managed identity $ID_NAME..."
    az identity delete --resource-group "$RESOURCE_GROUP" --name "$ID_NAME"
  fi
done

echo "🗑️ Deleting resource group $RESOURCE_GROUP..."
az group delete --name "$RESOURCE_GROUP" --yes --no-wait

echo "✅ Cleanup completed."
