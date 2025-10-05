> [!NOTE] 
> The modules in this repository will guide through the following workflow

```mermaid
sequenceDiagram
    autonumber
    actor Student as ARO Engineer
    participant Hub as Hub portal (ACM)
    participant Clipboard as Clipboard
    participant Admin as Admin node
    participant Central as Central cluster (spoke)

    %% Hub portal steps
    Student ->> Hub: 1 Generate import commands
    Student ->> Hub: 2 Log in and open All clusters
    Hub -->> Student: 3 local-cluster is listed
    Student ->> Hub: 4 Click Import Cluster
    Student ->> Hub: 5 Choose Cluster set = default
    Student ->> Hub: 6 Leave Additional labels blank
    Student ->> Hub: 7 Select import mode Run commands manually then Next
    Student ->> Hub: 8 Leave Automation template blank then Next
    Student ->> Hub: 9 Review and click Generate command
    Hub -->> Student: 10 Pending import shown and Copy command available
    Student ->> Clipboard: Copy base64 content

    %% Admin node actions
    Student ->> Admin: 11 cd to adminoc directory
    Student ->> Admin: 12 Run centralcluster.sh to log in
    Admin ->> Central: Authenticate to central cluster
    Student ->> Admin: 13 Create centralimport.sh and paste base64 content
    Student ->> Admin: 14 chmod +x centralimport.sh
    Admin ->> Central: 15 Execute centralimport.sh

    %% Completion
    Central -->> Hub: Cluster registers with Hub
    Hub -->> Student: 16 All clusters shows imported status

    %% Notes for training defaults
    Note over Hub,Student: Steps 5, 6, and 8 use training defaults (default cluster set, no labels, no automation template)
```

> [!TIP]
> Ensure that you completed the post deployment actions for oc login to ease the effort to importing the cluster into ACM

# Steps to import OpenShift cluster into ACM

## Step 1 Log into the hub cluster OCP portal, go to all clusters

![Module 4 Step 1 imageA](assets/images/mod04/ImportCluster-001.png)

![Module 4 Step 1 imageB](assets/images/mod04/ImportCluster-002.png)

> [!NOTE] 
> Under Cluster list, if no other clusters have imported you should see local-cluster, which is the cluster that has the ACM operator installed

## Step 2 To the right of the Search box, you should see a Import Cluster control, click the button to launch the Import form

![Module 4 Step 2 imageA](assets/images/mod04/ImportCluster-003.png)

## Step 3 Details form page. Enter the name you will refence the cluster to be imported by, in our case **contosocentralregion**. For training purposes you can choose **default** for Cluster set, Leave Additional Labels blank, and **Run import commands manually**, click next

![Module 4 Step 3 imageA](assets/images/mod04/ImportCluster-004.png)

## Step 4 Automation form page Leave Automation template blank for training purposes, click next

![Module 4 Step 4 imageA](assets/images/mod04/ImportCluster-005.png)

## Step 5 Review settings, if all looks as expected, click Generate command

![Module 4 Step 5 imageA](assets/images/mod04/ImportCluster-006.png)

## Step 6 On the portal you should see the cluster is pending import, Click the Copy the command button. This will paste the Base 64 content to your local clipboard we will use to generate the OC commands to import the cluster.

![Module 4 Step 6 imageA](assets/images/mod04/ImportCluster-007.png)

## Step 9 On the Admin Node, cd directories to the adminoc directory
## Step 10 Run the centralcluster.sh to log into the central cluster
## Step 11 Once logged into the central cluster, using vi, create a newfile called centralimport.sh, copy the base 64 content from the Copy command from previous step
## Step 12 Ensure bash file is executable using chmod +x
## Step 13 Run the centralimport.sh file
## Step 14 Back in the Hub cluster under All clusters, you should now see that your cluster has been imported.