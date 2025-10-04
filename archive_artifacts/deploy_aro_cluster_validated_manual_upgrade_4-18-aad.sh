#!/bin/bash

set -e

# ------------------------------
# Prompt user for input
# ------------------------------

read -p "Enter Resource Group name: " RESOURCE_GROUP
read -p "Enter Cluster name: " CLUSTER_NAME

# Location selection
LOCATIONS=("westus" "centralus" "eastus")
echo "Choose Location:"
select LOCATION in "${LOCATIONS[@]}"; do
  if [[ " ${LOCATIONS[*]} " == *" $LOCATION "* ]]; then
    echo "✅ Selected location: $LOCATION"
    break
  else
    echo "❌ Invalid choice, please select again."
  fi
done

# Master VM sizes
MASTER_SKUS=("Standard_D8s_v5" "Standard_D16s_v5" "Standard_D32s_v5" "Standard_D8s_v6" "Standard_D16s_v6" "Standard_D32s_v6")
echo "Choose Master VM size:"
select MASTER_VM_SIZE in "${MASTER_SKUS[@]}"; do
  if [[ " ${MASTER_SKUS[*]} " == *" $MASTER_VM_SIZE "* ]]; then
    echo "✅ Selected Master VM size: $MASTER_VM_SIZE"
    break
  else
    echo "❌ Invalid choice, please select again."
  fi
done

# Worker VM sizes
WORKER_SKUS=("Standard_D8s_v5" "Standard_D16s_v5" "Standard_D32s_v5" "Standard_D8s_v6" "Standard_D16s_v6" "Standard_D32s_v6")
echo "Choose Worker VM size:"
select WORKER_VM_SIZE in "${WORKER_SKUS[@]}"; do
  if [[ " ${WORKER_SKUS[*]} " == *" $WORKER_VM_SIZE "* ]]; then
    echo "✅ Selected Worker VM size: $WORKER_VM_SIZE"
    break
  else
    echo "❌ Invalid choice, please select again."
  fi
done

# ------------------------------
# Static values
# ------------------------------
VNET_NAME="aro-vnet"
MASTER_SUBNET="master-subnet"
WORKER_SUBNET="worker-subnet"
VNET_ADDRESS_PREFIX="10.0.0.0/22"
MASTER_SUBNET_PREFIX="10.0.0.0/23"
WORKER_SUBNET_PREFIX="10.0.2.0/23"
ARO_VERSION="4.17.27"

# Storage vars
STORAGE_ACCOUNT_NAME="aro$(openssl rand -hex 4)"
CONTAINER_NAME="arocontainer"

# ------------------------------
# Functions
# ------------------------------
register_provider() {
  local provider=$1
  echo "🔧 Registering $provider..."
  az provider register --namespace $provider
  for i in {1..10}; do
    STATUS=$(az provider show --namespace $provider --query "registrationState" -o tsv)
    if [[ "$STATUS" == "Registered" ]]; then
      echo "✅ $provider is registered."
      return 0
    fi
    echo "⏳ Waiting for $provider to register..."
    sleep 10
  done
  echo "❌ Failed to register $provider within timeout."
  exit 1
}

# ------------------------------
# Step 1: Register providers
# ------------------------------
for provider in Microsoft.RedHatOpenShift Microsoft.Network Microsoft.Compute Microsoft.Storage Microsoft.Authorization; do
  register_provider $provider
done

# ------------------------------
# Step 2: Create resource group
# ------------------------------
echo "📦 Creating resource group $RESOURCE_GROUP in $LOCATION..."
az group create --name $RESOURCE_GROUP --location $LOCATION >/dev/null

# Validate RG
for i in {1..3}; do
  sleep 15
  echo "🔍 Checking resource group (attempt $i)..."
  if az group show --name $RESOURCE_GROUP &>/dev/null; then
    echo "✅ Resource group exists."
    break
  fi
  if [ $i -eq 3 ]; then
    echo "❌ Resource group validation failed after 3 attempts."
    exit 1
  fi
done

