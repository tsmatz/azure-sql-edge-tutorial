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
-- (See routes setting in deployment.json)

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
