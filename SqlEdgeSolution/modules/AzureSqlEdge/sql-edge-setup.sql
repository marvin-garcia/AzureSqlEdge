-- declare variables
declare	@databaseMasterKey			nvarchar(64)
	,	@databaseScopedCredential	nvarchar(64)
	,	@dynamicSql					nvarchar(4000)
	,	@loginPassword				nvarchar(64)
	,	@schemaVersion				nvarchar(8);

-- declare version the database's schema will be upon the successful completion of this script
set @schemaVersion = N'1.0';

-- create dbo.SchemaVersionLog table
if not exists (select 1 from sys.objects where [name] = N'SchemaVersionLog' and schema_id = 1 )
begin
    create table dbo.SchemaVersionLog
		(	[version]	nvarchar(8)	not null
		,	appliedOn	datetime2	not null
		);
end

-- create dbo.SensorTemperature table
if not exists (select 1 from sys.objects where [name] = N'SensorTemperature' and schema_id = 1 )
begin
    create table dbo.SensorTemperature
		(	timeCreated			datetime2
		,	machineTemperature	float
		,	machinePressure		float
		,	ambientTemperature	float
		,	ambientHumidity		float
		);
end;

-- get database secrets
select	@databaseMasterKey			= json_value(secrets.[value], '$[0].DatabaseMasterKey')
	,	@databaseScopedCredential	= json_value(secrets.[value], '$[0].DatabaseScopedCredential')
	,	@loginPassword				= json_value(secrets.[value], '$[0].LoginPassword')
from	openrowset(bulk '/usr/work/DatabaseSecrets.json', single_clob)	as clob
cross	apply openjson(clob.BulkColumn,  'strict $')				as secrets;

-- abort if any secrets are missing
if @databaseMasterKey is null or @databaseScopedCredential is null or @loginPassword is null
begin
	raiserror( 'One or more database secrets are missing from DatabaseSecrets.json', 20, 1);
end;

-- create a master key for the database to enable encryption of the credential's secret
if not exists (select 1 from sys.symmetric_keys where [name] = N'##MS_DatabaseMasterKey##')
begin
	select @dynamicSql = concat(N'create master key encryption by password = ''', @databaseMasterKey, N'''');
	execute sp_executesql @dynamicSql;
end;

-- create a database-scoped credential for accessing the SQL Edge source
if not exists (select 1 from sys.database_scoped_credentials where [name] = N'SqlCredential')
begin
	select @dynamicSql = concat(N'create database scoped credential SqlCredential with identity = ''iotuser'', secret = ''', @databaseScopedCredential, N'''');
	execute sp_executesql @dynamicSql;
end

-- create a sql login
if not exists (select 1 from sys.sql_logins where [name] = N'iotuser')
begin
	select @dynamicSql = concat(N'create login iotuser with password = ''', @loginPassword, N'''');
	execute sp_executesql @dynamicSql;
end;

-- create a database user for the login and add it to the db_owner role
if not exists (select 1 from sys.database_principals where name = N'iotuser')
begin
    create user [iotuser] for login [iotuser];
	alter role db_owner add member iotuser;    
end;

-- create a file format for stream input
if not exists (select 1 from sys.external_file_formats where [name] = N'JsonFileFormat')
begin
	create external file format JsonFileFormat
		with ( format_type = JSON );
end;

-- create a stream output data source
if not exists (select 1 from sys.external_data_sources where [name] = N'EdgeHubSource')
begin
	create external data source EdgeHubSource 
		with ( location = 'edgehub://' );
end;

-- create SQL Edge output data source
if not exists (select 1 from sys.external_data_sources where [name] = N'LocalSqlSource')
begin
	create external data source LocalSqlSource
		with
		(	location	= 'sqlserver://tcp:.,1433'
		,	credential	= SqlCredential
		);
end;

-- create external input stream object
if not exists (select 1 from sys.external_streams where [name] = N'SensorInput')
begin
	create external stream SensorInput
		with
		(	data_source		= EdgeHubSource
		,	file_format		= JsonFileFormat
		,	location		= N'SensorInput'
		,	input_options	= N''
		,	output_options	= N''
		);
end;

-- create external output stream object
if not exists (select 1 from sys.external_streams where [name] = N'IotHubOutput')
begin
	create external stream IotHubOutput
		with
		(	data_source		= EdgeHubSource
		,	file_format		= JsonFileFormat
		,	location		= N'IotHubOutput'
		,	input_options	= N''
		,	output_options	= N''
		);
end;

-- create external sql output stream object
if not exists (select 1 from sys.external_streams where [name] = N'SqlDbOutput')
begin
	create external stream SqlDbOutput
		with
		(	data_source		= LocalSqlSource
		,	location		= N'IoTEdgeDB.dbo.SensorTemperature'
		,	input_options	= N''
		,	output_options	= N''
		);
end;

-- create and start the streaming job
if not exists (select 1 from sys.external_streaming_jobs where [name] = N'StreamingJob1')
begin

	-- create streaming jobs query
	execute sys.sp_create_streaming_job 
				@name = N'StreamingJob1'
			,	@statement =
N'
select	*
into	IotHubOutput
from    SensorInput

select	[timeCreated]
	,	machine.temperature	as [machineTemperature]
	,	machine.pressure	as [machinePressure]
	,	ambient.temperature as [ambientTemperature]
	,	ambient.humidity	as [ambientHumidity]
into    SqlDbOutput
from    SensorInput'
			,	@streams = NULL

	-- start streaming job if 'Created' or 'Stopped'
	if (select [status] from sys.external_streaming_jobs where [name] = N'StreamingJob1') in (0, 4)
	begin
		execute sys.sp_start_streaming_job @name = N'StreamingJob1';
	end;
end;

-- set the database schema's version
-- NOTE that max(appliedOn) date will always reflect the current schema's version if this methodology is consistently followed
if not exists (select 1 from dbo.SchemaVersionLog where [version] = @schemaVersion)
begin
	insert dbo.SchemaVersionLog
		(	[version]
		,	appliedOn
		)
	select	@schemaVersion
		,	getdate();
end

-- display the current schema version
select	top 1
		[version]
	,	appliedOn
from	dbo.SchemaVersionLog
order	by
		appliedOn desc;