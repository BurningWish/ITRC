
CREATE OR REPLACE FUNCTION ni_check_record_geometry_columns_table_post_graph_insert()
  RETURNS trigger AS
$BODY$
DECLARE
    --constant Graphs table name
    graphs_table_name varchar := 'Graphs';
    
    --postgis geometry_columns table, table name
    geometry_columns_table_name varchar := 'geometry_columns';
    
    --new node table added
    new_node_table_name varchar := '';
    
    --new edge table added
    new_edge_table_name varchar := '';
    
    --equivalent edge_geometry table added
    new_edge_geometry_table_name varchar := '';
    equivalent_edge_geometry_suffix varchar := 'Edge_Geometry';
    
    --constant 'Edges' table suffix
    edges_table_suffix varchar := 'Edges';
    
	--stores position of _Edges suffix in edge table name	
    pos integer := 0;
	
	--will store the base Edge table name
    base_table_name varchar := '';
    
    --checks for existence of node or edge geometry tables
    node_table_exists boolean := FALSE;
    edge_geometry_table_exists boolean := FALSE;
    
	--default values
	default_schema_name varchar := 'public';
	default_geometry_column_name varchar := 'geom';	
	
BEGIN

    --newly added node table name
    new_node_table_name := NEW."Nodes";
    
    --newly added edge table name
    new_edge_table_name := NEW."Edges";
    pos := position(edges_table_suffix in new_edge_table_name);
    base_table_name := substring(new_edge_table_name FROM 0 FOR pos);
    
    --equivalent edge geometry table name
    new_edge_geometry_table_name := base_table_name||equivalent_edge_geometry_suffix;
    
    --determine if the newly added nodes and edge_geometry tables have been registered against the geometry columns table
    EXECUTE 'SELECT EXISTS(SELECT * FROM '||quote_ident(geometry_columns_table_name)||' WHERE f_table_name = '||quote_literal(new_node_table_name)||')' INTO node_table_exists;
    EXECUTE 'SELECT EXISTS(SELECT * FROM '||quote_ident(geometry_columns_table_name)||' WHERE f_table_name = '||quote_literal(new_edge_geometry_table_name)||')' INTO edge_geometry_table_exists;
    
    IF node_table_exists IS TRUE AND edge_geometry_table_exists IS TRUE THEN
        RETURN NULL;
    ELSE
        --node table does not exist in the geometry columns table
        IF node_table_exists IS FALSE THEN
            EXECUTE 'INSERT INTO '||quote_ident(geometry_columns_table_name)||' (f_table_catalog, f_table_schema, f_table_name, f_geometry_column, coord_dimension, srid, "type") SELECT '''', ''public'', '||quote_literal(new_node_table_name)||',''geom'', ST_CoordDim(geom), ST_SRID(geom), GeometryType(geom) FROM '||quote_ident(new_node_table_name)||' LIMIT 1';
        END IF;
        
        --edge_geometry table does not exist in the geometry columns table
        IF edge_geometry_table_exists IS FALSE THEN
            EXECUTE 'INSERT INTO '||quote_ident(geometry_columns_table_name)||' (f_table_catalog, f_table_schema, f_table_name, f_geometry_column, coord_dimension, srid, "type") SELECT '''', '||quote_literal(default_schema_name)||', '||quote_literal(new_edge_geometry_table_name)||','||quote_literal(default_geometry_column_name)||', ST_CoordDim('||quote_ident(default_geometry_column_name)||'), ST_SRID('||quote_ident(default_geometry_column_name)||'), GeometryType('||quote_ident(default_geometry_column_name)||') FROM '||quote_ident(new_edge_geometry_table_name)||' LIMIT 1';
        END IF;
    END IF;
    
RETURN NULL;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION ni_check_record_geometry_columns_table_post_graph_insert() OWNER TO postgres;
