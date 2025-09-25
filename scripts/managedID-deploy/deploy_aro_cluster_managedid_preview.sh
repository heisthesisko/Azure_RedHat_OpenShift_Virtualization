#!/bin/bash
set -e

# ------------------------------
# Prompt user for input
# ------------------------------
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
# Step 1: Register providers
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
# Step 3: Networking
# ------------------------------
echo "🌐 Creating virtual network $VNET_NAME..."
az network vnet create --resource-group "$RESOURCE_GROUP" --name "$VNET_NAME"   --address-prefixes "$VNET_ADDRESS_PREFIX" --subnet-name "$MASTER_SUBNET" --subnet-prefix "$MASTER_SUBNET_PREFIX" >/dev/null

echo "📶 Creating worker subnet $WORKER_SUBNET..."
az network vnet subnet create --resource-group "$RESOURCE_GROUP" --vnet-name "$VNET_NAME"   --name "$WORKER_SUBNET" --address-prefix "$WORKER_SUBNET_PREFIX" >/dev/null

# ------------------------------
# Step 4: Storage
# ------------------------------
echo "📦 Creating storage account $STORAGE_ACCOUNT_NAME (Shared Key Disabled)..."
az storage account create --name "$STORAGE_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP" --location "$LOCATION"   --sku Standard_LRS --kind StorageV2 --min-tls-version TLS1_2   --allow-blob-public-access false --allow-shared-key-access false --enable-hierarchical-namespace true

echo "📂 Creating blob container $CONTAINER_NAME using Azure AD login..."
az storage container-rm create --resource-group "$RESOURCE_GROUP" --storage-account "$STORAGE_ACCOUNT_NAME" --name "$CONTAINER_NAME" >/dev/null

# ------------------------------
# Step 5: Managed Identities
# ------------------------------
CLUSTER_IDENTITY_NAME="${CLUSTER_NAME}-identity"
if az identity show --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_IDENTITY_NAME" >/dev/null 2>&1; then
  echo "ℹ️ Cluster managed identity $CLUSTER_IDENTITY_NAME already exists."
else
  echo "🆔 Creating cluster managed identity $CLUSTER_IDENTITY_NAME..."
  az identity create --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_IDENTITY_NAME" --location "$LOCATION" >/dev/null
  echo "✅ Created cluster managed identity $CLUSTER_IDENTITY_NAME."
fi

OPERATOR_IDENTITIES=(cloud-controller-manager ingress machine-api disk-csi-driver file-csi-driver cloud-network-config image-registry aro-operator)
for ID_NAME in "${OPERATOR_IDENTITIES[@]}"; do
  if az identity show --resource-group "$RESOURCE_GROUP" --name "$ID_NAME" >/dev/null 2>&1; then
    echo "ℹ️ Managed identity $ID_NAME already exists."
  else
    echo "🆔 Creating managed identity $ID_NAME..."
    az identity create --resource-group "$RESOURCE_GROUP" --name "$ID_NAME" --location "$LOCATION" >/dev/null
    echo "✅ Created managed identity $ID_NAME."
  fi
done

