Repository for guides and scripts to deploy ARO Virtualization clusters.

> [!IMPORTANT]  
> As of 10/8/2025 the highest OCP version deployed by Azure Resource Manager in 4.17.27, once deployed you must update the OCP channel to at least 4.18 to support Virtualization
> 
> ARO clusters nodes that will have the Virtualization Operator installed must have a minimum number of 8 cores assigned and use the Standard_DSv5 VM SKU's
> 
> ARO clusters that are upgraded to OCP version 4.19 channel can upgrade to Standard_DSv6 VM SKU's which support nvme drives

> [!NOTE] 
> The modules in this repository will guide through the following workflow
```mermaid
flowchart
 A[Mod-00: Deploy ARO management node] --> B{Choose deployment method}

  B -->|Managed identity| C[Mod-01a: Deploy ARO cluster with managed identity]
  B -->|Shared key access| D[Mod-01b:Deploy ARO cluster with shared key access]

  C --> E[Mod-02: Verify ARO cluster deployed and Post deployment actions]
  D --> E

  %% Post-deploy actions (can be done in parallel)
  E --> F[Mod-03: Deploy operators]
  E --> G[Mod-04: Integrate cluster with ACM]
  E --> H[Mod-05: Integrate cluster with VMware]

  %% Workload path after post-deploy setup
  F --> I{Workload path}
  G --> I
  H --> I

  I -->|Mod-06: Migrate VMs from source| J[Migrate VMs]
  I -->|Mod-07: Deploy greenfield VMs| K[Deploy greenfield VMs]
  %% Final step for both paths
  J --> L[Mod-08: Enable additional Azure services]
  K --> L
```
## References

- [ARO Quickstart CLI Guide](https://review.learn.microsoft.com/en-us/azure/openshift/create-cluster?branch=main&pivots=aro-azure-cli)
- [OpenShift Virtualization Guide](https://review.learn.microsoft.com/en-us/azure/openshift/howto-create-openshift-virtualization?branch=main)
- [Migration Toolkit for Virtualization (MTV)](https://docs.redhat.com/en/documentation/migration_toolkit_for_virtualization/2.8)


