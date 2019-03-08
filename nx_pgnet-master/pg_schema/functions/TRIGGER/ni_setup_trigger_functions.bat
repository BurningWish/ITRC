@echo off

REM - generic database parameters
REM - 1="<insert_host_value>" REM - e.g. "localhost"
REM - 2="<insert_postgres_user_name>" REM - e.g. "postgres"
REM - 3="<insert_postgresql_bin_path>" REM - e.g. "C:/Program Files (x86)/PostgreSQL/9.0/bin/"
REM - 4="<insert_ni_database_name>" REM - e.g. "ni_database"

REM - count arguments
set argcount=0
for %%x in (%*) do Set /A argcount+=1

REM - check argument count for missing arguments
IF %argcount% LSS 4 (
	echo "Input argument missing. Parameter 1 = host, Parameter 2 = user, Parameter 3 = postgres bin folder, Parameter 4 = database name. e.g. ni_setup_database.bat 'localhost' 'postgres' 'C:\Program Files (x86)\PostgreSQL\9.0\bin\' 'empty'
	GOTO :eof
)

IF %argcount% == 4 (
	%5% = %~dp0
)

REM - install all trigger functions to given database
C:
CD %3%
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_check_record_geometry_columns_table_post_graph_edges_update.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_check_record_geometry_columns_table_post_graph_nodes_update.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_check_record_geometry_columns_table_post_graph_insert.sql" 
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_delete_edges_table_post_delete_graph.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_delete_edges_geometry_table_post_delete_graph.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_delete_global_int_record_post_graph_record_delete.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_delete_int_edge_table_post_int_record_delete.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_delete_int_table_post_int_record_delete.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_delete_int_tables_post_delete_graph.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_delete_nodes_table_post_delete_graph.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_delete_record_geometry_columns_table_post_delete_graph.sql"
CD %5%
pause