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
WORKER_SKUS=("${MASTER_SKUS[@]}")
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
# Use the latest ARO 4.x version available (example shown for 4.18.18)
ARO_VERSION="4.18.18"

# Storage naming
STORAGE_ACCOUNT_NAME="aro$(openssl rand -hex 4)"
CONTAINER_NAME="arocontainer"

# ------------------------------
# Functions
# ------------------------------
register_provider() {
  local provider=$1
  echo "🔧 Registering $provider..."
  az provider register --namespace "$provider"
  for i in {1..10}; do
    STATUS=$(az provider show --namespace "$provider" --query "registrationState" -o tsv)
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

# Role assignment helper function
assign_role() {
  local ASSIGNEE_ID=$1
  local ROLE_ID=$2
  local SCOPE=$3
  local DESC=$4
  echo "🔑 Assigning $DESC ..."
  set +e
  local OUTPUT
  OUTPUT=$(az role assignment create --assignee-object-id "$ASSIGNEE_ID" --role "$ROLE_ID" --scope "$SCOPE" --assignee-principal-type ServicePrincipal 2>&1)
  local STATUS=$?
  set -e
  if [ $STATUS -ne 0 ]; then
    if echo "$OUTPUT" | grep -q "already exists"; then
      echo "ℹ️ Role assignment for $DESC already exists."
    else
      echo "❌ Failed to assign role for $DESC: $OUTPUT"
      exit 1
    fi
  else
    echo "✅ Role assigned for $DESC."
  fi
}

# ------------------------------
# Step 1: Register resource providers
# ------------------------------
for provider in Microsoft.RedHatOpenShift Microsoft.Network Microsoft.Compute Microsoft.Storage Microsoft.Authorization; do
  register_provider "$provider"
done

# ------------------------------
# Step 2: Create Resource Group
# ------------------------------
echo "📦 Creating resource group $RESOURCE_GROUP in $LOCATION..."
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" >/dev/null

# ------------------------------
# Step 3: Networking (VNet & Subnets)
# ------------------------------
echo "🌐 Creating virtual network $VNET_NAME..."
az network vnet create --resource-group "$RESOURCE_GROUP" --name "$VNET_NAME" \
  --address-prefixes "$VNET_ADDRESS_PREFIX" --subnet-name "$MASTER_SUBNET" --subnet-prefix "$MASTER_SUBNET_PREFIX" >/dev/null

echo "📶 Creating worker subnet $WORKER_SUBNET..."
az network vnet subnet create --resource-group "$RESOURCE_GROUP" --vnet-name "$VNET_NAME" \
  --name "$WORKER_SUBNET" --address-prefix "$WORKER_SUBNET_PREFIX" >/dev/null

# ------------------------------
# Step 4: Storage (Azure AD Only)
# ------------------------------
echo "📦 Creating storage account $STORAGE_ACCOUNT_NAME (Shared Key Disabled)..."
az storage account create --name "$STORAGE_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP" --location "$LOCATION" \
  --sku Standard_LRS --kind StorageV2 --min-tls-version TLS1_2 \
  --allow-blob-public-access false --allow-shared-key-access false --enable-hierarchical-namespace true

echo "📂 Creating blob container $CONTAINER_NAME using Azure AD login..."
az storage container-rm create --resource-group "$RESOURCE_GROUP" --storage-account "$STORAGE_ACCOUNT_NAME" --name "$CONTAINER_NAME" >/dev/null

echo "✅ Storage account and container ready for ARO."

# ------------------------------
# Step 5: Managed Identities and Roles
# ------------------------------
echo "🔐 Configuring managed identities for ARO..."
echo "Choose cluster identity type:"
options=("System-assigned (Azure creates a managed identity for the cluster)" "User-assigned (create a cluster managed identity in Azure)")
select IDENTITY_CHOICE in "${options[@]}"; do
  case $REPLY in
    1) USE_SYSTEM_IDENTITY=true; echo "✅ Using system-assigned identity for cluster."; break;;
    2) USE_SYSTEM_IDENTITY=false; echo "✅ Using user-assigned managed identity for cluster."; break;;
    *) echo "❌ Invalid choice, please select again.";;
  esac
done

# Define identity names
OPERATOR_IDENTITIES=(cloud-controller-manager ingress machine-api disk-csi-driver file-csi-driver cloud-network-config image-registry aro-operator)
if [ "$USE_SYSTEM_IDENTITY" = false ]; then
  IDENTITY_NAMES=("aro-cluster" "${OPERATOR_IDENTITIES[@]}")
else
  IDENTITY_NAMES=("${OPERATOR_IDENTITIES[@]}")
fi

