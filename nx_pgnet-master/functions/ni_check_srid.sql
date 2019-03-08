-- Function: ni_check_srid(integer)

-- DROP FUNCTION ni_check_srid(integer);

CREATE OR REPLACE FUNCTION ni_check_srid(integer)
  RETURNS boolean AS
$BODY$
DECLARE 

    --supplied EPSG code (if -1 then assume an aspatial network i.e. empty geometries for nodes and edges)
    srid ALIAS for $1;
    
    --count of EPSG codes matching given code
    srid_exists integer := 0;
    
BEGIN
	
	--if -1 then assume an aspatial network is being stored
	IF srid < 0 THEN
		RETURN TRUE;
	ELSE
		
		--count of matching EPSG codes
		EXECUTE 'SELECT COUNT(*) FROM spatial_ref_sys WHERE srid = '||srid INTO srid_exists;
		
		--return true if srid exists, false otherwise
		IF srid_exists > 0 THEN
			RETURN TRUE;
		ELSE
			RETURN FALSE;
		END IF;
		
	END IF;
    
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION ni_check_srid(integer) OWNER TO postgres;
