-- Function: ni_edge_snap_geometry_equality_check(character varying, character varying, integer, double precision)

-- DROP FUNCTION ni_edge_snap_geometry_equality_check(character varying, character varying, integer, double precision);

CREATE OR REPLACE FUNCTION ni_edge_snap_geometry_equality_check(character varying, character varying, integer, double precision)
  RETURNS integer AS
$BODY$ 
DECLARE
    --table prefix used to identify which edge_geometry tables to check
    table_prefix ALIAS for $1;    
    
    --geometry as WKT to compare against
    geometry_to_compare ALIAS for $2;
    
    --srid of new geometry
    SRID ALIAS for $3;
	
	--snap precision
	snap_precision ALIAS for $4;
    
    --geometry ID of matched edge_geometry record (do we need this to be a value only we know e.g. -1)
    matched_edge_id integer := -1;

    --edge geometry table name derived from table_prefix and edge_table_suffix
    edge_table_name varchar := '';
    --constant suffixes used on different network tables
    edge_table_suffix varchar := '_Edges';

BEGIN

    --create edge table name
    edge_table_name := table_prefix||edge_table_suffix;
    
    --check equality against currently stored geometries
    EXECUTE 'SELECT edge_table."edgeID" FROM '||quote_ident(edge_table_name)||' AS edge_table WHERE ST_Equals(ST_SnapToGrid(ST_GeomFromText('||quote_literal(geometry_to_compare)||', '||SRID||'), '||snap_precision||'), edge_table.geom)' INTO matched_edge_id;
	
	--return matched edge id
    RETURN matched_edge_id;
    
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION ni_edge_snap_geometry_equality_check(character varying, character varying, integer, double precision) OWNER TO postgres;