# Create identities if not existing
for ID_NAME in "${IDENTITY_NAMES[@]}"; do
  if az identity show --resource-group "$RESOURCE_GROUP" --name "$ID_NAME" >/dev/null 2>&1; then
    echo "ℹ️ Managed identity $ID_NAME already exists."
  else
    echo "🆔 Creating managed identity $ID_NAME..."
    az identity create --resource-group "$RESOURCE_GROUP" --name "$ID_NAME" --location "$LOCATION" >/dev/null
    echo "✅ Created managed identity $ID_NAME."
  fi
done

# Retrieve identity principal IDs
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
if [ "$USE_SYSTEM_IDENTITY" = false ]; then
  CLUSTER_PRINCIPAL_ID=$(az identity show --resource-group "$RESOURCE_GROUP" --name "aro-cluster" --query principalId -o tsv)
fi

declare -A PRINCIPAL_IDS
for id in "${OPERATOR_IDENTITIES[@]}"; do
  PRINCIPAL_IDS[$id]=$(az identity show --resource-group "$RESOURCE_GROUP" --name "$id" --query principalId -o tsv)
done

# Role definition IDs
ARO_FEDERATED_ROLE="ef318e2a-8334-4a05-9e4a-295a196c6a6e"        # Azure Red Hat OpenShift Federated Credential
ARO_CC_MANAGER_ROLE="a1f96423-95ce-4224-ab27-4e3dc72facd4"       # Azure Red Hat OpenShift Cloud Controller Manager
ARO_INGRESS_ROLE="0336e1d3-7a87-462b-b6db-342b63f7802c"          # Azure Red Hat OpenShift Cluster Ingress Operator
ARO_MACHINEAPI_ROLE="0358943c-7e01-48ba-8889-02cc51d78637"       # Azure Red Hat OpenShift Machine API Operator
ARO_NETWORK_ROLE="be7a6435-15ae-4171-8f30-4a343eff9e8f"          # Azure Red Hat OpenShift Network Operator
ARO_FILE_ROLE="0d7aedc0-15fd-4a67-a412-efad370c947e"             # Azure Red Hat OpenShift File Storage Operator
ARO_IMAGE_ROLE="8b32b316-c2f5-4ddf-b05b-83dacd2d08b5"            # Azure Red Hat OpenShift Image Registry Operator
ARO_SERVICE_ROLE="4436bae4-7702-4c84-919b-c4069ff25ee2"          # Azure Red Hat OpenShift Service Operator
NETWORK_CONTRIB_ROLE="4d97b98b-1d4f-4787-a291-c67834d212e7"      # Network Contributor (built-in)

# Assign federated credential role to cluster identity for each operator identity
if [ "$USE_SYSTEM_IDENTITY" = false ]; then
  for id in "${OPERATOR_IDENTITIES[@]}"; do
    assign_role "$CLUSTER_PRINCIPAL_ID" "$ARO_FEDERATED_ROLE" "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ManagedIdentity/userAssignedIdentities/$id" "'Federated Credential' role to aro-cluster on $id"
  done
fi

# Assign built-in ARO operator roles to each identity on required scope
assign_role "${PRINCIPAL_IDS[cloud-controller-manager]}" "$ARO_CC_MANAGER_ROLE" "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/$VNET_NAME/subnets/$MASTER_SUBNET" "'Cloud Controller Manager' role to cloud-controller-manager (master subnet)"
assign_role "${PRINCIPAL_IDS[cloud-controller-manager]}" "$ARO_CC_MANAGER_ROLE" "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/$VNET_NAME/subnets/$WORKER_SUBNET" "'Cloud Controller Manager' role to cloud-controller-manager (worker subnet)"

assign_role "${PRINCIPAL_IDS[ingress]}" "$ARO_INGRESS_ROLE" "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/$VNET_NAME/subnets/$MASTER_SUBNET" "'Cluster Ingress Operator' role to ingress (master subnet)"
assign_role "${PRINCIPAL_IDS[ingress]}" "$ARO_INGRESS_ROLE" "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/$VNET_NAME/subnets/$WORKER_SUBNET" "'Cluster Ingress Operator' role to ingress (worker subnet)"

assign_role "${PRINCIPAL_IDS[machine-api]}" "$ARO_MACHINEAPI_ROLE" "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/$VNET_NAME/subnets/$MASTER_SUBNET" "'Machine API Operator' role to machine-api (master subnet)"
assign_role "${PRINCIPAL_IDS[machine-api]}" "$ARO_MACHINEAPI_ROLE" "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/$VNET_NAME/subnets/$WORKER_SUBNET" "'Machine API Operator' role to machine-api (worker subnet)"

assign_role "${PRINCIPAL_IDS[aro-operator]}" "$ARO_SERVICE_ROLE" "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/$VNET_NAME/subnets/$MASTER_SUBNET" "'Service Operator' role to aro-operator (master subnet)"
assign_role "${PRINCIPAL_IDS[aro-operator]}" "$ARO_SERVICE_ROLE" "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/$VNET_NAME/subnets/$WORKER_SUBNET" "'Service Operator' role to aro-operator (worker subnet)"

