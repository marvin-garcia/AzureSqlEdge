-- Create database
IF NOT EXISTS (SELECT * FROM sys.databases WHERE name='IoTEdgeDB')
BEGIN
    CREATE DATABASE IoTEdgeDB;
END;
GO

USE IoTEdgeDB;
GO

-- Create table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE NAME = N'SensorTemperature')
BEGIN
    CREATE TABLE SensorTemperature (timeCreated datetime2, machineTemperature float, machinePressure float, ambientTemperature float, ambientHumidity float);
END;
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE NAME = N'OpcNodes')
BEGIN
    CREATE TABLE OpcNodes (id [int] IDENTITY(1,1) NOT NULL, SourceTimestamp DATETIME2, NodeId VARCHAR(128), ApplicationUri VARCHAR(128), DipData FLOAT NULL, SpikeData FLOAT NULL, RandomSignedInt32 FLOAT NULL);
END;
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE NAME = N'Models')
BEGIN

    CREATE TABLE Models (id [int] IDENTITY(1,1) NOT NULL, data [varbinary](max) NULL, description VARCHAR(128), applicationUri VARCHAR(128) NULL);
END;
GO

-- Create login
CREATE LOGIN iotuser WITH PASSWORD = 'SuperSecretP@ssw0rd!'
GO

-- Create a master key on the database. Required to encrypt the credential secret.
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'SuperStrongM@sterK3y!';

-- Create a database-scoped credential for accessing the SQL Server source
CREATE DATABASE SCOPED CREDENTIAL SQLCredential WITH IDENTITY = 'iotuser', SECRET = 'SuperSecretP@ssw0rd!'
GO

-- Create database user
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'iotuser')
BEGIN
    CREATE USER [iotuser] FOR LOGIN [iotuser]
    EXEC sp_addrolemember N'db_owner', N'iotuser'
END;
GO

-- Create file format for stream input
Create External file format jsonfileformat
WITH
( 
   format_type = JSON,
);
GO

-- Create stream output data source
CREATE EXTERNAL DATA SOURCE edgehubsource
WITH
(
    LOCATION = 'edgehub://'
);
GO

-- Create SQL output data source
CREATE EXTERNAL DATA SOURCE localsqlsource
WITH
(
    LOCATION = 'sqlserver://tcp:.,1433',
    CREDENTIAL = SQLCredential
);
GO

-- Create external input stream object
CREATE EXTERNAL STREAM sensortempinput
WITH
(
    DATA_SOURCE = edgehubsource,
    FILE_FORMAT = jsonfileformat,
    LOCATION = N'sensortempinput',
    INPUT_OPTIONS = N'',
    OUTPUT_OPTIONS = N''
);
GO

CREATE EXTERNAL STREAM opcpublisherinput
WITH
(
    DATA_SOURCE = edgehubsource,
    FILE_FORMAT = jsonfileformat,
    LOCATION = N'opcpublisherinput',
    INPUT_OPTIONS = N'',
    OUTPUT_OPTIONS = N''
);
GO

-- Create external output stream object
CREATE EXTERNAL STREAM iothuboutput
WITH
(
    DATA_SOURCE = edgehubsource,
    FILE_FORMAT = jsonfileformat,
    LOCATION = N'iothuboutput',
    INPUT_OPTIONS = N'',
    OUTPUT_OPTIONS = N''
);
GO

-- Create external SQL output stream object
CREATE EXTERNAL STREAM sensortempdboutput
WITH
(
    DATA_SOURCE = localsqlsource,
    LOCATION = N'IoTEdgeDB.dbo.SensorTemperature',
    INPUT_OPTIONS = N'',
    OUTPUT_OPTIONS = N''
);
GO

CREATE EXTERNAL STREAM opcnodesdboutput
WITH
(
    DATA_SOURCE = localsqlsource,
    LOCATION = N'IoTEdgeDB.dbo.OpcNodes',
    INPUT_OPTIONS = N'',
    OUTPUT_OPTIONS = N''
);
GO

-- Create streaming jobs query
EXEC sys.sp_stop_streaming_job @name=N'StreamingJob1'
EXEC sys.sp_drop_streaming_job @name=N'StreamingJob1'
GO

EXEC sys.sp_create_streaming_job @name=N'StreamingJob1', @statement=
N'
Select
    *
INTO
    iothuboutput
FROM
    opcpublisherinput

SELECT
    Value.SourceTimestamp,
    NodeId,
    ApplicationUri,
    (LAG(Value) OVER (PARTITION BY ApplicationUri LIMIT DURATION(minute, 3)  WHEN DisplayName = ''DipData'')).Value As DipData,
    (LAG(Value) OVER (PARTITION BY ApplicationUri LIMIT DURATION(minute, 3)  WHEN DisplayName = ''SpikeData'')).Value As SpikeData,
    (LAG(Value) OVER (PARTITION BY ApplicationUri LIMIT DURATION(minute, 3)  WHEN DisplayName = ''RandomSignedInt32'')).Value As RandomSignedInt32
INTO
    opcnodesdboutput
FROM
    opcpublisherinput'

EXEC sys.sp_start_streaming_job @name=N'StreamingJob1'
GO