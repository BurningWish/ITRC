
CREATE OR REPLACE FUNCTION ni_edge_geometry_equality_check(character varying, character varying, integer)
  RETURNS integer AS
$BODY$ 
DECLARE
    --table prefix used to identify which edge_geometry tables to check
    table_prefix ALIAS for $1;    
    
    --geometry as WKT to compare against
    geometry_to_compare ALIAS for $2;
    
    --srid of new geometry
    SRID ALIAS for $3;
    
    --geometry ID of matched edge_geometry record (do we need this to be a value only we know e.g. -1)
    matched_geom_id integer := -1;
    
    --edge geometry table name derived from table_prefix and edge_geometry_table_suffix
    edge_geometry_table_name varchar := '';
    --constant suffixes used on different network tables
    edge_geometry_table_suffix varchar := '_Edge_Geometry';
BEGIN
    
    --create edge_geometry table name
    edge_geometry_table_name := table_prefix||edge_geometry_table_suffix;
    
    --check equality against currently stored geometries
    EXECUTE 'SELECT edge_geometry_table."GeomID" FROM '||quote_ident(edge_geometry_table_name)||' AS edge_geometry_table WHERE ST_Equals(ST_GeomFromText('||quote_literal(geometry_to_compare)||', '||SRID||'), edge_geometry_table.geom)' INTO matched_geom_id;
	
	--return matched geometry id
    RETURN matched_geom_id;
    
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION ni_edge_geometry_equality_check(character varying, character varying, integer) OWNER TO postgres;
