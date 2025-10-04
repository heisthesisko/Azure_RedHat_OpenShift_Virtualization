#!/bin/bash

set -e

RESOURCE_GROUP="AroVirtTestCluster"
LOCATION="westus"
CLUSTER_NAME="aro-cluster"
VNET_NAME="aro-vnet"
MASTER_SUBNET="master-subnet"
WORKER_SUBNET="worker-subnet"
VNET_ADDRESS_PREFIX="10.0.0.0/22"
MASTER_SUBNET_PREFIX="10.0.0.0/23"
WORKER_SUBNET_PREFIX="10.0.2.0/23"
ARO_VERSION="4.17.27"
MASTER_VM_SIZE="Standard_D8s_v5"
WORKER_VM_SIZE="Standard_D8s_v5"

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

# Step 1: Register providers
for provider in Microsoft.RedHatOpenShift Microsoft.Network Microsoft.Compute Microsoft.Storage Microsoft.Authorization; do
  register_provider $provider
done

# Step 2: Create resource group
echo "📦 Creating resource group $RESOURCE_GROUP in $LOCATION..."
az group create --name $RESOURCE_GROUP --location $LOCATION >/dev/null

# Validating resource group with retries
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

# Step 3: Create virtual network and subnets
echo "🌐 Creating virtual network..."
az network vnet create \
  --resource-group $RESOURCE_GROUP \
  --name $VNET_NAME \
  --address-prefixes $VNET_ADDRESS_PREFIX \
  --subnet-name $MASTER_SUBNET \
  --subnet-prefix $MASTER_SUBNET_PREFIX >/dev/null

echo "📶 Creating worker subnet..."
az network vnet subnet create \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $VNET_NAME \
  --name $WORKER_SUBNET \
  --address-prefix $WORKER_SUBNET_PREFIX >/dev/null

# Validate VNet and subnets with retry
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

for i in {1..3}; do
  sleep 30
  echo "🔍 Checking master subnet (attempt $i)..."
  if az network vnet subnet show --resource-group $RESOURCE_GROUP --vnet-name $VNET_NAME --name $MASTER_SUBNET &>/dev/null; then
    echo "✅ Master subnet exists."
    break
  fi
  if [ $i -eq 3 ]; then
    echo "❌ Master subnet validation failed after 3 attempts."
    exit 1
  fi
done

for i in {1..3}; do
  sleep 30
  echo "🔍 Checking worker subnet (attempt $i)..."
  if az network vnet subnet show --resource-group $RESOURCE_GROUP --vnet-name $VNET_NAME --name $WORKER_SUBNET &>/dev/null; then
    echo "✅ Worker subnet exists."
    break
  fi
  if [ $i -eq 3 ]; then
    echo "❌ Worker subnet validation failed after 3 attempts."
    exit 1
  fi
done

echo "✅ Network resources validated."

# Step 5: Get Red Hat pull secret
echo "🔑 Please obtain your Red Hat pull secret from https://console.redhat.com/openshift/install/pull-secret"
read -s -p "Paste your pull secret and press enter: " PULL_SECRET

# Step 6: Create ARO cluster
echo "...input recieved"
echo "🚀 Creating ARO cluster version $ARO_VERSION..."
az aro create \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --vnet $VNET_NAME \
  --master-subnet $MASTER_SUBNET \
  --worker-subnet $WORKER_SUBNET \
  --location $LOCATION \
  --pull-secret "$PULL_SECRET" \
  --cluster-resource-group "${CLUSTER_NAME}-infra" \
  --version $ARO_VERSION \
  --master-vm-size $MASTER_VM_SIZE \
  --worker-vm-size $WORKER_VM_SIZE \


# Step 7: Wait for cluster to stabilize before upgrade
echo "⏳ Waiting for ARO cluster to reach 'Succeeded' state before upgrade..."

for i in {1..60}; do
  STATUS=$(az aro show --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --query provisioningState -o tsv)
  if [[ "$STATUS" == "Succeeded" ]]; then
    echo "✅ Cluster is ready. Proceed with manual upgrade."
    break
  fi
  echo "⏱️  [$i/30] Current status: $STATUS... waiting 30s"
  sleep 30
done

STATUS=$(az aro show --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --query provisioningState -o tsv)
if [[ "$STATUS" != "Succeeded" ]]; then
  echo "❌ Cluster is not ready for upgrade. Current state: $STATUS"
  exit 1
fi

echo "🔄 Log into OCP Portal to manually upgrade the cluster and install operators for virtualization."