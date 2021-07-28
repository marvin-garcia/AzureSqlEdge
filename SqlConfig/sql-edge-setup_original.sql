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
CREATE EXTERNAL STREAM sensorinput
WITH
(
    DATA_SOURCE = edgehubsource,
    FILE_FORMAT = jsonfileformat,
    LOCATION = N'sensorinput',
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
CREATE EXTERNAL STREAM sqldboutput
WITH
(
    DATA_SOURCE = localsqlsource,
    LOCATION = N'IoTEdgeDB.dbo.SensorTemperature',
    INPUT_OPTIONS = N'',
    OUTPUT_OPTIONS = N''
);
GO

-- Create streaming jobs query
EXEC sys.sp_create_streaming_job @name=N'StreamingJob1', @statement=
N'
Select
    *
INTO
    iothuboutput
FROM
    sensorinput

Select 
    [timeCreated],
    machine.temperature as [machineTemperature],
    machine.pressure as [machinePressure],
    ambient.temperature as [ambientTemperature],
    ambient.humidity as [ambientHumidity]
 INTO
    sqldboutput
FROM
    sensorinput'
GO

EXEC sys.sp_start_streaming_job @name=N'StreamingJob1'
GO