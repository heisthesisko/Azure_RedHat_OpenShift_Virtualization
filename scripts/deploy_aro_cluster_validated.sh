#!/bin/bash

set -e

RESOURCE_GROUP="AroVirtLab"
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
    echo "✅ Cluster is ready. Proceeding with upgrade."
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

echo "🔄 Upgrading ARO cluster to version 4.18.17"
az aro update \
  --name $CLUSTER_NAME \
  --resource-group $RESOURCE_GROUP \
  --version 4.18.17

echo "✅ Upgrade initiated. Monitor the ARO cluster in Azure Portal or with 'az aro show'."



# Step 8: Validate OpenShift version before installing operators
echo "🔍 Checking OpenShift version after upgrade..."
CLUSTER_VERSION=$(oc get clusterversion version -o jsonpath='{.status.desired.version}')
echo "📘 OpenShift version is $CLUSTER_VERSION"

if [[ "$CLUSTER_VERSION" < "4.18.17" ]]; then
  echo "❌ Cluster version is not 4.18 or higher. Aborting operator installation."
  exit 1
fi

# Check ClusterOperators are all Available=True
echo "🔍 Validating cluster health..."
UNAVAILABLE=$(oc get co | grep -v 'Available *True' | grep -v 'NAME' | wc -l)
if [ "$UNAVAILABLE" -ne 0 ]; then
  echo "❌ Some ClusterOperators are not available. Check 'oc get co'. Aborting."
  oc get co
  exit 1
fi

echo "✅ Cluster is healthy and upgraded to 4.18+. Proceeding with operator installs."

# Step 8: Install OpenShift Virtualization (KubeVirt) Operator
echo "📦 Installing OpenShift Virtualization Operator..."
oc new-project openshift-cnv || true

cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: openshift-virtualization
  namespace: openshift-cnv
spec:
  targetNamespaces:
  - openshift-cnv
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: kubevirt-hyperconverged
  namespace: openshift-cnv
spec:
  channel: stable
  name: kubevirt-hyperconverged
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

# Step 9: Install Migration Toolkit for Virtualization (MTV) Operator
echo "📦 Installing Migration Toolkit for Virtualization (MTV) Operator..."
oc new-project openshift-mtv || true

cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: mtv-operator-group
  namespace: openshift-mtv
spec:
  targetNamespaces:
  - openshift-mtv
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: migration-operator
  namespace: openshift-mtv
spec:
  channel: stable
  name: migration-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

echo "✅ Operators applied. Use 'oc get csv -n openshift-cnv' and 'oc get csv -n openshift-mtv' to monitor readiness."


# Step 10: Retry loop for healthy OpenShift version and operators
echo "🔄 Ensuring cluster remains healthy before applying CRs..."
for i in {1..20}; do
  CLUSTER_VERSION=$(oc get clusterversion version -o jsonpath='{.status.desired.version}')
  UNAVAILABLE=$(oc get co | grep -v 'Available *True' | grep -v 'NAME' | wc -l)
  if [[ "$CLUSTER_VERSION" =~ ^4\.18.*$ && "$UNAVAILABLE" -eq 0 ]]; then
    echo "✅ Cluster version is $CLUSTER_VERSION and all ClusterOperators are healthy."
    break
  fi
  echo "⏳ [$i/20] Version: $CLUSTER_VERSION, Unavailable Operators: $UNAVAILABLE. Retrying in 30s..."
  sleep 30
done

if [[ "$CLUSTER_VERSION" != 4.18* || "$UNAVAILABLE" -ne 0 ]]; then
  echo "❌ Cluster not ready after retries. Exiting."
  exit 1
fi

# Step 11: Apply HyperConverged CR for OpenShift Virtualization
echo "📦 Creating HyperConverged CR..."
cat <<EOF | oc apply -f -
apiVersion: hco.kubevirt.io/v1beta1
kind: HyperConverged
metadata:
  name: kubevirt-hyperconverged
  namespace: openshift-cnv
spec: {}
EOF

# Step 12: Apply MigrationController CR for MTV
echo "📦 Creating MigrationController CR..."
cat <<EOF | oc apply -f -
apiVersion: migration.openshift.io/v1alpha1
kind: MigrationController
metadata:
  name: migration-controller
  namespace: openshift-mtv
spec: {}
EOF

echo "✅ Operator CRs deployed. Use 'oc get hyperconverged -n openshift-cnv' and 'oc get migrationcontroller -n openshift-mtv' to monitor readiness."