CREATE OR REPLACE FUNCTION ni_check_record_geometry_columns_table_post_graph_nodes_update()
  RETURNS trigger AS
$BODY$
DECLARE
    --newly updated node table name
    updated_node_value varchar := '';
    
    --checking if node table of newly updated name exists in the geometry columns table
    node_table_exists boolean := FALSE;
    
    --constant geometry columns table
    geometry_columns_table_name varchar := 'geometry_columns';

	--default values
	default_schema_name varchar := 'public';
	default_geometry_column_name varchar := 'geom';	
	
BEGIN
    --newly changed node table
    updated_node_value := NEW."Nodes";
	
	--checks to see if the node table already exists in the geometry columns table
    EXECUTE 'SELECT EXISTS(SELECT * FROM '||quote_ident(geometry_columns_table_name)||' WHERE f_table_name = '||quote_literal(updated_node_value) INTO node_table_exists;
    
    IF node_table_exists IS TRUE THEN
        RETURN NULL;
    ELSE
        --add a new record to the geometry columns table
        EXECUTE 'INSERT INTO '||quote_ident(geometry_columns_table_name)||' (f_table_catalog, f_table_schema, f_table_name, f_geometry_column, coord_dimension, srid, "type") SELECT '''', '||quote_literal(default_schema_name)||', '||quote_literal(updated_node_value)||','||quote_literal(default_geometry_column_name)||', ST_CoordDim('||quote_ident(default_geometry_column_name)||'), ST_SRID('||quote_ident(default_geometry_column_name)||'), GeometryType('||quote_ident(default_geometry_column_name)||') FROM '||quote_ident(updated_node_value)||' LIMIT 1';
        
    END IF; 
    
RETURN NULL;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION ni_check_record_geometry_columns_table_post_graph_nodes_update() OWNER TO postgres;
