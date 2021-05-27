# Azure SQL Edge
Solution repository to showcase how to use Azure SQL Edge on an IoT architecture

## Pre-requisites
If you don't have an IoT edge environment, follow these steps:

1. Open a PowerShell console, and clone the [IoT ELMS solution](https://github.com/Azure-Samples/iotedge-logging-and-monitoring-solution)

   ```powershell
   git clone https://github.com/Azure-Samples/iotedge-logging-and-monitoring-solution.git
   ```

2. Run the solution and follow the provisioning flow. When prompted for a deployment option, choose **Create a sandbox environment for testing (fastest)**.

   ```powershell
   .\Scripts\deploy.ps1
   ```

3. Wait for the deployment script to finish. You should see the deployment summary at the end:

   ```powershell
   Resource Group: <resource-group-name>
   Environment unique id: <environment-unique-id>
   
   IoT Edge VM Credentials:
   Username: azureuser
   Password: <iot-edge-vm-password>
   
   ##############################################
   ##############################################
   ####                                      ####
   ####        Deployment Succeeded          ####
   ####                                      ####
   ##############################################
   ##############################################
   ```



[Deploy Azure SQL Edge using the Azure portal | Microsoft Docs](https://docs.microsoft.com/en-us/azure/azure-sql-edge/deploy-portal#connect-from-outside-the-container)

