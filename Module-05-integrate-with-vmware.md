# Integrate VMware with OpenShift clusters to enable for migration

> [!NOTE]
> It is assumed that you have already deployed the Virtualization and Migration Toolkit for Virtualization on your target OCP cluster

## Log into the your OCP cluster that you want to integrate with a VMware deployment

1. Go to the Migration for Virtualization on the left hand side of the OCP console and navigate to Providers

![Module 5 Step 1 imageA](assets/images/mod05/VMwareIntergration-001.png)

Since this is a new installation we need to create a Provider, click on the Create Provider

![Module 5 Step 1 imageB](assets/images/mod05/VMwareIntergration-002.png)

You are presented with several Provider types that are supported, in our case we will choose VMware

![Module 5 Step 1 imageC](assets/images/mod05/VMwareIntergration-003.png)

You are presented with a workflow to fill out, we will leave the default value for project as **openshift-mtv**

![Module 5 Step 1 imageD](assets/images/mod05/VMwareIntergration-004.png)

For Provider Resource Name we will list it as our **arizonvcenter**

![Module 5 Step 1 imageE](assets/images/mod05/VMwareIntergration-005.png)

We will choose vCEnter as our endpoint type. The url will be that of the vCenter SDK API.

![Module 5 Step 1 imageF](assets/images/mod05/VMwareIntergration-006.png)

For lab testing, we will skip installing a VDDK image. 

![Module 5 Step 1 imageG](assets/images/mod05/VMwareIntergration-007.png)

Add your username and password to enable to authenticate with vcenter. For lab testing we will skip certificate validation. Click Create Provider

![Module 5 Step 1 imageH](assets/images/mod05/VMwareIntergration-008.png)

You will see the provider will be created very quickly and the inventory of the vCenter will be listed:

![Module 5 Step 1 imageI](assets/images/mod05/VMwareIntergration-009.png)

![Module 5 Step 1 imageJ](assets/images/mod05/VMwareIntergration-010.png)