
CREATE OR REPLACE FUNCTION ni_create_interdependency_edge_view(character varying, character varying, character varying, integer, integer)
  RETURNS character varying AS
$BODY$
DECLARE
    
    --user supplied table prefix
    table_prefix ALIAS for $1;
    
	--schema name
    schema_name ALIAS for $2;
    
	--geometry column name for Edge_Geometry table
    geometry_column_name ALIAS for $3;
	
    --to store SRID of geometry in Edge_Geometry table
    SRID ALIAS for $4;
	
	--to store coordinate dimension of coordinates in geometry of Edge_Geometry table
    coordinate_dimension ALIAS for $5;
	
    --constant interdependency table suffixes
    interdependency_table_suffix varchar := '_Interdependency';
    interdependency_table_name varchar := '';
    
    --constant interdependency_edge table suffix
    interdependency_edge_table_suffix varchar := '_Interdependency_Edges';
    interdependency_edge_table_name varchar := '';
    
    --constant interdependency view suffix
    interdependency_view_suffix varchar := '_View_Interdependency_Interdependency_Edges';
    new_interdependency_view_name varchar := '';

    --interdependency_edge_geometry type
    interdependency_edge_geometry_type varchar := '';
    
    --constant geometry_columns table name
    geometry_column_table_name varchar := 'geometry_columns';
        
    --geometry_column_record_count
    geometry_column_record_count integer := 0;

    
BEGIN

    --create the new edge view table name
    new_interdependency_view_name := table_prefix||interdependency_view_suffix;
    
    --specify the interdependency table to join
    interdependency_table_name := table_prefix||interdependency_table_suffix;
    
    --specify the interdependency_edge table to join
    interdependency_edge_table_name := table_prefix||interdependency_edge_table_suffix;
	
	--drop view
	EXECUTE 'DROP VIEW IF EXISTS'||quote_ident(new_interdependency_view_name)||' CASCADE';		

    --create the view by joining the interdependency and interdependency_edge tables for tables with a specific prefix    
    EXECUTE 'CREATE OR REPLACE VIEW '||quote_ident(new_interdependency_view_name)||' AS SELECT int4(ROW_NUMBER() over (order by i."InterdependencyID")) as view_id, i.*, ie.geom FROM '||quote_ident(interdependency_table_name)||' AS i, '||quote_ident(interdependency_edge_table_name)||' as ie WHERE i."InterdependencyID" = ie."GeomID"';
    
    --retrieve the SRID of the edge_geometry table
    EXECUTE 'SELECT ST_SRID(geom) FROM '||quote_ident(interdependency_edge_table_name) INTO SRID;
    
    --retrieve the coordinate_dimension of the edge_geometry table
    --EXECUTE 'SELECT ST_Dimension(geom) FROM '||quote_ident(interdependency_edge_table_name) INTO coordinate_dimension;    
	EXECUTE 'SELECT ST_NDims(geom) FROM '||quote_ident(interdependency_edge_table_name) INTO coordinate_dimension;    
        
    --retrieve the geometry type for the interdependency edge geometry table
    EXECUTE 'SELECT GeometryType(geom) FROM '||quote_ident(interdependency_edge_table_name) INTO interdependency_edge_geometry_type;
    
	IF SRID > 0 THEN
	
		--add the interdependency view to the geometry columns table
		EXECUTE 'SELECT * FROM ni_add_to_geometry_columns('||quote_literal(new_interdependency_view_name)||', '''', '||quote_literal(schema_name)||', '||quote_literal(geometry_column_name)||', '||coordinate_dimension||','||SRID||','||quote_literal(interdependency_edge_geometry_type)||')';
		
	ELSE
	
		--add the interdependency view to the geometry columns table
		EXECUTE 'SELECT * FROM ni_add_to_geometry_columns('||quote_literal(new_interdependency_view_name)||', '''', '||quote_literal(schema_name)||', '||quote_literal(geometry_column_name)||', 0,'||SRID||','||quote_literal(interdependency_edge_geometry_type)||')';
	
	END IF;
	
    --return the new view name to the user
    RETURN new_interdependency_view_name;    
    
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION ni_create_interdependency_edge_view(character varying, character varying, character varying, integer, integer) OWNER TO postgres;