# ------------------------------
# Step 3: VNET + Subnets
# ------------------------------
echo "🌐 Creating virtual network..."
az network vnet create   --resource-group $RESOURCE_GROUP   --name $VNET_NAME   --address-prefixes $VNET_ADDRESS_PREFIX   --subnet-name $MASTER_SUBNET   --subnet-prefix $MASTER_SUBNET_PREFIX >/dev/null

echo "📶 Creating worker subnet..."
az network vnet subnet create   --resource-group $RESOURCE_GROUP   --vnet-name $VNET_NAME   --name $WORKER_SUBNET   --address-prefix $WORKER_SUBNET_PREFIX >/dev/null

# Validate VNET and subnets
for i in {1..3}; do
  sleep 30
  echo "🔍 Checking VNet (attempt $i)..."
  if az network vnet show --resource-group $RESOURCE_GROUP --name $VNET_NAME &>/dev/null; then
    echo "✅ VNet exists."
    break
  fi
  if [ $i -eq 3 ]; then
    echo "❌ VNet validation failed after 3 attempts."
    exit 1
  fi
done

# ------------------------------
# Step 4: Storage (AAD auth only)
# ------------------------------
echo "📦 Creating storage account $STORAGE_ACCOUNT_NAME (AAD auth only)..."
az storage account create   --name $STORAGE_ACCOUNT_NAME   --resource-group $RESOURCE_GROUP   --location $LOCATION   --sku Standard_LRS   --kind StorageV2   --min-tls-version TLS1_2   --allow-blob-public-access false   --allow-shared-key-access false   --enable-hierarchical-namespace true

SIGNED_IN_USER=$(az ad signed-in-user show --query id -o tsv)
STORAGE_ID=$(az storage account show --name $STORAGE_ACCOUNT_NAME --resource-group $RESOURCE_GROUP --query id -o tsv)

echo "🔑 Assigning Storage Blob Data Contributor role to logged-in user..."
az role assignment create   --assignee $SIGNED_IN_USER   --role "Storage Blob Data Contributor"   --scope $STORAGE_ID

echo "📂 Creating blob container $CONTAINER_NAME..."
az storage container create   --name $CONTAINER_NAME   --account-name $STORAGE_ACCOUNT_NAME   --auth-mode login

# ------------------------------
# Step 5: Pull Secret
# ------------------------------
echo "🔑 Please obtain your Red Hat pull secret from https://console.redhat.com/openshift/install/pull-secret"
read -s -p "Paste your pull secret and press enter: " PULL_SECRET
echo

# ------------------------------
# Step 6: Create ARO Cluster
# ------------------------------
echo "🚀 Creating ARO cluster version $ARO_VERSION..."
az aro create   --resource-group $RESOURCE_GROUP   --name $CLUSTER_NAME   --vnet $VNET_NAME   --master-subnet $MASTER_SUBNET   --worker-subnet $WORKER_SUBNET   --location $LOCATION   --pull-secret "$PULL_SECRET"   --cluster-resource-group "${CLUSTER_NAME}-infra"   --version $ARO_VERSION   --master-vm-size $MASTER_VM_SIZE   --worker-vm-size $WORKER_VM_SIZE

# ------------------------------
# Step 7: Wait for cluster
# ------------------------------
echo "⏳ Waiting for ARO cluster to reach 'Succeeded' state before upgrade..."
for i in {1..60}; do
  STATUS=$(az aro show --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --query provisioningState -o tsv)
  if [[ "$STATUS" == "Succeeded" ]]; then
    echo "✅ Cluster is ready. Proceed with manual upgrade."
    break
  fi
  echo "⏱️  [$i/60] Current status: $STATUS... waiting 30s"
  sleep 30
done

STATUS=$(az aro show --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --query provisioningState -o tsv)
if [[ "$STATUS" != "Succeeded" ]]; then
  echo "❌ Cluster is not ready for upgrade. Current state: $STATUS"
  exit 1
fi

echo "🔄 Log into OCP Portal to manually upgrade the cluster and install operators for virtualization."
