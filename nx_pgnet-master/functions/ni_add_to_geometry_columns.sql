-- Function: ni_add_to_geometry_columns(character varying, character varying, character varying, character varying, integer, integer, character varying)

-- DROP FUNCTION ni_add_to_geometry_columns(character varying, character varying, character varying, character varying, integer, integer, character varying);

CREATE OR REPLACE FUNCTION ni_add_to_geometry_columns(character varying, character varying, character varying, character varying, integer, integer, character varying)
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
    
    --geometry type e.g. POINT, LINESTRING
    geometry_type ALIAS for $7;
    
    --geometry_column_table_name
    geometry_column_table_name varchar := 'geometry_columns';
	
	--to store whether record of same values already exists
    geometry_column_record_exists integer := 0;
	
	--to store whether the given SRID exists in the spatial_ref_sys PostGIS geometry_columns table
    srid_exists boolean := FALSE;
BEGIN
	
	--check whether the given srid exists
    EXECUTE 'SELECT * FROM ni_check_srid('||srid||')' INTO srid_exists;
    	
    IF srid_exists IS FALSE THEN		
        RETURN FALSE;
    ELSE 
        
		--count records from geometry_columns table of same given values (to determine if record of same values already exists)
        EXECUTE 'SELECT COUNT(*) FROM '||quote_ident(geometry_column_table_name)||' WHERE f_table_catalog = '||quote_literal(table_catalog)||' AND f_table_schema = '||quote_literal(table_schema)||' AND f_table_name = '||quote_literal(table_name)||' AND f_geometry_column = '||quote_literal(geometry_column_name)||' AND coord_dimension = '||coordinate_dimension||' AND srid = '||SRID INTO geometry_column_record_exists;
        
        IF geometry_column_record_exists < 1 THEN
            --insert a record into the geometry_columns table
            EXECUTE 'INSERT INTO '||quote_ident(geometry_column_table_name)||' (f_table_catalog, f_table_schema, f_table_name, f_geometry_column, coord_dimension, srid, "type") VALUES ('||quote_literal(table_catalog)||', '||quote_literal(table_schema)||', '||quote_literal(table_name)||', '||quote_literal(geometry_column_name)||', '||coordinate_dimension||', '||srid||', '||quote_literal(geometry_type)||')';
        END IF;
        RETURN TRUE;
    END IF;

RETURN FALSE;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION ni_add_to_geometry_columns(character varying, character varying, character varying, character varying, integer, integer, character varying) OWNER TO postgres;
