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

REM - install all generic functions to given database (2)
C:
CD %3%
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_add_fr_constraints.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_add_global_interdependency_record.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_add_graph_record.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_add_interdependency_record.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_add_to_geometry_columns.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_build_spatial_index.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_check_interdependency_tables.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_check_network_tables.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_check_srid.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_create_edge_view.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_create_interdependency_edge_view.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_create_interdependency_tables.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_create_network_table_edge_geometry.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_create_network_table_edge_geometry_prefix_srid_only.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_create_network_table_edges.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_create_network_table_nodes.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_create_network_table_nodes_prefix_srid_only.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_create_network_tables.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_create_new_column_names_for_join.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_create_node_view.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_delete_network.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_edge_geometry_equality_check_with_srid.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_edge_geometry_equality_check_without_srid.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_edge_snap_geometry_equality_check.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_get_graph_id_by_prefix.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_get_graph_id_by_prefix.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_get_all_table_column_names.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_get_all_view_column_names.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_graph_to_csv_3.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_graph_to_csv_4.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_get_graph_to_gephi_edge_list.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_node_attribute_equality_check.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_node_geometry_equality_check_with_srid.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_node_geometry_equality_check_without_srid.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_node_snap_geometry_equality_check.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_remove_from_geometry_columns.sql"
psql -h %1 -U %2 -d %4 -w -f "%~dp0ni_reset_database_with_schema_name.sql"
CD %5%
pause