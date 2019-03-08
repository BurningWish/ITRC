@echo off

REM - install all network interdependency tables

REM - running order:
REM - ni_graphs.sql
REM - ni_global_interdependency.sql
REM - ni_interdependency.sql
REM - ni_interdependency_edges.sql
REM - ni_nodes.sql
REM - ni_edges.sql
REM - ni_edge_geometry.sql

REM - generic database parameters
REM - 1="<insert_host_value>" REM - e.g. "localhost"
REM - 2="<insert_postgres_user_name>" REM - e.g. "postgres"
REM - 3="<insert_postgresql_bin_path>" REM - e.g. "C:/Program Files (x86)/PostgreSQL/9.0/bin/"
REM - 4="<insert_ni_database_name>" REM - e.g. "ni_database"
REM - 5="<path_executing_batch_file"> REM this is autoset based upon where the ni_setup_database.bat file is executing

set argcount=0
for %%x in (%*) do Set /A argcount+=1

IF %argcount% LSS 5 (
	echo "Input argument missing. Parameter 1 = host, Parameter 2 = user, Parameter 3 = postgres bin folder, Parameter 4 = database name e.g. ni_setup_database.bat 'localhost' 'postgres' 'C:\Program Files (x86)\PostgreSQL\9.0\bin\' 'empty'
	pause
	GOTO :eof
	
)

IF %argcount% == 4 (
	%5% = %~dp0
)

C:
CD %3%
REM - graphs
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_graphs.sql"

REM - global_interdependency
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_global_interdependency.sql"

REM - interdependency
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_interdependency.sql"

REM - interdependency_edges
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_interdependency_edges.sql"

REM - nodes
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_nodes.sql"

REM - edges
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_edges.sql"

REM - edge_geometry
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_edge_geometry.sql"
CD %5%
pause