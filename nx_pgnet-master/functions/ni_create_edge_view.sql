-- Function: ni_create_edge_view(character varying)

-- DROP FUNCTION ni_create_edge_view(character varying);

CREATE OR REPLACE FUNCTION ni_create_edge_view(character varying)
  RETURNS character varying AS
$BODY$
DECLARE
    --user supplied table prefix
    table_prefix ALIAS for $1;
    
    --constant edge table suffix
    edge_table_suffix varchar := '_Edges';
    edge_table_name varchar := '';
    
    --constant edge_geometry table suffix
    edge_geometry_table_suffix varchar := '_Edge_Geometry';
    edge_geometry_table_name varchar := '';
    
    --constant value to use for creating the new edge to edge_geometry view (join)
    edge_view_suffix varchar := '_View_Edges_Edge_Geometry';
    new_edge_view_name varchar := '';
    
    --to hold the information on the geometry columns of the edge_geometry table
    SRID integer := 0;
    dims integer := 0;
    
    --geometry_column_record_count
    geometry_column_record_count integer := 0;
        
    --constant geometry column table name
    geometry_column_table_name varchar := 'geometry_columns';
    
    --edge_geometry type
    edge_geometry_type varchar := '';
    
    --schema name
    schema_name varchar := 'public';
    
    geometry_column_name varchar := 'geom';
BEGIN
    --create the new edge view table name
    new_edge_view_name := table_prefix||edge_view_suffix;
    
    --specify the edge table to join
    edge_table_name := table_prefix||edge_table_suffix;
    
    --specify the edge_geometry table to join
    edge_geometry_table_name := table_prefix||edge_geometry_table_suffix;
    
    --create the view by joining the edge and edge_geometry tables for tables with a specific prefix
    --EXECUTE 'CREATE OR REPLACE VIEW '||quote_ident(new_edge_view_name)||' AS SELECT * FROM '||quote_ident(edge_table_name)||', '||quote_ident(edge_geometry_table_name)||' WHERE "EdgeID" = "GeomID"';
    
	--drop view 	
	EXECUTE 'DROP VIEW IF EXISTS'||quote_ident(new_edge_view_name)||' CASCADE';
	
    --this creates a view of the two edge and edge_geometry tables - this works in QGIS
    EXECUTE 'CREATE OR REPLACE VIEW '||quote_ident(new_edge_view_name)||' AS SELECT int4(ROW_NUMBER() over (order by edge_table."EdgeID")) as view_id, edge_table.*, edge_geometry_table.* FROM '||quote_ident(edge_table_name)||' as edge_table, '||quote_ident(edge_geometry_table_name)||' as edge_geometry_table WHERE edge_table."Edge_GeomID" = edge_geometry_table."GeomID"';
    
    --retrieve the SRID of the edge_geometry table
    EXECUTE 'SELECT ST_SRID(geom) FROM '||quote_ident(edge_geometry_table_name) INTO SRID;
    
    --retrieve the dims of the edge_geometry table
    --EXECUTE 'SELECT ST_Dimension(geom) FROM '||quote_ident(edge_geometry_table_name) INTO dims;
	EXECUTE 'SELECT ST_NDims(geom) FROM '||quote_ident(edge_geometry_table_name) INTO dims;
    
    --retrieve the geometry type for the edge geometry table
    EXECUTE 'SELECT GeometryType(geom) FROM '||quote_ident(edge_geometry_table_name) INTO edge_geometry_type;
    
	IF SRID > 0 THEN
		
		--add the edge view to the geometry columns table
		EXECUTE 'SELECT * FROM ni_add_to_geometry_columns('||quote_literal(new_edge_view_name)||', '''', '||quote_literal(schema_name)||', '||quote_literal(geometry_column_name)||', '||dims||','||SRID||','||quote_literal(edge_geometry_type)||')';
		
	ELSE
		
		--add the edge view to the geometry columns table
		EXECUTE 'SELECT * FROM ni_add_to_geometry_columns('||quote_literal(new_edge_view_name)||', '''', '||quote_literal(schema_name)||', '||quote_literal(geometry_column_name)||', 0,'||SRID||','||quote_literal(edge_geometry_type)||')';
	
	END IF;
	
    --return the new view name to the user
    RETURN new_edge_view_name;
    
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION ni_create_edge_view(character varying) OWNER TO postgres;
