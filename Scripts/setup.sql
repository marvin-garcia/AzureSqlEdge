CREATE DATABASE AzureSqlEdge;
GO
USE AzureSqlEdge;
GO
CREATE TABLE SimulatedTemperature (timeCreated datetime2, machineTemperature float, machinePressure float, ambientTemperature float, ambientHumidity float);
GO

CREATE LOGIN iotuser WITH PASSWORD = 'SuperSecretP@ssw0rd!'
GO

Use AzureSqlEdge;
GO

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'iotuser')
BEGIN
    CREATE USER [iotuser] FOR LOGIN [iotuser]
    EXEC sp_addrolemember N'db_owner', N'iotuser'
END;
GO