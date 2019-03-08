
CREATE OR REPLACE FUNCTION ni_create_network_table_edge_geometry(character varying, integer)
  RETURNS boolean AS
$BODY$ 
DECLARE
    --constant edge geometry table suffix
    edge_geometry_table_suffix varchar := '_Edge_Geometry';
    
    --base edge table to inherit from
    inherit_edge_geometry_table_name varchar := 'Edge_Geometry';
    
    --new edge table name to create
    new_edge_geometry_table_name varchar := '';
    
    --supplied table prefix e.g. Electricity
    table_prefix ALIAS for $1;    
    
    --SRID (EPSG code) of data to be stored in table of name new_edge_geometry_table_name_table_name
    table_srid ALIAS for $2;
    
    --boolean to store check if the supplied SRID is valid i.e. exists in spatial_ref_sys
    srid_exists boolean := FALSE;
    
    --boolean to store check if an edge_geometry table already exists
    edge_geometry_table_exists boolean := FALSE;    

    --constants (could be exposed as parameters)
    schema_name varchar := 'public';
    geometry_column_name varchar := 'geom';
    dims integer := 2;
    --need to decide whether this is going to cause a problem, or whether we can make this a parameter to feed in to the function
    edge_geometry_type varchar := 'LINESTRING';
    --edge_geometry_type varchar := 'GEOMETRY';
    
    
BEGIN

    --create the new edge geometry table name
    new_edge_geometry_table_name := table_prefix||edge_geometry_table_suffix;
    
    --check to see that the SRID supplied is valid
    EXECUTE 'SELECT * FROM ni_check_srid('||table_srid||')' INTO srid_exists;    
    
	--check if the edge geometry table exists
    EXECUTE 'SELECT EXISTS (SELECT * FROM information_schema.tables WHERE table_name = '||quote_literal(new_edge_geometry_table_name)||')' INTO edge_geometry_table_exists;
	
    --the supplied srid code does not exist in the spatial_ref_sys table on the current database i.e. an invalid SRID integer has been supplied
	--(-1 is allowed to denote an aspatial network where node and edge geometries are both empty)
    IF srid_exists IS FALSE THEN
        RETURN FALSE;
    END IF;
    
    IF edge_geometry_table_exists IS TRUE THEN
        --if the equivalent edge_geometry table does exist, return FALSE
        RETURN FALSE;
    ELSE
        --create the edge_geometry table        
        EXECUTE 'CREATE TABLE '||quote_ident(new_edge_geometry_table_name)||'() INHERITS ('||quote_ident(inherit_edge_geometry_table_name)||')';

        EXECUTE 'ALTER TABLE '||quote_ident(new_edge_geometry_table_name)||' ADD CONSTRAINT "enforce_srid_geom" CHECK (st_srid(geom) = '||table_srid||')';
        
		--add the enforce_dims check
		EXECUTE 'ALTER TABLE '||quote_ident(new_edge_geometry_table_name)||' ADD CONSTRAINT "enforce_dims_geom" CHECK (st_ndims('||quote_ident(geometry_column_name)||') = 2)';
		
		--add the enforce_geotype check
		EXECUTE 'ALTER TABLE '||quote_ident(new_edge_geometry_table_name)||' ADD CONSTRAINT "enforce_geotype_geom" CHECK (geometrytype('||quote_ident(geometry_column_name)||') = ''MULTILINESTRING''::text OR geometrytype('||quote_ident(geometry_column_name)||') = ''LINESTRING''::text OR '||quote_ident(geometry_column_name)||' IS NULL)';
		
        --to ensure that a new sequence exists for each new edge table
        EXECUTE 'ALTER TABLE '||quote_ident(new_edge_geometry_table_name)||' ADD COLUMN "GeomID" bigserial';
        
        --to ensure that the new sequence is used as the primary key
        EXECUTE 'ALTER TABLE '||quote_ident(new_edge_geometry_table_name)||' ADD CONSTRAINT '||new_edge_geometry_table_name||'_prkey PRIMARY KEY ("GeomID")';
        
		IF table_srid > 0 THEN
		
			--add the edge_geometry table to the geometry_columns table
			EXECUTE 'SELECT * FROM ni_add_to_geometry_columns('||quote_literal(new_edge_geometry_table_name)||', '''', '||quote_literal(schema_name)||', '||quote_literal(geometry_column_name)||', '||dims||','||table_srid||','||quote_literal(edge_geometry_type)||')';
			
		ELSE
			
			EXECUTE 'SELECT * FROM ni_add_to_geometry_columns('||quote_literal(new_edge_geometry_table_name)||', '''', '||quote_literal(schema_name)||', '||quote_literal(geometry_column_name)||', 0,'||table_srid||',''LINESTRING EMPTY'')';
			
		END IF;	
        
		--aspatial network being stored 
		IF table_srid < 0 THEN
			
			--drop the srid constraint
			EXECUTE 'ALTER TABLE '||quote_ident(new_edge_geometry_table_name)||' DROP CONSTRAINT "enforce_srid_geom"';
			--drop the enforce_dims constraint
			EXECUTE 'ALTER TABLE '||quote_ident(new_edge_geometry_table_name)||' DROP CONSTRAINT "enforce_dims_geom"';
			--drop the enforce_geotype constraint
			EXECUTE 'ALTER TABLE '||quote_ident(new_edge_geometry_table_name)||' DROP CONSTRAINT "enforce_geotype_geom"';
			
		END IF;
		
        RETURN TRUE;
    END IF;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION ni_create_network_table_edge_geometry(character varying, integer) OWNER TO postgres;
