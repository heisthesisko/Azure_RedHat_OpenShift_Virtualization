#!/bin/bash
set -e

read -p "Enter Resource Group name: " RESOURCE_GROUP
read -p "Enter Cluster name: " CLUSTER_NAME

LOCATIONS=("westus" "centralus" "eastus")
echo "Choose Location:"
select LOCATION in "${LOCATIONS[@]}"; do
  if [[ " ${LOCATIONS[*]} " == *" $LOCATION "* ]]; then
    echo "✅ Selected location: $LOCATION"
    break
  fi
done

MASTER_SKUS=("Standard_D8s_v5" "Standard_D16s_v5" "Standard_D32s_v5" "Standard_D8s_v6" "Standard_D16s_v6" "Standard_D32s_v6")
echo "Choose Master VM size:"
select MASTER_VM_SIZE in "${MASTER_SKUS[@]}"; do
  if [[ " ${MASTER_SKUS[*]} " == *" $MASTER_VM_SIZE "* ]]; then
    echo "✅ Selected Master VM size: $MASTER_VM_SIZE"
    break
  fi
done

WORKER_SKUS=("${MASTER_SKUS[@]}")
echo "Choose Worker VM size:"
select WORKER_VM_SIZE in "${WORKER_SKUS[@]}"; do
  if [[ " ${WORKER_SKUS[*]} " == *" $WORKER_VM_SIZE "* ]]; then
    echo "✅ Selected Worker VM size: $WORKER_VM_SIZE"
    break
  fi
done

VNET_NAME="aro-vnet"
MASTER_SUBNET="master-subnet"
WORKER_SUBNET="worker-subnet"
VNET_ADDRESS_PREFIX="10.0.0.0/22"
MASTER_SUBNET_PREFIX="10.0.0.0/23"
WORKER_SUBNET_PREFIX="10.0.2.0/23"
ARO_VERSION="4.18.18"
STORAGE_ACCOUNT_NAME="aro$(openssl rand -hex 4)"
CONTAINER_NAME="arocontainer"

echo "📦 Creating resource group $RESOURCE_GROUP in $LOCATION..."
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" >/dev/null

echo "🌐 Creating virtual network..."
az network vnet create --resource-group "$RESOURCE_GROUP" --name "$VNET_NAME"   --address-prefixes "$VNET_ADDRESS_PREFIX" --subnet-name "$MASTER_SUBNET" --subnet-prefix "$MASTER_SUBNET_PREFIX" >/dev/null

echo "📶 Creating worker subnet..."
az network vnet subnet create --resource-group "$RESOURCE_GROUP" --vnet-name "$VNET_NAME"   --name "$WORKER_SUBNET" --address-prefix "$WORKER_SUBNET_PREFIX" >/dev/null

echo "📦 Creating storage account $STORAGE_ACCOUNT_NAME (Shared Key Disabled)..."
az storage account create --name "$STORAGE_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP" --location "$LOCATION"   --sku Standard_LRS --kind StorageV2 --min-tls-version TLS1_2 --allow-blob-public-access false   --allow-shared-key-access false --enable-hierarchical-namespace true

echo "📂 Creating blob container $CONTAINER_NAME using Azure AD login..."
az storage container-rm create --resource-group "$RESOURCE_GROUP" --storage-account "$STORAGE_ACCOUNT_NAME" --name "$CONTAINER_NAME" >/dev/null

echo "🔑 Please obtain your Red Hat pull secret from https://console.redhat.com/openshift/install/pull-secret"
read -s -p "Paste your pull secret and press enter: " PULL_SECRET
echo

echo "🚀 Creating ARO cluster version $ARO_VERSION..."
az aro create --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME"   --vnet "$VNET_NAME" --master-subnet "$MASTER_SUBNET" --worker-subnet "$WORKER_SUBNET"   --location "$LOCATION" --pull-secret "$PULL_SECRET" --cluster-resource-group "${CLUSTER_NAME}-infra"   --version "$ARO_VERSION" --master-vm-size "$MASTER_VM_SIZE" --worker-vm-size "$WORKER_VM_SIZE" --enable-managed-identity

echo "⏳ Waiting for cluster to succeed..."
for i in {1..60}; do
  STATUS=$(az aro show --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" --query provisioningState -o tsv)
  if [[ "$STATUS" == "Succeeded" ]]; then
    echo "✅ Cluster is ready."
    break
  fi
  sleep 30
done
