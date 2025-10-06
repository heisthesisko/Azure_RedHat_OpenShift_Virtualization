# Creating Migration plans and moving VM's from VMware to Azure RedHat OpenShift Visualization clusters

```mermaid
sequenceDiagram
  participant Admin
  participant VMware
  participant MTV
  participant ARO

  Admin->>VMware: Verify provider connectivity
  Admin->>MTV: Add VMware provider (URL, creds)
  MTV->>VMware: Validate connection
  VMware-->>MTV: Inventory OK

  Admin->>MTV: Create migration plan (select VMs)
  MTV->>ARO: Check target resources
  MTV-->>Admin: Report dependencies
  Admin->>MTV: Resolve dependencies

  Admin->>MTV: Start migration
  MTV->>VMware: Copy data (warm/cold)
  VMware-->>MTV: Snapshots / disks exported
  MTV->>ARO: Import disks and create VMs
  ARO-->>MTV: VMs created / started
  MTV-->>Admin: Migration complete
```

## Create a Migration plan

1. Log intoOpenShift Console and navigate to Migration for Virtulization -> Migration Plans

![Module 6 Section 1 imageA](assets/images/mod06/MigrateVMs-001.png)

2. Create a migration plan by clicking Create Plan control in right corner

![Module 6 Section 1 imageB](assets/images/mod06/MigrateVMs-002.png)

3. Fill out the form as in the image, click Next

![Module 6 Section 1 imageC](assets/images/mod06/MigrateVMs-003.png)

4. 
![Module 6 Section 1 imageC](assets/images/mod06/MigrateVMs-003.png)

1. On the details page, upper right corner click on the Create migration plan control

![Module 6 Section 1 imageD](assets/images/mod06/MigrateVMs-004.png)

5. In the plan information fill out the Plan name, in our case **contosovms**, for lab work leave the rest of values as is, blank in some cases. Click Next

![Module 6 Section 1 imageE](assets/images/mod06/MigrateVMs-005.png)