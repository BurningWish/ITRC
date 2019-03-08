-- Function: ni_node_geometry_equality_check(character varying, character varying, integer)

-- DROP FUNCTION ni_node_geometry_equality_check(character varying, character varying, integer);

CREATE OR REPLACE FUNCTION ni_node_geometry_equality_check(character varying, character varying, integer)
  RETURNS integer AS
$BODY$ 
DECLARE
    --table prefix used to identify which node tables to check
    table_prefix ALIAS for $1;    
    
    --geometry as WKT to compare against
    geometry_to_compare ALIAS for $2;
    
    --srid of new geometry
    SRID ALIAS for $3;
    
    --geometry ID of matched node record (do we need this to be a value only we know e.g. -1)
    matched_node_id integer := -1;

    --node geometry table name derived from table_prefix and node_table_suffix
    node_table_name varchar := '';
    --constant suffixes used on different network tables
    node_table_suffix varchar := '_Nodes';

BEGIN

    --create node table name
    node_table_name := table_prefix||node_table_suffix;
    
    --check equality against currently stored geometries
    EXECUTE 'SELECT node_table."NodeID" FROM '||quote_ident(node_table_name)||' AS node_table WHERE ST_Equals(ST_GeomFromText('||quote_literal(geometry_to_compare)||', '||SRID||'), node_table.geom)' INTO matched_node_id;
	
	--return matched node id
    RETURN matched_node_id;
    
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION ni_node_geometry_equality_check(character varying, character varying, integer) OWNER TO postgres;
