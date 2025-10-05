# Creating Migration plans and moving VM's from VMware to Azure RedHat OpenShift Visualization clusters

```mermaid
sequenceDiagram
  autonumber
  participant Admin
  participant vCenter as VMware vCenter/ESXi
  participant MTV as MTV (Migration Toolkit for Virtualization)
  participant ARO as ARO Cluster (OpenShift Virtualization)

  Admin->>vCenter: Ensure provider connectivity\n(FW/DNS/ports reachable)
  Admin->>MTV: Add VMware provider\n(URL, credentials, thumbprint)
  MTV->>vCenter: Validate connection & discover inventory
  vCenter-->>MTV: OK (clusters, networks, VMs)

  Admin->>MTV: Create Migration Plan\n(choose VMs, target ns/storage)
  MTV->>ARO: Assess target resources & mappings
  MTV-->>Admin: Report dependencies\n(networks, storage, OS tools)

  Admin->>MTV: Resolve dependencies\n(map networks/storage, pre-reqs)
  Admin->>MTV: Start Migration
  MTV->>vCenter: Orchestrate data copy (warm/cold)
  vCenter-->>MTV: Snapshot/export disks & metadata
  MTV->>ARO: Import disks; create KubeVirt VM defs
  ARO-->>MTV: VMs created/started
  MTV-->>Admin: Migration complete
```