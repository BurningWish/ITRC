@echo off
REM - ensures the output ni_tables.sql file has the tables defined in the correct order
copy /A ni_drop_tables.sql+ni_graphs.sql+ni_global_interdependency.sql+ni_interdependency.sql+ni_interdependency_edges.sql+ni_nodes.sql+ni_edges.sql+ni_edge_geometry.sql ni_tables.sql /B /Y
pause