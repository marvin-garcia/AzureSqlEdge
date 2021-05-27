-- Create a master key on the database. Required to encrypt the credential secret.
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'SuperStrongM@sterK3y!';
GO

-- Create database
CREATE DATABASE AzureSqlEdge;
GO

-- Create table
USE AzureSqlEdge;
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE NAME = N'SimulatedTemperature')
BEGIN
    CREATE TABLE SimulatedTemperature (timeCreated datetime2, machineTemperature float, machinePressure float, ambientTemperature float, ambientHumidity float);
END;
GO

-- Create login
CREATE LOGIN iotuser WITH PASSWORD = 'SuperSecretP@ssw0rd!'
GO

-- Create a database-scoped credential for accessing the SQL Server source
CREATE DATABASE SCOPED CREDENTIAL SQLCredential
WITH IDENTITY = 'iotuser', SECRET = 'SuperSecretP@ssw0rd!'
GO

-- Create database user
Use AzureSqlEdge;
GO

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'iotuser')
BEGIN
    CREATE USER [iotuser] FOR LOGIN [iotuser]
    EXEC sp_addrolemember N'db_owner', N'iotuser'
END;
GO

-- Create file format for stream input
Create External file format InputFileFormat
WITH
( 
   format_type = JSON,
)
GO

-- Create file format for stream outnput
Create External file format OutputFileFormat
WITH
( 
   format_type = JSON,
)
GO

-- Create stream input data source
CREATE EXTERNAL DATA SOURCE EdgeHubInput
WITH
(
    LOCATION = 'edgehub://'
)
GO

-- Create stream output data source
CREATE EXTERNAL DATA SOURCE EdgeHubOutput
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
    DATA_SOURCE = EdgeHubInput,
    FILE_FORMAT = InputFileFormat,
    LOCATION = N'sensorinput',
    INPUT_OPTIONS = N'',
    OUTPUT_OPTIONS = N''
);
GO

-- Create external output stream object
CREATE EXTERNAL STREAM SensorOutput
WITH
(
    DATA_SOURCE = EdgeHubOutput,
    FILE_FORMAT = OutputFileFormat,
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
    LOCATION = N'AzureSqlEdge.dbo.SimulatedTemperature',
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
