
CREATE OR REPLACE FUNCTION ni_node_separation_distance(character varying, character varying, integer, integer)
  RETURNS integer AS
$BODY$ 
DECLARE
    --table prefix used to identify which node_geometry tables to check
    table_prefix ALIAS for $1;    
    
    --geometry as WKT to compare against
    geometry_to_compare ALIAS for $2;
    
    --srid of new geometry
    SRID ALIAS for $3;
    
	node_id_to_compare ALIAS for $4;
	
    --geometry ID of matched node_geometry record (do we need this to be a value only we know e.g. -1)
    distance float := 0;
    
    --edge geometry table name derived from table_prefix and node_table_suffix
    node_table_name varchar := '';
    --constant suffixes used on different network tables
    node_table_suffix varchar := '_Nodes';
BEGIN
    
    --create node_geometry table name
    node_table_name := table_prefix||node_table_suffix;
    
    --check equality against currently stored geometries
    EXECUTE 'SELECT ST_Distance(ST_GeomFromText('||quote_literal(geometry_to_compare)||', '||SRID||'), node_geometry_table.geom) FROM '||quote_ident(node_table_name)||' as node_geometry_table WHERE "NodeID" = '||node_id_to_compare INTO distance;
	
    RETURN distance;
    
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION ni_node_separation_distance(character varying, character varying, integer, integer) OWNER TO postgres;
