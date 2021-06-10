# Wait for the SQL Server to come up
sleep 90s

# Run the setup script to create the DB and the schema in the DB
/opt/mssql-tools/bin/sqlcmd -S localhost -U -P $MSSQL_SA_PASSWORD -i setup.sql >> /usr/work/mssqllogs.txt 2>&1