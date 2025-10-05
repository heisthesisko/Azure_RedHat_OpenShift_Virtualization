> [!NOTE] 
> The modules in this repository will guide through the following workflow


Flowchart:

1. Update the ocp version channel in via the portal
2. Unblock channel updates to allow upgrade to 4.18 or 4.19 via az command
3. Launch upgrade via the OC portal
4. Create oc admin login scripts to be ease administration in later modules


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