# Azure Red Hat OpenShift (ARO) Cluster Deployment Guide with Retry and Monitoring

## Overview

This guide explains how to deploy an Azure Red Hat OpenShift (ARO) 4.18+ cluster into the **West US 3** region using Azure CLI and Cloud Shell, with automatic retries and live monitoring. It also includes post-deployment health checks for:

- OpenShift Virtualization Operator
- Migration Toolkit for Virtualization (MTV)
- Required MTV Custom Resource Definitions (CRDs)

---

## Components

| Component         | Value            |
|------------------|------------------|
| Resource Group    | AroVirtL300       |
| Cluster Name      | aro-cluster       |
| Virtual Network   | aro-vnet          |
| OpenShift Version | 4.18+             |
| VM Size           | Standard_D8s_v5   |

---

## Files Required

| File Name                                    | Purpose                                 |
|----------------------------------------------|-----------------------------------------|
| `deploy_aro_cluster_validated.sh`            | Core deployment script                  |
| `aro_operator_health_check_with_logging.sh`  | Health check for operator readiness     |
| `deploy_and_monitor_aro_with_retry.sh`       | Wrapper script with retry and logging   |

---

## Step-by-Step Instructions

### 1. Upload and Prepare Scripts in Azure Cloud Shell

Place all three files in your Cloud Shell directory and make them executable:

```bash
chmod +x deploy_aro_cluster_validated.sh
chmod +x aro_operator_health_check_with_logging.sh
chmod +x deploy_and_monitor_aro_with_retry.sh
```

---

### 2. Run the Deployment + Monitoring Script

Launch the deployment process with retries and health checks:

```bash
./deploy_and_monitor_aro_with_retry.sh
```

This script will:

- Run `deploy_aro_cluster_validated.sh`
- Monitor the deployment every 60 seconds
- Automatically retry up to 3 times if provisioning fails
- Log all output to `aro_deployment_<timestamp>.log`
- After success, run the health check script to:
  - Wait for operators to install and stabilize
  - Check for required MTV CRDs
  - Report errors to screen and log

---

### 3. VM Size Configuration

This deployment uses the **Standard_D8s_v5** VM series, optimized for balanced compute and memory. It is explicitly defined in the ARO create command:

```bash
--master-vm-size Standard_D8s_v5 \
--worker-vm-size Standard_D8s_v5
```

---

### 4. Verify ARO Deployment Status

After deployment, verify success with:

```bash
az aro show -g AroVirtL300 -n aro-cluster --query provisioningState -o tsv
```

Expected output:

```
Succeeded
```

---

### 5. Operator Health Check Breakdown

The health check script:

- Waits for `kubevirt-hyperconverged` and `migration-operator` to become healthy
- Confirms `HyperConverged` CR reaches `Available`
- Lists CSVs and pod status in each namespace
- Verifies presence of:
  - `virtmigrationplans.mtv.openshift.io`
  - `migrationcontrollers.mtv.openshift.io`
  - `plans.migration.openshift.io`
  - `providers.migration.openshift.io`

Results are saved in:

```
aro_operator_health_<timestamp>.log
```

---

## References

- [ARO Quickstart CLI Guide](https://review.learn.microsoft.com/en-us/azure/openshift/create-cluster?branch=main&pivots=aro-azure-cli)
- [OpenShift Virtualization Guide](https://review.learn.microsoft.com/en-us/azure/openshift/howto-create-openshift-virtualization?branch=main)
- [Migration Toolkit for Virtualization (MTV)](https://docs.redhat.com/en/documentation/migration_toolkit_for_virtualization/2.8)

