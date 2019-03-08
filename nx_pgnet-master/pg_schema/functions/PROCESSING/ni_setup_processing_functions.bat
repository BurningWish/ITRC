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

REM - install all processing functions in to the database
C:
CD %3%
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_data_proc_connect_hanging_edges_to_node_like.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_data_proc_connect_hanging_edges_to_node_in_search.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_data_proc_connect_nodes_to_point_on_nearest_edge_like.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_data_proc_connect_nodes_to_point_on_nearest_edge_in_search.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_data_proc_detect_and_combine_duplicate_edges.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_find_junctions.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_find_nearest_nodeb_to_nodea_using_nn.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_link_nodeb_to_nodea_by_attribute.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_nearest_point_to_line_segment.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_node_separation_distance_with_node_id.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_node_separation_distance_without_node_id.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_union_geometry_distinct_records.sql"
CD %5
pause