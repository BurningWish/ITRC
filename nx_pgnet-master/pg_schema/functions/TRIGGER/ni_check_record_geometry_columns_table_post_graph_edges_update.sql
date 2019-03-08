
CREATE OR REPLACE FUNCTION ni_check_record_geometry_columns_table_post_graph_edges_update()
  RETURNS trigger AS
$BODY$
DECLARE
    --new edge table name
    updated_edge_value varchar := '';
    
    --check for existence of edge_geometry column in geometry_columns table
    edge_geometry_table_exists boolean := FALSE;
    
    --constant edge_geometry table name
    geometry_columns_table_name varchar := 'geometry_columns';
	
	--stores position of _Edges suffix in edge table name
    pos integer := 0;
	
	--will store the base Edge table name
    base_table_name varchar := '';
	
	--to store the equivalent Edge_Geometry table name
    new_edge_geometry_table_name varchar := '';
	
	--constant edge and edge_geometry table suffixes
	edge_table_suffix varchar := '_Edges';
	edge_geometry_table_suffix varchar := '_Edge_Geometry';
	
	--default values
	default_schema_name varchar := 'public';
	default_geometry_column_name varchar := 'geom';	
	
BEGIN
    --new edge table name
    updated_edge_value := NEW."Edges";
    
    --to determine prefix (or base table name)
    pos := position(edge_table_suffix in updated_edge_value);
    base_table_name := substring(updated_edge_value FROM 0 FOR pos);
    
    --equivalent edge geometry table name
    new_edge_geometry_table_name := base_table_name||edge_geometry_table_suffix;
    
	--check if table with given edge_geometry table name already exists
    EXECUTE 'SELECT EXISTS(SELECT * FROM '||quote_ident(geometry_columns_table_name)||' WHERE f_table_name = '||quote_literal(new_edge_geometry_table_name)||')' INTO edge_geometry_table_exists;
    
    IF edge_geometry_table_exists IS TRUE THEN
        RETURN NULL;
    ELSE
        --add a new record to the geometry_columns table 
        EXECUTE 'INSERT INTO '||quote_ident(geometry_columns_table_name)||' (f_table_catalog, f_table_schema, f_table_name, f_geometry_column, coord_dimension, srid, "type") SELECT '''', '||quote_literal(default_schema_name)||', '||quote_literal(new_edge_geometry_table_name)||','||quote_literal(default_geometry_column_name)||', ST_CoordDim('||quote_ident(default_geometry_column_name)||'), ST_SRID('||quote_ident(default_geometry_column_name)||'), ST_GeometryType('||quote_ident(default_geometry_column_name)||') FROM '||quote_ident(new_edge_geometry_table_name)||' LIMIT 1';
        
    END IF; 
    
RETURN NULL;

END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION ni_check_record_geometry_columns_table_post_graph_edges_update() OWNER TO postgres;
