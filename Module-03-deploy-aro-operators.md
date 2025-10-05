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

4. Select or change values for your installation, in our case we will leave everything at the deafult settings and values. Click Install at the bottom

![Module 3 Section 1 imageD](assets/images/mod03/InstallOperators-004.png)

The install process will start and follow any additional workflow requests if needed. Once finished you will see the Operator was installed.

![Module 3 Section 1 imageE](assets/images/mod03/InstallOperators-005.png)
![Module 3 Section 1 imageF](assets/images/mod03/InstallOperators-006.png)
![Module 3 Section 1 imageG](assets/images/mod03/InstallOperators-007.png)

## Installing Migration Toolkit for Virtualization operator

1. Go to Operators->Operator Hub. In the search control, type MTV, you will see the option for Migration Toolkit for Virtualization Operator, click on the tile to launch the pop-up window

![Module 3 Section 1 imageH](assets/images/mod03/InstallOperators-008.png)

2. Select or change values for your installation, in our case we will leave everything at the default settings and values. Click Install at the top

![Module 3 Section 1 imageI](assets/images/mod03/InstallOperators-009.png)

3. Fill out the workflow form, in our case leaving the default values, click install at the top

![Module 3 Section 1 imageJ](assets/images/mod03/InstallOperators-010.png)

During the workflow you will be required to Create a ForkLift Controller, click to proceed.

![Module 3 Section 1 imageK](assets/images/mod03/InstallOperators-011.png)

Leave the default values for our needs and click create

![Module 3 Section 1 imageL](assets/images/mod03/InstallOperators-012.png)

Forklift Controller created:

![Module 3 Section 1 imageM](assets/images/mod03/InstallOperators-013.png)

Once you create the first fork-lift controller you can navigate to the Details tab and see the Operator was installed:

![Module 3 Section 1 imageN](assets/images/mod03/InstallOperators-014.png)
![Module 3 Section 1 imageO](assets/images/mod03/InstallOperators-015.png)

## Installing Virtualization Operator

1. Go to Operators->Operator Hub. In the search control, type virt, several options appear, choose OpenShift Virtualization tile to launch the pop-up window

![Module 3 Section 1 imageP](assets/images/mod03/InstallOperators-016.png)

2. Select or change values for your installation, in our case we will leave everything at the default settings and values. Click Install at the top

![Module 3 Section 1 imageQ](assets/images/mod03/InstallOperators-017.png)

3. Fill out the workflow form, in our case leaving the default values, click install at the bottom

![Module 3 Section 1 imageR](assets/images/mod03/InstallOperators-018.png)
![Module 3 Section 1 imageS](assets/images/mod03/InstallOperators-019.png)

As part of the workflow you wil need to Create HyperConverged, click to proceed

![Module 3 Section 1 imageT](assets/images/mod03/InstallOperators-020.png)

Fill out the form, in our case leaving all values at default, scroll to the bottom an click Create to proceed:

![Module 3 Section 1 imageU](assets/images/mod03/InstallOperators-021.png)
![Module 3 Section 1 imageV](assets/images/mod03/InstallOperators-022.png)

You will see the operator will take some time to install (five minutes):

![Module 3 Section 1 imageW](assets/images/mod03/InstallOperators-023.png)

Once completed you can see the status in the Home Overview:

![Module 3 Section 1 imageX](assets/images/mod03/InstallOperators-024.png)





