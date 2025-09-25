#!/bin/bash

set -euo pipefail

# ============================================================================
# ARO Deployment with Tag Inheritance from Resource Group (Azure Policy)
# - Prompts for RG/cluster/VM sizes like the original
# - Creates/updates a custom Azure Policy that copies selected tags
#   from the Resource Group onto ALL resources in that RG
# - Assigns that policy at RG scope immediately after RG creation
# - Fix: blob container uses --metadata (not Azure Resource tags)
# ============================================================================

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
# Tagging / Policy configuration
# ------------------------------
# Provide default RG tags (space-separated key=value)
# You can edit this list or answer prompts later to add/override.
DEFAULT_RG_TAGS=("Environment=Test")

# Which tag keys should be inherited by resources in this RG?
# This list is used to BUILD a safer "modify" policy that adds/replaces only these keys.
INHERIT_TAG_KEYS=("SecurityControl=Ignore")

# Policy definition name & assignment name
POLICY_DEF_NAME="Inherit-RG-Tags-SelectedKeys"
POLICY_ASSIGN_NAME="Inherit-RG-Tags-Assignment"

# ------------------------------
# Functions
# ------------------------------
register_provider() {
  local provider=$1
  echo "🔧 Registering $provider..."
  az provider register --namespace "$provider" >/dev/null
  for i in {1..12}; do
    STATUS=$(az provider show --namespace "$provider" --query "registrationState" -o tsv)
    if [[ "$STATUS" == "Registered" ]]; then
      echo "✅ $provider is registered."
      return 0
    fi
    echo "⏳ Waiting for $provider to register... ($i/12)"
    sleep 10
  done
  echo "❌ Failed to register $provider within timeout."
  exit 1
}

ensure_rg_exists() {
  echo "📦 Creating resource group $RESOURCE_GROUP in $LOCATION..."
  az group create --name "$RESOURCE_GROUP" --location "$LOCATION" >/dev/null
  echo "✅ Resource group ensured: $RESOURCE_GROUP"
}

apply_rg_tags() {
  # Merge any existing tags with desired tags, then apply
  echo "🏷️  Applying default tags to resource group (if missing): ${DEFAULT_RG_TAGS[*]}"
  local set_expr=()
  for kv in "${DEFAULT_RG_TAGS[@]}"; do
    key="${kv%%=*}"
    val="${kv#*=}"
    set_expr+=( "tags.${key}=${val}" )
  done
  az group update --name "$RESOURCE_GROUP" --set "${set_expr[@]}"
  echo "✅ Tags applied to resource group."
}

create_or_update_policy_definition() {
  echo "🛡️  Creating/updating custom policy definition to inherit specific tag keys..."

  # Resolve role definition ID for 'Resource Policy Contributor' (required for modify effect)
  local rpc_role_id
  rpc_role_id=$(az role definition list --name "Resource Policy Contributor" --query "[0].id" -o tsv)
  if [[ -z "$rpc_role_id" ]]; then
    echo "❌ Could not resolve 'Resource Policy Contributor' role definition ID. Ensure you have sufficient permissions."
    exit 1
  fi

  # Build operations JSON for each tag key
  # Example operation:
  # {
  #   "operation": "addOrReplace",
  #   "field": "tags['Environment']",
  #   "value": "[resourceGroup().tags['Environment']]"
  # }
  ops="["
  first=1
  for key in "${INHERIT_TAG_KEYS[@]}"; do
    if [[ $first -eq 0 ]]; then ops+=", "; fi
    ops+="{\"operation\":\"addOrReplace\",\"field\":\"tags['${key}']\",\"value\":\"[resourceGroup().tags['${key}']]\"}"
    first=0
  done
  ops+="]"

  # Write policy JSON to a temp file
  policy_file="$(mktemp)"
  cat > "$policy_file" <<EOF
{
  "properties": {
    "displayName": "Inherit selected tags from the resource group",
    "policyType": "Custom",
    "mode": "Indexed",
    "description": "Add or replace specific tag keys on resources with the values from the parent resource group.",
    "metadata": { "category": "Tags" },
    "policyRule": {
      "if": {
        "allOf": [
          { "field": "type", "notEquals": "Microsoft.Resources/subscriptions/resourceGroups" }
        ]
      },
      "then": {
        "effect": "modify",
        "details": {
          "roleDefinitionIds": [ "${rpc_role_id}" ],
          "operations": ${ops}
        }
      }
    }
  }
}
EOF

  # Create or update the policy definition
  if az policy definition show --name "$POLICY_DEF_NAME" >/dev/null 2>&1; then
    az policy definition update --name "$POLICY_DEF_NAME" --rules "$policy_file" --mode Indexed >/dev/null
  else
    az policy definition create --name "$POLICY_DEF_NAME" --display-name "Inherit selected tags from the resource group" --rules "$policy_file" --mode Indexed >/dev/null
  fi

  rm -f "$policy_file"
  echo "✅ Policy definition ready: $POLICY_DEF_NAME"
}

