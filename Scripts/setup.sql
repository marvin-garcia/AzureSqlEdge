-- Create database
IF NOT EXISTS (SELECT * FROM sys.databases WHERE name='IoTEdgeDB')
BEGIN
    CREATE DATABASE IoTEdgeDB;
END;
GO

-- Create table
USE IoTEdgeDB;
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE NAME = N'SimulatedTemperature')
BEGIN
    CREATE TABLE SimulatedTemperature (timeCreated datetime2, machineTemperature float, machinePressure float, ambientTemperature float, ambientHumidity float);
END;
GO

-- Create login
CREATE LOGIN iotuser WITH PASSWORD = 'SuperSecretP@ssw0rd!'
GO

-- Create a master key on the database. Required to encrypt the credential secret.
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'SuperStrongM@sterK3y!';

-- Create a database-scoped credential for accessing the SQL Server source
CREATE DATABASE SCOPED CREDENTIAL SQLCredential
WITH IDENTITY = 'iotuser', SECRET = 'SuperSecretP@ssw0rd!'
GO

-- Create database user
Use IoTEdgeDB;
GO

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'iotuser')
BEGIN
    CREATE USER [iotuser] FOR LOGIN [iotuser]
    EXEC sp_addrolemember N'db_owner', N'iotuser'
END;
GO

-- Create file format for stream input
Create External file format JsonFormat
WITH
( 
   format_type = JSON,
)
GO

-- Create stream output data source
CREATE EXTERNAL DATA SOURCE EdgeHubTarget
WITH
(
    LOCATION = 'edgehub://'
)
GO

-- Create SQL output data source
CREATE EXTERNAL DATA SOURCE LocalSQLOutput
WITH
(
    LOCATION = 'sqlserver://tcp:.,1433',
    CREDENTIAL = SQLCredential
)
GO

-- Create external input stream object
CREATE EXTERNAL STREAM SensorInput
WITH
(
    DATA_SOURCE = EdgeHubTarget,
    FILE_FORMAT = JsonFormat,
    LOCATION = N'sensorinput',
    INPUT_OPTIONS = N'',
    OUTPUT_OPTIONS = N''
);
GO

-- Create external output stream object
CREATE EXTERNAL STREAM SensorOutput
WITH
(
    DATA_SOURCE = EdgeHubTarget,
    FILE_FORMAT = JsonFormat,
    LOCATION = N'sensoroutput',
    INPUT_OPTIONS = N'',
    OUTPUT_OPTIONS = N''
);
GO

-- Create external SQL output stream object
CREATE EXTERNAL STREAM SqlOutput
WITH
(
    DATA_SOURCE = LocalSQLOutput,
    LOCATION = N'IoTEdgeDB.dbo.SimulatedTemperature',
    INPUT_OPTIONS = N'',
    OUTPUT_OPTIONS = N''
);
GO

-- Create streaming jobs query
EXEC sys.sp_create_streaming_job @name=N'StreamingJob1', @statement=
N'
Select * INTO SensorOutput from SensorInput

Select 
    [timeCreated],
    machine.temperature as [machineTemperature],
    machine.pressure as [machinePressure],
    ambient.temperature as [ambientTemperature],
    ambient.humidity as [ambientHumidity]
 INTO SqlOutput from SensorInput
 '
GO

-- Start streaming job
EXEC sys.sp_start_streaming_job @name=N'StreamingJob1'
GO