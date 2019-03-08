-- Function: ni_reset_database(character varying)

-- DROP FUNCTION ni_reset_database(character varying);

CREATE OR REPLACE FUNCTION ni_reset_database(character varying)
  RETURNS void AS
$BODY$
DECLARE

    --ALIAS for schema_name input parameter
    schema_name ALIAS for $1;
    
    --for storing records from the information_schema table
    information_schema_record RECORD;
    
    --generic network interdependency tables
    parent_node_table_name varchar := 'Nodes';
    parent_edges_table_name varchar := 'Edges';
    parent_edge_geometry_table_name varchar := 'Edge_Geometry';
    graphs_table_name varchar := 'Graphs';
    global_interdependency_table_name varchar := 'Global_Interdependency';
    interdependency_table_name varchar := 'Interdependency';
    interdependency_edge_table_name varchar := 'Interdependency_Edges';
    
    --generic view suffixes
    edge_edge_geometry_view_suffix varchar := '_View_Edges_Edge_Geometry';
    interdependency_interdependency_edge_view_suffix varchar := '_View_Interdependency_Interdependency_Edges';
    
    --generic postgis tables - NOT TO DELETE
    geography_columns_table_name varchar := 'geography_columns';
    geometry_columns_table_name varchar := 'geometry_columns';
    spatial_ref_sys_table_name varchar := 'spatial_ref_sys';

BEGIN

    --delete tables, not including Nodes, Edges, Edge_Geometry, Graphs, Global Interdependency, geometry_columns, geography_columns, spatial_ref_sys
    FOR information_schema_record IN EXECUTE 'SELECT * FROM information_schema.tables WHERE table_type != ''VIEW'' AND table_schema = '||quote_literal(schema_name)||' AND table_name != '||quote_literal(parent_node_table_name)||' AND table_name != '||quote_literal(parent_edges_table_name)||' AND table_name != '||quote_literal(parent_edge_geometry_table_name)||' AND table_name != '||quote_literal(graphs_table_name)||' AND table_name != '||quote_literal(global_interdependency_table_name)||' AND table_name != '||quote_literal(geometry_columns_table_name)||' AND table_name != '||quote_literal(spatial_ref_sys_table_name)||' AND table_name != '||quote_literal(geography_columns_table_name)||' AND table_name != '||quote_literal(interdependency_table_name)||' AND table_name != '||quote_literal(interdependency_edge_table_name) LOOP
        --remove the table and dependencies using CASCADE        
        EXECUTE 'DROP TABLE IF EXISTS '||quote_ident(information_schema_record.table_name)||' CASCADE';
    END LOOP;
    
    --need to write some code to remove the views between edge and edge_geometry, and interdependency and interdependency_edge    
    FOR information_schema_record IN EXECUTE 'SELECT * FROM information_schema.views WHERE table_schema = '||quote_literal(schema_name)||' AND table_name LIKE ''%'||edge_edge_geometry_view_suffix||''' OR table_name LIKE ''%'||interdependency_interdependency_edge_view_suffix||'''' LOOP
        --remove the interdependency and edge views
        EXECUTE 'DROP VIEW IF EXISTS'||quote_ident(information_schema_record.table_name)||' CASCADE';
        EXECUTE 'DELETE FROM '||quote_ident(geometry_columns_table_name)||' WHERE f_table_name = '||quote_literal(information_schema_record.table_name);
    END LOOP;
    
    --remove all records from the graph table
    --remove all records from the geometry_columns table        
    EXECUTE 'DELETE FROM '||quote_ident(global_interdependency_table_name);
    EXECUTE 'DELETE FROM '||quote_ident(graphs_table_name);
    EXECUTE 'DELETE FROM '||quote_ident(geometry_columns_table_name);
    
    --reset graph sequence
    --reset global interdependency sequence
    ALTER SEQUENCE "Graphs_GraphID_seq" RESTART WITH 1;
    ALTER SEQUENCE "Global_Interdependency_InterdependencyID_seq" RESTART WITH 1;

    
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION ni_reset_database(character varying) OWNER TO postgres;
