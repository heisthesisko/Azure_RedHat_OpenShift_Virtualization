# Azure Red Hat OpenShift (ARO) 4.17+ Deployment Guide (Managed Identity Storage Authentication)

This guide provides a **step-by-step walkthrough** for deploying an Azure Red Hat OpenShift (ARO) cluster using an interactive deployment script.  
This variant uses **Azure AD and managed identities** for storage authentication instead of storage account keys, improving security and aligning with Azure’s recommended approach.

## ⚙️ Prerequisites
- Azure CLI >= 2.67.0
- Logged in with az login and Owner or Contributor + User Access Administrator
- Red Hat pull secret from console.redhat.com

## 🚀 Step-by-Step Instructions
1. unzip deploy_aro_cluster_managedid_package.zip
2. cd deploy_aro_cluster_managedid_package
3. chmod +x deploy_aro_cluster_managedid.sh
4. ./deploy_aro_cluster_managedid.sh

The script will: register providers, create RG, VNet, Storage account (shared key disabled), managed identities, assign roles, and deploy the ARO cluster.

## 📊 Architecture Diagram
```mermaid
flowchart TD
    A[Azure Subscription] --> B[Resource Group]
    B --> C[VNET 10.0.0.0/22]
    C --> C1[Master Subnet 10.0.0.0/23]
    C --> C2[Worker Subnet 10.0.2.0/23]
    B --> D[Storage Account (Shared Key Disabled)]
    D --> D1[Blob Container for ARO]
    B --> E[ARO Cluster]
    E --> E1[Master Nodes]
    E --> E2[Worker Nodes]
    E --> F[OCP Portal]
```

## 🛠️ Troubleshooting
- Ensure correct CLI version and roles
- Quota errors: request more cores
- Invalid pull secret: check JSON
- Cluster stuck: verify region and quotas

## ✅ Post-Deployment Tasks
- Log into OCP portal
- Upgrade cluster if needed
- Install operators

## Reference Content

https://learn.microsoft.com/en-us/azure/openshift/howto-create-openshift-cluster?source=recommendations&pivots=aro-az-cli
https://learn.microsoft.com/en-us/azure/openshift/howto-upgrade-aro-openshift-cluster#set-the-upgradeable-to-annotation-on-the-azure-red-hat-openshift-clusters-cloudcredential-resource