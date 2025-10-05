> [!NOTE] 
> The modules in this repository will guide through the following workflow
> [!TIP]
> Ensure that you completed the post deployment actions for oc login to ease the effort to importing the cluster into ACM


Flowchart:

1. Generate import commands from ACM operator on Hub cluster to import spoke clusters
2. Log into the hub cluster OCP portal, go to all clusters
3. Under Cluster list, if no other clusters have imported you should see local-cluster, which is the cluster that has the ACM operator installed
4. To the right of the Search box, you should see a Import Cluster control, click the button to launch the Import form
5. For training purposes you can choose default for Cluster set
6. Leave Additional labels blank for training purposes
7. For import mode we will choose "Run import commands manually", click next
8. Leave Automation template blank for training purposes, click next
9. Review settings, if all looks as expected, click Generate command.
10. On the portal you should see the cluster is pending import, Click the Copy the command button. This will paste the Base 64 content to your local clipboard we will use to generate the OC commands to import the cluster.
11. On the Admin Node, cd directories to the adminoc directory
12. Run the centralcluster.sh to log into the central cluster
13. Once logged into the central cluster, using vi, create a newfile called centralimport.sh, copy the base 64 content from the Copy command from previous step
14. Ensure bash file is executable using chmod +x
15. Run the centralimport.sh file
16. Back in the Hub cluster under All clusters, you should now see that your cluster has been imported.

```mermaid
flowchart TD
  %% Flow: ACM import from Hub to Admin node and back

  %% Hub portal steps
  subgraph HUB[Hub cluster portal]
    S1[Generate import commands from ACM]
    S2[Log in to Hub OCP portal and open All clusters]
    S3[Confirm local-cluster is listed]
    S4[Click Import Cluster]
    S5[Cluster set: choose default]
    S6[Additional labels: leave blank]
    S7[Import mode: Run commands manually, then Next]
    S8[Automation template: leave blank, then Next]
    S9[Review settings and click Generate command]
    S10[Cluster shows Pending import. Click Copy command to copy base64 content]
  end

  %% Admin node steps
  subgraph ADMIN[Admin node]
    S11[cd to adminoc directory]
    S12[Run centralcluster.sh to log in to central cluster]
    S13[Create centralimport.sh and paste the base64 content]
    S14[Make script executable: chmod +x centralimport.sh]
    S15[Run centralimport.sh]
  end

  %% Final verification
  S16[Back on Hub All clusters: cluster is imported]

  %% Edges
  S1 --> S2 --> S3 --> S4 --> S5 --> S6 --> S7 --> S8 --> S9 --> S10
  S10 --> S11 --> S12 --> S13 --> S14 --> S15 --> S16
```


```mermaid
sequenceDiagram
    autonumber
    actor Student as Student engineer
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