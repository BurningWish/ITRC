-- Function: ni_create_node_view(character varying)

-- DROP FUNCTION ni_create_node_view(character varying);

CREATE OR REPLACE FUNCTION ni_create_node_view(character varying)
  RETURNS character varying AS
$BODY$
DECLARE
    --user supplied table prefix
    table_prefix ALIAS for $1;
    
    --constant node table suffix
    node_table_suffix varchar := '_Nodes';
    node_view_suffix varchar := '_View_Nodes';
    new_node_view_name varchar := '';
    node_table_name varchar := '';
	
    --to hold the information on the geometry columns of the node table
    SRID integer := 0;
    dims integer := 0;
    
    --geometry_column_record_count
    geometry_column_record_count integer := 0;
    
    --node type
    node_geometry_type varchar := '';
    
    --constant geometry column table name
    geometry_column_table_name varchar := 'geometry_columns';
    
    schema_name varchar := 'public';
    
    geometry_column_name varchar := 'geom';
BEGIN
    
    --original node table name
    node_table_name := table_prefix||node_table_suffix;
    
    --create the new node view table name
    new_node_view_name := table_prefix||node_view_suffix;

	--drop the view	
	EXECUTE 'DROP VIEW IF EXISTS'||quote_ident(new_node_view_name)||' CASCADE';
	
    --create node view
    EXECUTE 'CREATE OR REPLACE VIEW '||quote_ident(new_node_view_name)||' AS SELECT int4(ROW_NUMBER() over (order by node_table."NodeID")) as view_id, node_table.* FROM '||quote_ident(node_table_name)||' as node_table';
    
    --retrieve the SRID of the node view
    EXECUTE 'SELECT ST_SRID(geom) FROM '||quote_ident(node_table_name) INTO SRID;
    
    --retrieve the dims of the node view
    --EXECUTE 'SELECT ST_Dimension(geom) FROM '||quote_ident(node_table_name) INTO dims;
	EXECUTE 'SELECT ST_NDims(geom) FROM '||quote_ident(node_table_name) INTO dims;
    
    --retrieve the geometry type for the node view
    EXECUTE 'SELECT GeometryType(geom) FROM '||quote_ident(node_table_name) INTO node_geometry_type;
    
	IF SRID > 0 THEN
		
		--add the node view to the geometry columns table
		EXECUTE 'SELECT * FROM ni_add_to_geometry_columns('||quote_literal(new_node_view_name)||', '''', '||quote_literal(schema_name)||', '||quote_literal(geometry_column_name)||', '||dims||','||SRID||','||quote_literal(node_geometry_type)||')';
		--return the new view name to the user
		RETURN new_node_view_name;
		
	ELSE
		
		--add the node view to the geometry columns table
		EXECUTE 'SELECT * FROM ni_add_to_geometry_columns('||quote_literal(new_node_view_name)||', '''', '||quote_literal(schema_name)||', '||quote_literal(geometry_column_name)||', 0,'||SRID||','||quote_literal(node_geometry_type)||')';
		--return the new view name to the user
		RETURN new_node_view_name;
		
	END IF;
	
	
    
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION ni_create_node_view(character varying) OWNER TO postgres;
