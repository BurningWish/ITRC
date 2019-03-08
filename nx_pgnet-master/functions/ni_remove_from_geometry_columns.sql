-- Function: ni_remove_from_geometry_columns(character varying, character varying, character varying, character varying, integer, integer)

-- DROP FUNCTION ni_remove_from_geometry_columns(character varying, character varying, character varying, character varying, integer, integer);

CREATE OR REPLACE FUNCTION ni_remove_from_geometry_columns(character varying, character varying, character varying, character varying, integer, integer)
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
    coordinate_dimension ALIAS for $5;
    
    --coordinate reference system (EPSG code)
    SRID ALIAS for $6;
        
    --geometry_column_table_name
    geometry_column_table_name varchar := 'geometry_columns';
	
	--to store count of geometry column records with same values
    geometry_column_record_exists integer := 0;

	--to store if supplied srid exists
    srid_exists boolean := FALSE;
BEGIN

    EXECUTE 'SELECT * FROM ni_check_srid('||srid||')' INTO srid_exists;
    
    IF srid_exists IS FALSE THEN
        RETURN FALSE;
    ELSE 
        
		EXECUTE 'DELETE FROM '||quote_ident(geometry_column_table_name)'|| WHERE f_table_catalog = '||quote_literal(table_catalog)||' AND f_table_schema = '||quote_literal(table_schema)||' AND f_table_name = '||quote_literal(table_name)||' AND f_geometry_column = '||quote_literal(geometry_column_name)||' AND coord_dimension = '||coordinate_dimension||' AND srid = '||SRID;
		
        RETURN TRUE;
    END IF;

RETURN FALSE;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION ni_remove_from_geometry_columns(character varying, character varying, character varying, character varying, integer, integer) OWNER TO postgres;
