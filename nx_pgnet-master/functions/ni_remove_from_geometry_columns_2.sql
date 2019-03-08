-- Function: ni_remove_from_geometry_columns(character varying, character varying, character varying, character varying, integer, integer, character varying)

-- DROP FUNCTION ni_remove_from_geometry_columns(character varying, character varying, character varying, character varying, integer, integer, character varying);

CREATE OR REPLACE FUNCTION ni_remove_from_geometry_columns(character varying, character varying, character varying, character varying, integer, integer, character varying)
  RETURNS boolean AS
$BODY$ 
DECLARE
--table name to insert
    table_name ALIAS for $1;

    --table_catalog
    table_catalog ALIAS for $2;
    
    --table schema
    table_schema ALIAS for $3;
    
    --table geometry column name
    geometry_column_name ALIAS for $4;
    
    --coordinate dimensions of input geometry
    coord_dim ALIAS for $5;
    
    --coordinate reference system (EPSG code)
    SRID ALIAS for $6;
    
    --geometry type e.g. POINT, LINESTRING
    geometry_type ALIAS for $7;
    
    --geometry_column_table_name
    geometry_column_table_name varchar := 'geometry_columns';
    geometry_column_record_exists integer := 0;

    srid_exists boolean := FALSE;
BEGIN

    EXECUTE 'SELECT * FROM ni_check_srid('||srid||')' INTO srid_exists;
    
    IF srid_exists IS FALSE THEN
        RETURN FALSE;
    ELSE 
        
		EXECUTE 'DELETE FROM '||quote_ident(geometry_column_table_name)'|| WHERE f_table_catalog = '||quote_literal(table_catalog)||' AND f_table_schema = '||quote_literal(table_schema)||' AND f_table_name = '||quote_literal(table_name)||' AND f_geometry_column = '||quote_literal(geometry_column_name)||' AND coord_dimension = '||coord_dim||' AND srid = '||SRID;
		
        RETURN TRUE;
    END IF;

RETURN FALSE;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION ni_remove_from_geometry_columns(character varying, character varying, character varying, character varying, integer, integer, character varying) OWNER TO postgres;
