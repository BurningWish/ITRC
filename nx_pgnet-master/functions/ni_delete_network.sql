-- Function: ni_delete_network(character varying)

-- DROP FUNCTION ni_delete_network(character varying);

CREATE OR REPLACE FUNCTION ni_delete_network(character varying)
  RETURNS void AS
$BODY$
DECLARE
    --table prefix to assign to nodes, edge and edge_geometry table
    table_prefix ALIAS for $1;
    
    --constant node table suffix
    node_table_suffix varchar := '_Nodes';
    --constant edge table suffix
    edge_table_suffix varchar := '_Edges';
    --constant edge_geometry table suffix
    edge_geometry_table_suffix varchar := '_Edge_Geometry';
    
    --constant interdependency suffix
    interdependency_table_suffix varchar := '_Interdependency';
    --constant interdependency edge suffix
    interdependency_edge_table_suffix varchar := '_Interdependency_Edges';
    
    --generic view suffixes
    node_view_suffix varchar := '_View_Nodes';
    edge_edge_geometry_view_suffix varchar := '_View_Edges_Edge_Geometry';
    interdependency_interdependency_edge_view_suffix varchar := '_View_Interdependency_Interdependency_Edges';
    
	node_view_name varchar := '';
	edge_edge_geometry_view_name varchar := '';
	interdependency_interdependency_edge_view_name varchar := '';
	
    --to determine which interdependency tables to delete
    interdependency_prefix_like_comparator varchar := '';
    interdependency_suffix_like_comparator varchar := '';
    interdependency_edge_suffix_like_comparator varchar := '';
    
    --node table name (table_prefix+node_table_suffix)
    node_table_name_to_delete varchar := '';
    --edge table name (table_prefix+edge_table_suffix)
    edge_table_name_to_delete varchar := '';
    --edge geometry table name (table_prefix+edge_geometry_table_suffix)
    edge_geometry_table_name_to_delete varchar := '';
    
    --record from the information_schema table
    information_schema_record RECORD;
    
    --network graph id
    graph_id integer := 0;
    
    --network graph count
    graph_count integer := -1;
    
    --constant geometry column table name
    geometry_column_table_name varchar := 'geometry_columns';
    
    --database schema name
    schema_name varchar := '';
BEGIN

	node_view_name := table_prefix||node_view_suffix;
	edge_edge_geometry_view_name := table_prefix||edge_edge_geometry_view_suffix;
	interdependency_interdependency_edge_view_name := table_prefix||interdependency_interdependency_edge_view_suffix;

    --delete the associated interdependencies
    --find all tables in the public schema with table prefix in    
    interdependency_prefix_like_comparator := table_prefix||'%';
    interdependency_suffix_like_comparator := '%'||interdependency_table_suffix;
    interdependency_edge_suffix_like_comparator := '%'||interdependency_edge_table_suffix;
    
    
    --remove the views from the geometry columns table    
	FOR information_schema_record IN EXECUTE 'SELECT * FROM information_schema.views WHERE table_schema = '||quote_literal(schema_name)||' AND table_name ILIKE '||quote_literal(edge_edge_geometry_view_name)||' OR table_name ILIKE '||quote_literal(interdependency_interdependency_edge_view_name)||' OR table_name ILIKE '||quote_literal(node_view_name)||'' LOOP
		
        --remove the interdependency and edge views
        EXECUTE 'DROP VIEW IF EXISTS'||quote_ident(information_schema_record.table_name)||' CASCADE';
        EXECUTE 'DELETE FROM '||quote_ident(geometry_column_table_name)||' WHERE f_table_name = '||quote_literal(information_schema_record.table_name);
    END LOOP;
    
    --remove the tables from information_schema
    FOR information_schema_record IN EXECUTE 'SELECT table_name FROM information_schema.tables WHERE table_schema = '||quote_literal(schema_name)||' AND table_name LIKE '||quote_literal(interdependency_prefix_like_comparator)||' AND (table_name LIKE '||quote_literal(interdependency_suffix_like_comparator)||' OR table_name LIKE '||quote_literal(interdependency_edge_suffix_like_comparator)||')' LOOP
        --drop the interdependency table        
        EXECUTE 'DROP TABLE IF EXISTS '||quote_ident(information_schema_record.table_name)||' CASCADE';
        
    END LOOP;
    
    
    --determine if there are any graphs of that name
    EXECUTE 'SELECT count(*) FROM "Graphs" WHERE "GraphName" = '||quote_literal(table_prefix) INTO graph_count;
    --if there are graphs, then get the ID of it and delete the interdependency records 
    IF graph_count > 0 THEN
        
        --determine the graph id for the current graph/network to be deleted
        EXECUTE 'SELECT "GraphID" FROM "Graphs" WHERE "GraphName" = '||quote_literal(table_prefix) INTO graph_id;
        
        --remove the records from Global_Interdependency table that reference the network to be deleted
        EXECUTE 'DELETE FROM "Global_Interdependency" WHERE "InterdependencyFromGraphID" = '||graph_id||' OR "InterdependencyToGraphID" = '||graph_id;
    
    END IF;
    
    --create node table name
    node_table_name_to_delete := table_prefix||node_table_suffix;
    
    --create edge table name
    edge_table_name_to_delete := table_prefix||edge_table_suffix;
    
    --create edge_geometry table name
    edge_geometry_table_name_to_delete := table_prefix||edge_geometry_table_suffix;
    
    --delete the edge table
    EXECUTE 'DROP TABLE IF EXISTS '||quote_ident(edge_table_name_to_delete)||' CASCADE';
    
    --remove the edge_geometry table
    EXECUTE 'DROP TABLE IF EXISTS '||quote_ident(edge_geometry_table_name_to_delete)||' CASCADE';
    
    --remove the node table
    EXECUTE 'DROP TABLE IF EXISTS '||quote_ident(node_table_name_to_delete);
    
    --remove the records from the graphs table
    EXECUTE 'DELETE FROM "Graphs" WHERE "GraphName" = '||quote_literal(table_prefix);
    
    RETURN;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION ni_delete_network(character varying) OWNER TO postgres;