assign_policy_to_rg() {
  echo "🔗 Assigning policy to RG scope so new resources inherit RG tags..."
  local scope
  scope=$(az group show --name "$RESOURCE_GROUP" --query id -o tsv)

  # Create or update assignment
  if az policy assignment show --name "$POLICY_ASSIGN_NAME" --scope "$scope" >/dev/null 2>&1; then
    az policy assignment delete --name "$POLICY_ASSIGN_NAME" --scope "$scope" >/dev-null 2>&1 || true
  fi

  az policy assignment create \
    --name "$POLICY_ASSIGN_NAME" \
    --scope "$scope" \
    --policy "$POLICY_DEF_NAME" >/dev/null

  echo "✅ Policy assignment created at scope: $scope"
}

# ------------------------------
# Step 1: Register providers
# ------------------------------
for provider in Microsoft.RedHatOpenShift Microsoft.Network Microsoft.Compute Microsoft.Storage Microsoft.Authorization; do
  register_provider "$provider"
done

# ------------------------------
# Step 2: Create resource group and apply tags
# ------------------------------
ensure_rg_exists
apply_rg_tags

# ------------------------------
# Step 3: Policy setup and assignment
# ------------------------------
create_or_update_policy_definition
assign_policy_to_rg

# ------------------------------
# Step 4: VNET + Subnets
# ------------------------------
echo "🌐 Creating virtual network..."
az network vnet create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VNET_NAME" \
  --address-prefixes "$VNET_ADDRESS_PREFIX" \
  --subnet-name "$MASTER_SUBNET" \
  --subnet-prefix "$MASTER_SUBNET_PREFIX" >/dev/null

echo "📶 Creating worker subnet..."
az network vnet subnet create \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --name "$WORKER_SUBNET" \
  --address-prefix "$WORKER_SUBNET_PREFIX" >/dev/null

# ------------------------------
# Step 5: Storage (Shared Key Enabled)
# ------------------------------
echo "📦 Creating storage account $STORAGE_ACCOUNT_NAME (Shared Key Enabled)..."
az storage account create \
  --name "$STORAGE_ACCOUNT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --allow-shared-key-access true \
  --enable-hierarchical-namespace true \
  --tags "SecurityControl=Ignore" >/dev/null

# Get storage key
ACCOUNT_KEY=$(az storage account keys list --resource-group "$RESOURCE_GROUP" --account-name "$STORAGE_ACCOUNT_NAME" --query "[0].value" -o tsv)

echo "📂 Creating blob container $CONTAINER_NAME using account key..."
# NOTE: blob containers do not support Azure Resource Tags, use metadata instead
az storage container create \
  --name "$CONTAINER_NAME" \
  --account-name "$STORAGE_ACCOUNT_NAME" \
  --account-key "$ACCOUNT_KEY" \
  --metadata "SecurityControl=Ignore" >/dev/null

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
az aro create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CLUSTER_NAME" \
  --vnet "$VNET_NAME" \
  --master-subnet "$MASTER_SUBNET" \
  --worker-subnet "$WORKER_SUBNET" \
  --location "$LOCATION" \
  --pull-secret "$PULL_SECRET" \
  --cluster-resource-group "${CLUSTER_NAME}-infra" \
  --version "$ARO_VERSION" \
  --master-vm-size "$MASTER_VM_SIZE" \
  --worker-vm-size "$WORKER_VM_SIZE" \
  --tags "SecurityControl=Ignore"

# ------------------------------
# Step 8: Wait for cluster
# ------------------------------
echo "⏳ Waiting for ARO cluster to reach 'Succeeded' state before upgrade..."
for i in {1..60}; do
  STATUS=$(az aro show --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" --query provisioningState -o tsv)
  if [[ "$STATUS" == "Succeeded" ]]; then
    echo "✅ Cluster is ready. Proceed with manual upgrade."
    break
  fi
  echo "⏱️  [$i/60] Current status: $STATUS... waiting 30s"
  sleep 30
done

STATUS=$(az aro show --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" --query provisioningState -o tsv)
if [[ "$STATUS" != "Succeeded" ]]; then
  echo "❌ Cluster is not ready for upgrade. Current state: $STATUS"
  exit 1
fi

echo "🔄 Log into OCP Portal to manually upgrade the cluster and install operators for virtualization."