assign_role "${PRINCIPAL_IDS[cloud-network-config]}" "$ARO_NETWORK_ROLE" "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/$VNET_NAME" "'Network Operator' role to cloud-network-config (VNet)"
assign_role "${PRINCIPAL_IDS[file-csi-driver]}" "$ARO_FILE_ROLE" "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/$VNET_NAME" "'File Storage Operator' role to file-csi-driver (VNet)"
assign_role "${PRINCIPAL_IDS[image-registry]}" "$ARO_IMAGE_ROLE" "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/$VNET_NAME" "'Image Registry Operator' role to image-registry (VNet)"

# Grant ARO service principal network contributor on VNet
RP_SP_OBJECT_ID=$(az ad sp list --display-name "Azure Red Hat OpenShift RP" --query "[0].id" -o tsv)
assign_role "$RP_SP_OBJECT_ID" "$NETWORK_CONTRIB_ROLE" "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/$VNET_NAME" "'Network Contributor' role to Azure Red Hat OpenShift RP service principal (VNet)"

# ------------------------------
# Step 6: Pull Secret
# ------------------------------
echo "🔑 Please obtain your Red Hat pull secret from https://console.redhat.com/openshift/install/pull-secret"
read -s -p "Paste your pull secret and press enter: " PULL_SECRET
echo

# ------------------------------
# Step 7: Create ARO Cluster
# ------------------------------
echo "🚀 Creating ARO cluster version $ARO_VERSION..."
if [ "$USE_SYSTEM_IDENTITY" = true ]; then
  az aro create --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" \
    --vnet "$VNET_NAME" --master-subnet "$MASTER_SUBNET" --worker-subnet "$WORKER_SUBNET" \
    --location "$LOCATION" --pull-secret "$PULL_SECRET" --cluster-resource-group "${CLUSTER_NAME}-infra" \
    --version "$ARO_VERSION" --master-vm-size "$MASTER_VM_SIZE" --worker-vm-size "$WORKER_VM_SIZE" \
    --enable-managed-identity \
    --assign-platform-workload-identity cloud-controller-manager cloud-controller-manager \
    --assign-platform-workload-identity ingress ingress \
    --assign-platform-workload-identity machine-api machine-api \
    --assign-platform-workload-identity disk-csi-driver disk-csi-driver \
    --assign-platform-workload-identity file-csi-driver file-csi-driver \
    --assign-platform-workload-identity cloud-network-config cloud-network-config \
    --assign-platform-workload-identity image-registry image-registry \
    --assign-platform-workload-identity aro-operator aro-operator
else
  az aro create --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" \
    --vnet "$VNET_NAME" --master-subnet "$MASTER_SUBNET" --worker-subnet "$WORKER_SUBNET" \
    --location "$LOCATION" --pull-secret "$PULL_SECRET" --cluster-resource-group "${CLUSTER_NAME}-infra" \
    --version "$ARO_VERSION" --master-vm-size "$MASTER_VM_SIZE" --worker-vm-size "$WORKER_VM_SIZE" \
    --enable-managed-identity --assign-cluster-identity aro-cluster \
    --assign-platform-workload-identity cloud-controller-manager cloud-controller-manager \
    --assign-platform-workload-identity ingress ingress \
    --assign-platform-workload-identity machine-api machine-api \
    --assign-platform-workload-identity disk-csi-driver disk-csi-driver \
    --assign-platform-workload-identity file-csi-driver file-csi-driver \
    --assign-platform-workload-identity cloud-network-config cloud-network-config \
    --assign-platform-workload-identity image-registry image-registry \
    --assign-platform-workload-identity aro-operator aro-operator
fi

# ------------------------------
# Step 8: Wait for cluster to be Ready
# ------------------------------
echo "⏳ Waiting for ARO cluster to reach 'Succeeded' state before upgrade..."
for i in {1..60}; do
  STATUS=$(az aro show --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" --query "provisioningState" -o tsv)
  if [[ "$STATUS" == "Succeeded" ]]; then
    echo "✅ Cluster is ready. Proceed with manual upgrade."
    break
  fi
  echo "⏱️  [$i/60] Current status: $STATUS... waiting 30s"
  sleep 30
done

STATUS=$(az aro show --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" --query "provisioningState" -o tsv)
if [[ "$STATUS" != "Succeeded" ]]; then
  echo "❌ Cluster did not reach 'Succeeded' state. Current state: $STATUS"
  exit 1
fi

echo "🔄 Log into the OpenShift Console (OCP portal) to verify the cluster, then perform any required post-deployment steps (e.g., upgrade OpenShift version, install operators)."
