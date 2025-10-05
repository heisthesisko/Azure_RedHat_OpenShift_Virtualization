# Module workflow

```mermaid
flowchart TD
  A[Start] --> B[Login to OpenShift Portal]
  B --> C[Install ACM Operator]
  C --> D[Install MTV Operator]
  D --> E[Install Virtualization Operator]
  E --> F[End]
```



> [!NOTE] 
> The steps in this module assume that your OpenShift cluster version is at 4.18.24 or greater.

## Installing OpenShift Operators

1. Login into the OpenShift Portal and go to Operators->Operator Hub

![Module 3 Section 1 imageA](assets/images/mod03/InstallOperators-001.png)

2. In the search control, type Advanced, you will see the option for Advanced Cluster Management for Kubernetes, click on the tile to launch the pop-up window

![Module 3 Section 1 imageB](assets/images/mod03/InstallOperators-002.png)

3. Choose your Channel and Version values (defaults to latest) Click Install

![Module 3 Section 1 imageC](assets/images/mod03/InstallOperators-003.png)

4. Select or change values for your isntallation, in our case we will leave everything at the deafult settings and values. Click Install at the bottom

![Module 3 Section 1 imageD](assets/images/mod03/InstallOperators-004.png)

The install process will start and follow any additional workflow requests if needed. Once finished you will see the Operator was installed.

![Module 3 Section 1 imageE](assets/images/mod03/InstallOperators-005.png)
![Module 3 Section 1 imageF](assets/images/mod03/InstallOperators-006.png)
![Module 3 Section 1 imageG](assets/images/mod03/InstallOperators-007.png)

## Installing Migration Toolkit for Virtualization operator

