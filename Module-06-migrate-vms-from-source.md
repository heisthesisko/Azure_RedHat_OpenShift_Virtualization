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

4. In the Search control, filter by **Contoso**, this will provide a quick way to search the VM inventory to choose from

![Module 6 Section 1 imageD](assets/images/mod06/MigrateVMs-004.png)
![Module 6 Section 1 imageE](assets/images/mod06/MigrateVMs-005.png)

5. On Network map, choose a new network map for lab purposes, leave values that are prefilled or blank and click Next.

![Module 6 Section 1 imageF](assets/images/mod06/MigrateVMs-006.png)

6. On Storage map, choose a new storage map for lab purposes, leave values that are prefilled or blank and click Next.

![Module 6 Section 1 imageG](assets/images/mod06/MigrateVMs-007.png)

7. Migration type for lab work, leave as Cold Migration

![Module 6 Section 1 imageH](assets/images/mod06/MigrateVMs-008.png)

8. Additional Setup we will not change anything, however notice you can click to preserve static IP's

![Module 6 Section 1 imageI](assets/images/mod06/MigrateVMs-009.png)

1. Hooks we will not change anything, however notice you can add a Pre and Post hook to the VM migration, such as:

**Pre-Migration**
```yml
- hosts: vms
  tasks:
    - name: Stop MariaDB
      service:
        name: mariadb
        state: stopped
    - name: Create marker file
      copy:
        dest: /tmp/pre_migration.txt
        content: "Pre-migration complete"
```

**Post-Migration**
```yaml
- hosts: vms
  gather_facts: no
  tasks:
    - name: Download Azure Arc onboarding script
      get_url:
        url: https://aka.ms/AzureArcAgentScript
        dest: /tmp/install_arc_agent.sh
        mode: '0755'

    - name: Run Azure Arc onboarding script
      shell: |
        /tmp/install_arc_agent.sh \
          --resource-group "my-rg" \
          --subscription-id "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" \
          --location "eastus" \
          --tenant-id "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" \
          --tags "env=prod" \
          --no-proxy
```

![Module 6 Section 1 imageJ](assets/images/mod06/MigrateVMs-010.png)

9. Review and Create Plan

![Module 6 Section 1 imageK](assets/images/mod06/MigrateVMs-011.png)

10. Start Plan

![Module 6 Section 1 imageL](assets/images/mod06/MigrateVMs-012.png)
![Module 6 Section 1 imageM](assets/images/mod06/MigrateVMs-013.png)

11. Monitor progress by going to the Virtual Machines Tab on the migration plan to see progress

![Module 6 Section 1 imageN](assets/images/mod06/MigrateVMs-014.png)

12. Once completed you should see a similar result as below:

![Module 6 Section 1 imageO](assets/images/mod06/MigrateVMs-015.png)