# Get IDs
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
CLUSTER_PRINCIPAL_ID=$(az identity show --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_IDENTITY_NAME" --query principalId -o tsv)
declare -A PRINCIPAL_IDS
for id in "${OPERATOR_IDENTITIES[@]}"; do
  PRINCIPAL_IDS[$id]=$(az identity show --resource-group "$RESOURCE_GROUP" --name "$id" --query principalId -o tsv)
done

# Role IDs
ARO_FEDERATED_ROLE="ef318e2a-8334-4a05-9e4a-295a196c6a6e"
ARO_CC_MANAGER_ROLE="a1f96423-95ce-4224-ab27-4e3dc72facd4"
ARO_INGRESS_ROLE="0336e1d3-7a87-462b-b6db-342b63f7802c"
ARO_MACHINEAPI_ROLE="0358943c-7e01-48ba-8889-02cc51d78637"
ARO_NETWORK_ROLE="be7a6435-15ae-4171-8f30-4a343eff9e8f"
ARO_FILE_ROLE="0d7aedc0-15fd-4a67-a412-efad370c947e"
ARO_IMAGE_ROLE="8b32b316-c2f5-4ddf-b05b-83dacd2d08b5"
ARO_SERVICE_ROLE="4436bae4-7702-4c84-919b-c4069ff25ee2"
NETWORK_CONTRIB_ROLE="4d97b98b-1d4f-4787-a291-c67834d212e7"

# Federated Credential
for id in "${OPERATOR_IDENTITIES[@]}"; do
  assign_role "$CLUSTER_PRINCIPAL_ID" "$ARO_FEDERATED_ROLE" "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ManagedIdentity/userAssignedIdentities/$id" "'Federated Credential' role to $CLUSTER_IDENTITY_NAME on $id"
done

# Operator roles
assign_role "${PRINCIPAL_IDS[cloud-controller-manager]}" "$ARO_CC_MANAGER_ROLE" "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/$VNET_NAME/subnets/$MASTER_SUBNET" "Cloud Controller Manager role (master subnet)"
assign_role "${PRINCIPAL_IDS[cloud-controller-manager]}" "$ARO_CC_MANAGER_ROLE" "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/$VNET_NAME/subnets/$WORKER_SUBNET" "Cloud Controller Manager role (worker subnet)"
assign_role "${PRINCIPAL_IDS[ingress]}" "$ARO_INGRESS_ROLE" "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/$VNET_NAME/subnets/$MASTER_SUBNET" "Ingress Operator role (master subnet)"
assign_role "${PRINCIPAL_IDS[ingress]}" "$ARO_INGRESS_ROLE" "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/$VNET_NAME/subnets/$WORKER_SUBNET" "Ingress Operator role (worker subnet)"
assign_role "${PRINCIPAL_IDS[machine-api]}" "$ARO_MACHINEAPI_ROLE" "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/$VNET_NAME/subnets/$MASTER_SUBNET" "Machine API role (master subnet)"
assign_role "${PRINCIPAL_IDS[machine-api]}" "$ARO_MACHINEAPI_ROLE" "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/$VNET_NAME/subnets/$WORKER_SUBNET" "Machine API role (worker subnet)"
assign_role "${PRINCIPAL_IDS[aro-operator]}" "$ARO_SERVICE_ROLE" "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/$VNET_NAME/subnets/$MASTER_SUBNET" "Service Operator role (master subnet)"
assign_role "${PRINCIPAL_IDS[aro-operator]}" "$ARO_SERVICE_ROLE" "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/$VNET_NAME/subnets/$WORKER_SUBNET" "Service Operator role (worker subnet)"
assign_role "${PRINCIPAL_IDS[cloud-network-config]}" "$ARO_NETWORK_ROLE" "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/$VNET_NAME" "Network Operator role (VNet)"
assign_role "${PRINCIPAL_IDS[file-csi-driver]}" "$ARO_FILE_ROLE" "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/$VNET_NAME" "File Storage Operator role (VNet)"
assign_role "${PRINCIPAL_IDS[image-registry]}" "$ARO_IMAGE_ROLE" "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/$VNET_NAME" "Image Registry Operator role (VNet)"

# ARO RP SP
RP_SP_OBJECT_ID=$(az ad sp list --display-name "Azure Red Hat OpenShift RP" --query "[0].id" -o tsv)
assign_role "$RP_SP_OBJECT_ID" "$NETWORK_CONTRIB_ROLE" "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/$VNET_NAME" "Network Contributor role to ARO RP service principal"

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
az aro create --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME"   --vnet "$VNET_NAME" --master-subnet "$MASTER_SUBNET" --worker-subnet "$WORKER_SUBNET"   --location "$LOCATION" --pull-secret "$PULL_SECRET" --cluster-resource-group "${CLUSTER_NAME}-infra"   --version "$ARO_VERSION" --master-vm-size "$MASTER_VM_SIZE" --worker-vm-size "$WORKER_VM_SIZE"   --enable-managed-identity   --assign-cluster-identity $CLUSTER_IDENTITY_NAME   --assign-platform-workload-identity cloud-controller-manager cloud-controller-manager   --assign-platform-workload-identity ingress ingress   --assign-platform-workload-identity machine-api machine-api   --assign-platform-workload-identity disk-csi-driver disk-csi-driver   --assign-platform-workload-identity file-csi-driver file-csi-driver   --assign-platform-workload-identity cloud-network-config cloud-network-config   --assign-platform-workload-identity image-registry image-registry   --assign-platform-workload-identity aro-operator aro-operator

# ------------------------------
# Step 8: Wait for Ready
# ------------------------------
echo "⏳ Waiting for ARO cluster to reach 'Succeeded'..."
for i in {1..60}; do
  STATUS=$(az aro show --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" --query provisioningState -o tsv)
  if [[ "$STATUS" == "Succeeded" ]]; then
    echo "✅ Cluster is ready."
    break
  fi
  echo "⏱️  [$i/60] Current status: $STATUS... waiting 30s"
  sleep 30
done
