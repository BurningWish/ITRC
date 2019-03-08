
CREATE OR REPLACE FUNCTION ni_create_network_table_nodes(character varying, character varying, character varying, integer, integer)
  RETURNS boolean AS
$BODY$ 
DECLARE
	
	--unique table prefix e.g. Electricity
    table_prefix ALIAS for $1;
    	
    --schema name
    schema_name ALIAS for $2;
	
	--node geometry column name
    node_geometry_column_name ALIAS for $3;
	
    --SRID (EPSG code) of data to be stored in table of name new_node_table_name
    table_srid ALIAS for $4;
	
	--coord dim
    node_geometry_coordinate_dim ALIAS for $5;
	
    --constant node table suffix
    node_table_suffix varchar := '_Nodes';
    
    --base node table to inherit from
    inherit_node_table_name varchar := 'Nodes';
    
    --new node table name to create
    new_node_table_name varchar := '';
    
    --boolean to store check if table of new_node_table_name already exists
    table_exists boolean := FALSE;
    
    --boolean to store check if the supplied SRID is valid i.e. exists in spatial_ref_sys
    srid_exists boolean := FALSE;
    
    --node_geometry_type
    node_geometry_type varchar := 'POINT';
    
    --default catalog name
    catalog_name varchar := '';
BEGIN

    --set the new node table name
    new_node_table_name := table_prefix||node_table_suffix;

    --check to see if the new node table to be created already exists
    EXECUTE 'SELECT EXISTS (SELECT * FROM information_schema.tables WHERE table_name = '||quote_literal(new_node_table_name)||')' INTO table_exists;
    
    --check to see that the SRID supplied is valid
    EXECUTE 'SELECT * FROM ni_check_srid('||table_srid||')' INTO srid_exists;    
    
    --the supplied srid code does not exist in the spatial_ref_sys table on the current database i.e. an invalid SRID integer has been supplied
	--(-1 is allowed to denote an aspatial network where node and edge geometries are both empty)
    IF srid_exists IS FALSE THEN
        RETURN FALSE;
    END IF;
    
    IF table_exists IS TRUE THEN
        --if a table of <table_prefix>_Nodes already exists in the database, return FALSE
        RETURN FALSE;
    ELSE
       
        --create the node table based on the provided table suffix (arg1) and the constant node_table_suffix, by inheriting from the base node table (inherit_node_table_name)        
        EXECUTE 'CREATE TABLE '||quote_ident(new_node_table_name)||'() INHERITS ('||quote_ident(inherit_node_table_name)||')';

        --add spatial constraints - srid check             
        EXECUTE 'ALTER TABLE '||quote_ident(new_node_table_name)||' ADD CONSTRAINT "enforce_srid_geom" CHECK (st_srid(geom) = '||table_srid||')';
        
		--add the enforce_dims check
		EXECUTE 'ALTER TABLE '||quote_ident(new_node_table_name)||' ADD CONSTRAINT "enforce_dims_geom" CHECK (st_ndims('||quote_ident(node_geometry_column_name)||') = 2)';
		
		--add the enforce_geotype check
		EXECUTE 'ALTER TABLE '||quote_ident(new_node_table_name)||' ADD CONSTRAINT "enforce_geotype_geom" CHECK (geometrytype('||quote_ident(node_geometry_column_name)||') = ''POINT''::text OR '||quote_ident(node_geometry_column_name)||' IS NULL)';
		
        --to ensure that a new sequence exists for each new node table
        EXECUTE 'ALTER TABLE '||quote_ident(new_node_table_name)||' ADD COLUMN "NodeID" bigserial';
        
        --to ensure that the new sequence is used as the primary key
        EXECUTE 'ALTER TABLE '||quote_ident(new_node_table_name)||' ADD CONSTRAINT '||new_node_table_name||'_prkey PRIMARY KEY ("NodeID")';       
        
		IF table_srid > 0 THEN
		
			--add this new node table to the geometry columns table
			EXECUTE 'SELECT * FROM ni_add_to_geometry_columns('||quote_literal(new_node_table_name)||', '||quote_literal(catalog_name)||', '||quote_literal(schema_name)||', '||quote_literal(node_geometry_column_name)||', '||node_geometry_coordinate_dim||','||table_srid||','||quote_literal(node_geometry_type)||')';
		
		ELSE
			
			--add this new node table to the geometry columns table
			EXECUTE 'SELECT * FROM ni_add_to_geometry_columns('||quote_literal(new_node_table_name)||', '||quote_literal(catalog_name)||', '||quote_literal(schema_name)||', '||quote_literal(node_geometry_column_name)||', 0,'||table_srid||',''POINT EMPTY'')';
			
		END IF;
        
		--aspatial network being stored 
		IF table_srid < 0 THEN
			
			--drop the srid constraint
			EXECUTE 'ALTER TABLE '||quote_ident(new_node_table_name)||' DROP CONSTRAINT "enforce_srid_geom"';
			--drop the enforce_dims constraint
			EXECUTE 'ALTER TABLE '||quote_ident(new_node_table_name)||' DROP CONSTRAINT "enforce_dims_geom"';
			--drop the enforce_geotype constraint
			EXECUTE 'ALTER TABLE '||quote_ident(new_node_table_name)||' DROP CONSTRAINT "enforce_geotype_geom"';
			
		END IF;
		
        RETURN TRUE;
    END IF;
    
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION ni_create_network_table_nodes(character varying, character varying, character varying, integer, integer) OWNER TO postgres;
