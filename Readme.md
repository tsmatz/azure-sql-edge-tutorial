# Azure SQL Edge Tutorial Hands-On

In this repository, you can learn how you can use Azure SQL Edge with typical scenarios step-by-step.<br>
Please follow this readme description.

## Preparation - Provision IoT Hub and Device ##

Before starting, prepare resources - IoT hub and Edge device - in Microsoft Azure.

In [Azure Portal](https://portal.azure.com/), create IoT Hub resource. (Please proceed wizards and create a resource.)

![Create IoT Hub resource](images/create_iothub.png?raw=true)

In this example, we use "Azure IoT Edge on Ubuntu" virtual machine for IoT Edge device, on which Edge runtime is already installed and running.<br>
In [Azure Portal](https://portal.azure.com/), create "Azure IoT Edge on Ubuntu" resource.

![Create IoT Edge device](images/create_edge_on_ubuntu.png?raw=true)

In the generated IoT Hub resource page in Azure Portal, click "IoT Edge" menu on left-side navigation, click "Add an IoT Edge device" button, and proceed to register new IoT Edge device entry.

![Register IoT Edge device in IoT Hub](images/register_edge_device.png?raw=true)

Once you have registered a device, you can obtain connection string in device settings. (See below.)<br>
Please copy this connection string.

![Get device connection string](images/get_connection_string.png?raw=true)

In order to connect to IoT Hub from your Edge device (Ubuntu VM), login to Ubuntu VM, open ```/etc/iotedge/config.yaml``` in text editor, and paste above connection string on ```device_connection_string``` section (see below) in this file. (You can use ```nano``` for editting text on Ubuntu.)

```
...
provisioning:
  source: "manual"
  device_connection_string: "<ADD DEVICE CONNECTION STRING HERE>"
...
```

> You can also use ```/etc/iotedge/configedge.sh``` to configure connection string in IoT Edge runtime.

Restart IoT Edge runtime as follows.

```
sudo systemctl restart iotedge
```

> You can see whether Edge runtime is successfully running by ```sudo systemctl status iotedge``` command.

In Azure Portal, go to IoT Edge pane in IoT Hub resource page, and see whether only one system module (which is Edge agent module) is connected from your Edge device (Ubuntu).

![Edge status](images/edge_status01.png?raw=true)

> Please ignore 417 error status. (This is because no deployment is specified yet.)

## Preparation - Install Module for Data Generation ##

Next, we provision data generator module on Edge device. This custom module generates and sends streaming events every seconds into edge hub.

In Azure Portal, create a container registery resource, in which we'll publish our data generator image later.

![Create container registry](images/create_acr.png?raw=true)

After the container registry is created, click "Access keys" in the left navigation on your Azure container registry (ACR) resource and copy server name, user name, and password string.

![Container registry credentials](images/acr_credential.png?raw=true)

Clone (Download) this repository in your working machine, and go to ```/data-generator-module``` directory.

```
git clone https://github.com/tsmatz/azure-sql-edge-tutorial.git
cd azure-sql-edge-tutorial/data-generator-module
```

Generate "Data Generator Module" image and push this image into your container registry. (Change the following ```{YOUR CONTAINER REGISTRY}.azurecr.io``` into your own server name.)

```
# Build data generator module's image
docker build --rm -f ./Dockerfile -t {YOUR CONTAINER REGISTRY}.azurecr.io/data-generator-module:0.0.1 ./
# Login to ACR (Please input username and password for ACR admin)
docker login {YOUR CONTAINER REGISTRY}.azurecr.io
# Push image to ACR
docker push {YOUR CONTAINER REGISTRY}.azurecr.io/data-generator-module:0.0.1
```

Open ```deployment/deployment1.json``` in text editor and change placeholders to meet your own container registry settings. (There exist total 4 placeholders to change.)

By running the following command, deploy "Data Generator Module" on your Edge device (Ubuntu) through IoT Hub.

```
# Install IoT extension for using "az iot edge" command
az extension add --name azure-iot
# Set modules with deployment manifest to a single device
cd deployment
az iot edge set-modules --hub-name {YOUR IOT HUB NAME} --device-id {YOUR DEVICE NAME} --content ./deployment1.json
```

Go to IoT Hub resource in Azure Portal, and see whether modules are correctly installed and working on Edge device (Ubuntu).

![Edge status](images/edge_status02.png?raw=true)

Logon to Edge device (Ubuntu) and run the following command to see whether ```DataGeneratorModule``` is correctly running.

```
# List installed modules
iotedge list

NAME                 STATUS   DESCRIPTION    CONFIG
DataGeneratorModule  running  Up 5 minutes   iottest01.azurecr.io/data-generator-module:0.0.1
edgeHub              running  Up 5 minutes   mcr.microsoft.com/azureiotedge-hub:1.0
edgeAgent            running  Up 29 minutes  mcr.microsoft.com/azureiotedge-agent:1.0

# Show logs of Data Generator Module
iotedge logs DataGeneratorModule

{the sending messages will be displayed}
```

## Install and Configure SQL Edge Module (Input Stream Sample) ##

In this exercise, we will install Azure SQL Edge module on your Edge device (Ubuntu), and configure SQL Edge instance to consume the streaming events generated by above Data Generator Module (```DataGeneratorModule```).

In order for simplification, through this tutorial, we will set up database using SQL client (such as, Azure Data Studio) manually.<br>
However, in production use, you can set up and modify database objects for all connected devices as follows :

- You can specify the zipped dacpac (or bacpac) using ```MSSQL_PACKAGE``` environment's parameter in creation options of SQL Edge module. (See "[SQL Database DACPAC and BACPAC packages in SQL Edge](https://docs.microsoft.com/en-us/azure/azure-sql-edge/deploy-dacpac)" for details.)
- Inside each devices, SQL commands will be invoked with familiar manners by connecting to SQL port (1433 by default) on SQL Edge module. (See "[Connect and query Azure SQL Edge](https://docs.microsoft.com/en-us/azure/azure-sql-edge/connect)" for details.)

Now let's start to install SQL Edge on device (Ubuntu).

Open ```deployment/deployment2.json``` in text editor and change placeholders to meet your own container registry settings. (There exist total 4 placeholders to change.)<br>
Then run the following command to deploy Azure SQL Edge on your Edge device (Ubuntu).

```
cd deployment
az iot edge set-modules --hub-name {YOUR IOT HUB NAME} --device-id {YOUR DEVICE NAME} --content ./deployment2.json
```

> Note : You can also deploy Azure SQL Edge using Azure Portal UI. (The wizard will generate the same deployment configuration, such as ```deployment/deployment2.json```.)<br>
![Deploy SQL Edge](images/install_sql_edge.png?raw=true)

In IoT Edge device pane, see whether Azure SQL Edge module is successfully running. (See below.)<br>
Once SQL Edge is deployed on your device, the billing starts regardless of whether the SQL process is running or stopped.

![Edge status](images/edge_status03.png?raw=true)

As I mentioned above, let us manually set up database from here. (This will help you understand how it's working.)

First, in order to allow SQL client to connect to SQL Edge database, open inbound 1433 port in firewall settings on network configuration in Edge device (Ubuntu).

![Open default SQL port](images/open_sql_port.png?raw=true)

Connect Azure SQL Edge database using SQL client in your working machine, such as, Azure Data Studio. Use the following credential.

- Server Name : [IP address of your Edge device (Ubuntu)]
- Admin User Name : sa
- Admin User Password : P@ssw0rd

Run ```sql/create_schema.sql``` (below) on SQL Edge database.

```
USE [master];
GO

CREATE DATABASE [FoodInspection];
GO

USE [FoodInspection];
GO

CREATE TABLE [dbo].[InspectionResults](
    [timestamp] DATETIME2(7) NULL,
    [weight] NUMERIC(25, 20) NULL,
    [concentration] NUMERIC(25, 20) NULL,
    [grade] INT NULL
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[DefectiveItems](
    [timestamp] DATETIME2(7) NULL,
    [weight] NUMERIC(25, 20) NULL,
    [concentration] NUMERIC(25, 20) NULL,
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[Models](
	[id] INT IDENTITY(1,1) NOT NULL,
	[data] VARBINARY(MAX) NULL,
	[description] VARCHAR(255) NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

-- Strong password required to encrypt the credential secret

CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Str0ngP@ssw0rd';
GO

-- Create stream input from edge hub
-- (See routes setting in deployment2.json)

CREATE EXTERNAL FILE FORMAT [JSONFormat]  
WITH ( FORMAT_TYPE = JSON)
GO

Create EXTERNAL DATA SOURCE [EdgeHub] 
With(
  LOCATION = N'edgehub://'
)
GO

CREATE EXTERNAL STREAM [DataGeneratorInput] WITH 
(
  DATA_SOURCE = EdgeHub,
  FILE_FORMAT = JSONFormat,
  LOCATION = N'input1'
)
GO

-- Create stream output to database table

CREATE DATABASE SCOPED CREDENTIAL [SQLCredential]
WITH IDENTITY = 'sa', SECRET = 'P@ssw0rd'

CREATE EXTERNAL DATA SOURCE [LocalSQL]
WITH (LOCATION = 'sqlserver://tcp:.,1433',CREDENTIAL = [SQLCredential])

CREATE EXTERNAL STREAM [TableOutput] WITH 
(
  DATA_SOURCE = [LocalSQL],
  LOCATION = N'FoodInspection.dbo.InspectionResults'
)

-- Create a streraming job and Start

EXEC sys.sp_create_streaming_job @name=N'ResultInsertJob',
@statement= N'Select * INTO TableOutput from DataGeneratorInput'

EXEC sys.sp_start_streaming_job @name=N'ResultInsertJob'
```

By running this script, the streaming events generated by Data Generator Module will be consumed by streaming job on Azure SQL Edge. All events will be saved into ```InspectionResults``` table, row by row.

![Illustrated structure](images/structure01.png?raw=true)

When you run the following query, you will see that the number of rows increases every seconds.

```
SELECT COUNT(*) FROM [FoodInspection].dbo.[InspectionResults]
```

In this exercise, ```grade``` column in ```InspectionResults``` table will still be empty. (See below.)

![Open default SQL port](images/table_data01.png?raw=true)

## Deploy Model on SQL Edge ##

In this exercise, we will create the model to predict ```grade``` column of ```InspectionResults``` table.<br>
The model will be trained in Azure Machine Learning notebook and deployed into SQL Edge database. Using this model, the values of ```grade``` column will be predicted (inferenced) within database process.

First, create Azure Machine Learning resource (Machine Learning workspace) in Azure Portal.

![Create machine learning](images/create_ml.png?raw=true)

Go to [machine learning studio](https://ml.azure.com/) UI and login to above workspace.<br>
Click "Compute" in left-navigation and create a compute instance in machine learning studio. (See below.)

![Create machine learning compute instance](images/create_ml_compute.png?raw=true)

Click "Notebooks" in the left navigation.<br>
Push "Upload files" icon (below) and upload ```train-model/train.ipynb``` and ```train-model/traindat.csv``` in this repository.

![Upload files on ML compute instance](images/upload_files_on_mlcompute.png?raw=true)

Change the following settings in ```train.ipynb```. (There exist total 4 placeholds.)

```
ws = Workspace(
  subscription_id="[YOUR SUBSCRIPTION ID]",
  resource_group="[YOUR RESOURCE GROUP NAME]",
  workspace_name="[YOUR AML WORKSPACE NAME]")
```

```
server = "[YOUR SQL EDGE SERVER IP]"
userid = "sa"
password = "P@ssw0rd"
database = "FoodInspection"
```

Run each cells on ```train.ipynb```.<br>
This will create ONNX model binary, and the generated model will be inserted into ```Models``` table in SQL Edge database.

Finally, run ```sql/register_prediction_agent.sql``` (below) on SQL Edge database.<br>
This SQL will register SQL Agent jobs to predict ```grade``` values for each items.

```
USE [FoodInspection];
GO

CREATE PROCEDURE assign_item_grade
AS
    -- Load onnx model
    DECLARE @model VARBINARY(MAX) = (SELECT [data] FROM [FoodInspection].[dbo].[Models] WHERE [id] = 1);

    -- Create temp table
    CREATE TABLE #TempNewResults
    (
        [timestamp] [DATETIME2](7) NULL,
        [weight] REAL NULL,
        [concentration] REAL NULL,
        [grade] INT NULL
    );

    -- Insert data (in which grade is not assigned) into temp table
    INSERT INTO [#TempNewResults] ([timestamp], [weight], [concentration])
    SELECT [timestamp], CAST([weight] AS REAL), CAST([concentration] AS REAL) FROM [FoodInspection].[dbo].[InspectionResults]
    WHERE [grade] IS NULL;

    -- Set grade in temp table
    MERGE [#TempNewResults] AS OrgTable
    USING (
        SELECT [#TempNewResults].[timestamp] AS [timestamp], p.output_label1 as [grade] FROM PREDICT(MODEL = @model, DATA = [#TempNewResults], Runtime=ONNX) WITH (output_label1 REAL) AS p
    ) AS PredTable
    ON [OrgTable].[timestamp] = [PredTable].[timestamp]
    WHEN MATCHED THEN
    UPDATE SET [OrgTable].[grade] = [PredTable].[grade];

    -- Merge grade with InspectionResults table
    MERGE [FoodInspection].[dbo].[InspectionResults] AS OrgTable
    USING (SELECT [timestamp], [grade] FROM [#TempNewResults]) AS TempTable
    ON [OrgTable].[timestamp] = [TempTable].[timestamp]
    WHEN MATCHED THEN
    UPDATE SET [OrgTable].[grade] = [TempTable].[grade];

    -- Insert into DefectiveItems table
    INSERT INTO [FoodInspection].[dbo].[DefectiveItems] ([timestamp], [weight], [concentration])
    SELECT [timestamp], CAST([weight] AS NUMERIC(25, 20)), CAST([concentration] AS NUMERIC(25, 20))
    FROM [#TempNewResults]
    WHERE [grade] = -1

    -- Drop temp table
    DROP TABLE [#TempNewResults];
GO

-- Create and register SQL agent job

USE [msdb];
GO

EXEC dbo.sp_add_job  
    @job_name = N'AssignGradeJob' ;  
GO

EXEC dbo.sp_add_jobstep
    @job_name = N'AssignGradeJob',
    @step_name = N'SetGradeAndDetectDefective',
    @subsystem = N'TSQL',
    @command = N'EXEC FoodInspection.dbo.assign_item_grade',
    @retry_attempts = 5,
    @retry_interval = 5;
GO

EXEC dbo.sp_add_schedule  
    @schedule_name = N'Every2Minutes',
    @enabled = 1,
    @freq_type = 4,
    @freq_interval = 1,
    @freq_subday_type = 4,
    @freq_subday_interval = 2;

EXEC dbo.sp_attach_schedule  
   @job_name = N'AssignGradeJob',  
   @schedule_name = N'Every2Minutes';
GO

EXEC dbo.sp_add_jobserver  
    @job_name = N'AssignGradeJob';  
GO
```

This job runs every 2 minutes and will do the following tasks.

- Set values of ```grade``` column in ```InspectionResults``` table using our trained model (onnx model).
- If ```grade``` value equals to -1 (which means a defective item), the data will also be inserted into ```DefectiveItems``` table.

![Illustrated structure](images/structure02.png?raw=true)



SQL Edge is based on SQL database engine, and you then can also integrate with a variety of familiar products and services, such as, Azure Data Factory or SQL Data Sync.
