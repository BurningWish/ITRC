-- Function: ni_create_interdependency_edge_view(character varying)

-- DROP FUNCTION ni_create_interdependency_edge_view(character varying);

CREATE OR REPLACE FUNCTION ni_create_interdependency_edge_view(character varying)
  RETURNS character varying AS
$BODY$
DECLARE
    
    --table prefix to identify a particular network
    table_prefix ALIAS for $1;
    
    --constant interdependency table suffixes
    interdependency_table_suffix varchar := '_Interdependency';
    interdependency_table_name varchar := '';
    
    --constant interdependency_edge table suffix
    interdependency_edge_table_suffix varchar := '_Interdependency_Edges';
    interdependency_edge_table_name varchar := '';
    
    --constant interdependency view suffix
    interdependency_view_suffix varchar := '_View_Interdependency_Interdependency_Edges';
    new_interdependency_view_name varchar := '';

    --to hold the information on the geometry columns of the interdependency_edges table
    SRID integer := 0;
    dims integer := 0;
    
    --interdependency_edge_geometry type
    interdependency_edge_geometry_type varchar := '';
    
    --constant geometry_columns table name
    geometry_column_table_name varchar := 'geometry_columns';
        
    --geometry_column_record_count
    geometry_column_record_count integer := 0;
    
    --default schema name
    schema_name varchar := 'public';
    
    --geometry column name
    geometry_column_name varchar := 'geom';
    
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
    EXECUTE 'CREATE OR REPLACE VIEW '||quote_ident(new_interdependency_view_name)||' AS SELECT int4(ROW_NUMBER() over (order by i."InterdependencyID")) as id, i.*, ie.geom FROM '||quote_ident(interdependency_table_name)||' AS i, '||quote_ident(interdependency_edge_table_name)||' as ie WHERE i."InterdependencyID" = ie."GeomID"';
    
    --add a new column to the view that acts as a primary key to overcome the issue of QGIS not accepting non-int4 types as primary keys
    --EXECUTE 'ALTER VIEW '||quote_ident(new_interdependency_view_name)||'';
        
    --retrieve the SRID of the edge_geometry table
    EXECUTE 'SELECT ST_SRID(geom) FROM '||quote_ident(interdependency_edge_table_name) INTO SRID;
    
    --retrieve the dims of the edge_geometry table
    EXECUTE 'SELECT ST_Dimension(geom) FROM '||quote_ident(interdependency_edge_table_name) INTO dims;    
        
    --retrieve the geometry type for the interdependency edge geometry table
    EXECUTE 'SELECT GeometryType(geom) FROM '||quote_ident(interdependency_edge_table_name) INTO interdependency_edge_geometry_type;
    
	--add the interdependency view to the geometry columns table
	EXECUTE 'SELECT * FROM ni_add_to_geometry_columns('||quote_literal(new_interdependency_view_name)||', '''', '||quote_literal(schema_name)||', '||quote_literal(geometry_column_name)||', '||dims||','||SRID||','||quote_literal(interdependency_edge_geometry_type)||')';
	
    --return the new view name to the user
    RETURN new_interdependency_view_name;    
    
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION ni_create_interdependency_edge_view(character varying) OWNER TO postgres;
