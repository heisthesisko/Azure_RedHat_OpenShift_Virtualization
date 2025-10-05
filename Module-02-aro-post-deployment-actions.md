> [!NOTE] 
> The modules in this repository will guide through the following workflow


Flowchart:

1. Logging into OCP console after ARO cluster has been created
2. Update the ocp version channel in via the portal
3. Unblock channel updates to allow upgrade to 4.18 or 4.19 via az command
4. Launch upgrade via the OC portal
5. Create oc admin login scripts to be ease administration in later modules


# Logging into OCP console after ARO cluster has been created

1. Get the ocp console url for the target cluster from the Azure portal ARO Clusters Blade

![Module 2 Section 1 imageA](assets/images/mod02/OCPConsole-001.png)

2. Copy the url and paster into your browser and go to the portal login page

![Module 2 Section 1 imageB](assets/images/mod02/OCPConsole-002.png)

3. Log into the az cli on your Admin Node to obtain your credentials

```bash
az aro list-credentials --name <your_cluster_name> --resource-group <your_resource_group_name>
```
Your output should look like this:

![Module 2 Section 1 imageC](assets/images/mod02/OCPConsole-003.png)

4. Use these credentials to login into the OpenShift Portal

![Module 2 Section 1 imageD](assets/images/mod02/OCPConsole-004.png)

# Update the ocp version channel in via the portal

1. Once logged in you are brought into Overview pane of the Console, in the center of the screen ensure that you have a green check mark indicating a healthy status of the cluster. You may see Insights are disabled which is expected.
2. You will navigate to the Administration tab on the left side of the console to set the ocp channel.

![Module 2 Section 1 imageE](assets/images/mod02/OCPConsole-005.png)

3. Click on Cluster Settings in the Administration section of the Console, you will see in console that the current version is 4.17.27, you will also see an alert that the cluster should not be updated to the next minor version, which we must in order to enable the Virtualization Operator. Following steps will show how to unblock this to proceed to ocp version 4.18. 

![Module 2 Section 1 imageF](assets/images/mod02/OCPConsole-006.png)

4. Click on the pencil icon to configure our preferred upgrade channel. You will be presented with a pop up form to enter your channel

![Module 2 Section 1 imageG](assets/images/mod02/OCPConsole-007.png)

5. We will target by typing in the form stable-4.18 and save.

![Module 2 Section 1 imageH](assets/images/mod02/OCPConsole-008.png)

6. You will now see in the console our Channel is set to stable-4.18, however we are blocked from going to 4.18.24

![Module 2 Section 1 imageI](assets/images/mod02/OCPConsole-009.png)

# Unblocking Channel update

1. From your Admin Node run the following command:

```bash
az aro update --name aro-contoso-virt --resource-group ContosoAroVirtDemo --upgradeable-to 4.18.24
```
![Module 2 Section 1 imageJ](assets/images/mod02/OCPConsole-010.png)

> [!NOTE]
> The command takes a minute or two to execute. Once finished you will see some output in the Admin node console and return to a normal prompt waiting for input.

2. The command will start the upgrade process to unblock the cluster upgrade, typically this will take a few minutes and you will see the portal transition a few times until the cluster is ready to update.

Initial view after command succeeds

![Module 2 Section 1 imageK](assets/images/mod02/OCPConsole-011.png)

View that Cluster is now ready to update to next version

![Module 2 Section 1 imageL](assets/images/mod02/OCPConsole-012.png)

# Launch upgrade via the OC portal

1. While logged into the OpenShift Portal under Administration->Cluster Settings->Details, you can click on Select Version

![Module 2 Section 1 imageM](assets/images/mod02/OCPConsole-013.png)

2. We will keep the default value presented, however you can use the drop down to choose another version of 4.18 for your needs. Click on Update to launch the Cluster upgrade

![Module 2 Section 1 imageN](assets/images/mod02/OCPConsole-014.png)

3. The command will take a mitute or two to initiate, once started you will see at the top of the portal in a yellow bar the Cluster is updating from 4.17.27 to 4.18.24

![Module 2 Section 1 imageO](assets/images/mod02/OCPConsole-015.png)

4. The cluster upgrade time varies depending on number of nodes in the cluster and other variables, typically the six node cluster will tale about 45 minutes to fully update.

View from Administration blade the progress of the upgrade

![Module 2 Section 1 imageP](assets/images/mod02/OCPConsole-016.png)

View from the Home Overview blade of the upgrade progress

![Module 2 Section 1 imageQ](assets/images/mod02/OCPConsole-017.png)

> [!Note] it is not uncommon to see status warnings such as the control plane being degraded, this is normal as the cluster is updated. Eventually the alert will clear and status will return to healthy.
> 
> ![Module 2 Section 1 imageR](assets/images/mod02/OCPConsole-018.png)













