-- Function: ni_data_proc_detect_and_combine_duplicate_edges(character varying, character varying, character varying, integer, character varying, character varying)

-- DROP FUNCTION ni_data_proc_detect_and_combine_duplicate_edges(character varying, character varying, character varying, integer, character varying, character varying);

CREATE OR REPLACE FUNCTION ni_data_proc_detect_and_combine_duplicate_edges(character varying, character varying, character varying, integer, character varying, character varying)
  RETURNS character varying AS
$BODY$
DECLARE

	--edge table name
	edge_table_name ALIAS for $1;
	
	--pkey in edge table 
	edge_join_key_column_name ALIAS for $2;
	
	--name of geometry column for edge table
	edge_geometry_column_name ALIAS for $3;
	
	--srid for geometry column of edge table
	edge_geometry_table_srid ALIAS for $4;
	
	--name of already created join table (from which the duplicates will be replaced by a single record)
	join_table_name ALIAS for $5;
	
	--name of temporary output table created to store results of running query
	output_table_name ALIAS for $6;

	--name of table to temporarily store duplicate connections
	duplicate_table_name text := '';
	
	--name of table to temporarily store connections that appear only once (but need to be recombined with those stored in duplicate_table_name
	duplicate_table_name_count_1 text := '';
	
	--temporary table for storing the unique connections / edges, that will be rejoined with the edge table prior to output
	temp_unique_table_name text := '';
	
	--final resultant table to be created and stored in PostGIS
	unique_table_name text := '';
	
	--to store the data type of the primary key column supplied in edge_join_key_column_name (parameter 2)
	edge_join_key_column_type text := '';
	
	--used to allow looping of records without defining data structure i.e. needing to know column list prior to execution
	loop_record RECORD;
	
	--checks that the unique table has been created correctly i.e. stored in information_schema
	unique_table_exists integer := 0;
	
	--to store the result of unioning all additional combined geometry 
	union_additional_combined_geom text := '';
	
	--to store the original 
	orig_geom text := '';
	
	--to store the geometry to be output within the unique table
	final_geom text := '';
	
	--used to count number of geometries per edge geometry
	num_geom integer := 0;
BEGIN

	--duplicate table name (this will hold records of all duplicate edges in the join table)
	duplicate_table_name := output_table_name||'_dpl';	
	
	--drop the duplicate table
	EXECUTE 'DROP TABLE IF EXISTS '||quote_ident(duplicate_table_name);	
		
	--duplicates table (create a table containing only those records (referenced by edge table column supplied) that are duplicate) - table contains gid and count	
	EXECUTE 'CREATE TEMP TABLE '||quote_ident(duplicate_table_name)||' AS SELECT join_table.'||quote_ident(edge_join_key_column_name)||', COUNT(*) as count FROM '||quote_ident(join_table_name)||' AS join_table GROUP BY join_table.'||quote_ident(edge_join_key_column_name);--||' ORDER BY join_table.'||quote_ident(edge_join_key_column_name);
	
	--retrieve the edge join key data type:
	EXECUTE 'SELECT data_type FROM information_schema.columns WHERE table_name = '||quote_literal(edge_table_name) INTO edge_join_key_column_type;
	
	--create a temporary table name to store the unique records
	temp_unique_table_name := output_table_name||'_tp_u';
	--create a unique table name (this will be output)
	unique_table_name := output_table_name||'_unique';
	
	--drop temp unique table
	EXECUTE 'DROP TABLE IF EXISTS '||quote_ident(temp_unique_table_name);
	
	--create a new table to contain only the unique records	
	EXECUTE 'CREATE TEMP TABLE '||quote_ident(temp_unique_table_name)||' (gid_copy '||edge_join_key_column_type||', final_geom geometry) ';
	
	--define the duplicate table name to store all connections that appear only once in the input join table
	duplicate_table_name_count_1 := duplicate_table_name||'_count_1';
	
	--drop the temporary table containing the records with count = 1
	EXECUTE 'DROP TABLE IF EXISTS '||quote_ident(duplicate_table_name_count_1);
	
	--get all the records where there is only a single count i.e. connection at one end
	EXECUTE 'CREATE TEMP TABLE '||quote_ident(duplicate_table_name_count_1)||' AS SELECT * FROM '||quote_ident(duplicate_table_name)||' WHERE count = 1';
	
	--loop around all the single records i.e. only connected at one end.
	FOR loop_record IN EXECUTE 'SELECT (dup_count_1.'||quote_ident(edge_join_key_column_name)||'::'||edge_join_key_column_type||') AS gid FROM '||quote_ident(duplicate_table_name_count_1)||' AS dup_count_1 ORDER BY gid ASC' LOOP
		union_additional_combined_geom := '';
		num_geom := 0;
		orig_geom := '';
		
		--union the additional_combined_geom
		EXECUTE 'SELECT ST_AsText(ST_Union(ARRAY(SELECT additional_combined_geom FROM '||quote_ident(join_table_name)||' WHERE '||quote_ident(edge_join_key_column_name)||' = '||quote_literal(loop_record.gid)||' ORDER BY '||quote_ident(edge_join_key_column_name)||')))' INTO union_additional_combined_geom;
		
		--count geometries
		EXECUTE 'SELECT ST_NumGeometries('||quote_ident(edge_geometry_column_name)||') FROM '||quote_ident(join_table_name)||' WHERE '||quote_ident(edge_join_key_column_name)||' = '||quote_literal(loop_record.gid) INTO num_geom;
		
		--union all geometries if there are more than one, otherwise just return original geometry
		IF num_geom > 1 THEN
			--union the original geometry
			EXECUTE 'SELECT ST_AsText(ST_Union(ARRAY(SELECT '||quote_ident(edge_geometry_column_name)||' FROM '||quote_ident(join_table_name)||' WHERE '||quote_ident(edge_join_key_column_name)||' = '||quote_literal(loop_record.gid)||' ORDER BY '||quote_ident(edge_join_key_column_name)||')))' INTO orig_geom;
		ELSE		
			EXECUTE 'SELECT ST_AsText('||quote_ident(edge_geometry_column_name)||') FROM '||quote_ident(join_table_name)||' WHERE '||quote_ident(edge_join_key_column_name)||' = '||quote_literal(loop_record.gid) INTO orig_geom;			
		END IF;
		
		--determine if the output has any additional geometry, or is just the original
		IF union_additional_combined_geom IS NOT NULL THEN
		
			EXECUTE 'SELECT ST_AsText(ST_Union(ST_GeomFromText('||quote_literal(union_additional_combined_geom)||', 27700), ST_GeomFromText('||quote_literal(orig_geom)||', 27700)))' INTO final_geom;
		ELSE
			final_geom := orig_geom;
		END IF;
		
		IF final_geom IS NOT NULL THEN
			--add the final geometry to the temporary unique table of edges
			--EXECUTE 'INSERT INTO '||quote_ident(temp_unique_table_name)||'(gid_copy, final_geom) VALUES ('||CAST (loop_record.gid AS edge_join_key_column_type)||', ST_GeomFromText('||quote_literal(final_geom)||', 27700))';
			EXECUTE 'INSERT INTO '||quote_ident(temp_unique_table_name)||'(gid_copy, final_geom) VALUES (('||loop_record.gid||'::'||edge_join_key_column_type||'), ST_GeomFromText('||quote_literal(final_geom)||', 27700))';
		ELSE 
			EXECUTE 'INSERT INTO '||quote_ident(temp_unique_table_name)||'(gid_copy) VALUES(('||loop_record.gid||'::'||edge_join_key_column_type||'))';
		END IF;
		
		
	END LOOP;
	
	--remove those records with count <= 1 from the duplicates table
	EXECUTE 'DELETE FROM '||quote_ident(duplicate_table_name)||' WHERE count <= 1';
	
	--loop around the duplicate table
	FOR loop_record IN EXECUTE 'SELECT duplicate_table.'||quote_ident(edge_join_key_column_name)||' as gid, 
	duplicate_table.count FROM '||quote_ident(duplicate_table_name)||' AS duplicate_table ORDER BY gid' LOOP		
		
		--select from the join table all those records that equal current gid value
		--union the additional_combined_geom
		EXECUTE 'SELECT ST_AsText(ST_Union(ARRAY(SELECT additional_combined_geom FROM '||quote_ident(join_table_name)||' WHERE '||quote_ident(edge_join_key_column_name)||' = '||quote_literal(loop_record.gid)||' ORDER BY '||quote_ident(edge_join_key_column_name)||')))' INTO union_additional_combined_geom;
		
		--count geometries
		EXECUTE 'SELECT ST_NumGeometries('||quote_ident(edge_geometry_column_name)||') FROM '||quote_ident(join_table_name)||' WHERE '||quote_ident(edge_join_key_column_name)||' = '||quote_literal(loop_record.gid) INTO num_geom;
		--union all geometries if there are more than one, otherwise just return original geometry
		
		IF num_geom > 1 THEN
			
			--union the original geometry
			EXECUTE 'SELECT ST_AsText(ST_Union(ARRAY(SELECT '||quote_ident(edge_geometry_column_name)||' FROM '||quote_ident(join_table_name)||' WHERE '||quote_ident(edge_join_key_column_name)||' = '||quote_literal(loop_record.gid)||' ORDER BY '||quote_ident(edge_join_key_column_name)||')))' INTO orig_geom;
		ELSE			
			EXECUTE 'SELECT ST_AsText('||quote_ident(edge_geometry_column_name)||') FROM '||quote_ident(join_table_name)||' WHERE '||quote_ident(edge_join_key_column_name)||' = '||quote_literal(loop_record.gid) INTO orig_geom;			
		END IF;
		
		--determine if the output has any additional geometry, or is just the original
		IF union_additional_combined_geom IS NOT NULL THEN
		
			EXECUTE 'SELECT ST_AsText(ST_Union(ST_GeomFromText('||quote_literal(union_additional_combined_geom)||', 27700), ST_GeomFromText('||quote_literal(orig_geom)||', 27700)))' INTO final_geom;
		ELSE
			final_geom := orig_geom;
		END IF;
		
		IF final_geom IS NOT NULL THEN
			--add the union data to the temporary unique table
			--EXECUTE 'INSERT INTO '||quote_ident(temp_unique_table_name)||'(gid_copy, final_geom) VALUES ('||CAST (loop_record.gid AS edge_join_key_column_type)||', ST_GeomFromText('||quote_literal(final_geom)||', 27700))';
			EXECUTE 'INSERT INTO '||quote_ident(temp_unique_table_name)||'(gid_copy, final_geom) VALUES (('||loop_record.gid||'::'||edge_join_key_column_type||'), ST_GeomFromText('||quote_literal(final_geom)||', 27700))';
		ELSE
			EXECUTE 'INSERT INTO '||quote_ident(temp_unique_table_name)||'(gid_copy) VALUES(('||loop_record.gid||'::'||edge_join_key_column_type||'))';
		END IF;
		
	END LOOP;
	
	--drop the unique output table
	EXECUTE 'DROP TABLE IF EXISTS '||quote_ident(unique_table_name);
	
	--create the new table joined between the edge table and the generated output table based on key matches - this will contain only the original number of edges in the edge table
	EXECUTE 'CREATE TABLE '||quote_ident(unique_table_name)||' AS SELECT * FROM '||quote_ident(edge_table_name)||' LEFT OUTER JOIN '||quote_ident(temp_unique_table_name)||' ON ('||quote_ident(edge_table_name)||'.'||quote_ident(edge_join_key_column_name)||' = '||quote_ident(temp_unique_table_name)||'.gid_copy)';
	
	--remove the gid_copy and old geometry columns as these are now superceeded
	EXECUTE 'ALTER TABLE '||quote_ident(unique_table_name)||' DROP COLUMN gid_copy';
	EXECUTE 'ALTER TABLE '||quote_ident(unique_table_name)||' DROP COLUMN '||quote_ident(edge_geometry_column_name);
	
	--add a comment to the unique output table stating that the table has been created using this function.
	EXECUTE 'COMMENT ON TABLE '||quote_ident(unique_table_name)|| ' IS ''This table was created using the ni_connect_hanging_edges_to_nodes function. This table contains the newly derived connected edges combined with the original edge geometry. Please see the network_interdependency schema for more details of the parameters required for this function, and what it does''';
	
	--rename the newly defined geometry column
	EXECUTE 'ALTER TABLE '||quote_ident(unique_table_name)||' RENAME COLUMN final_geom TO '||quote_ident(edge_geometry_column_name);
	
	--add geometry checks for geom column to the unique table
	EXECUTE 'ALTER TABLE '||quote_ident(unique_table_name)||' ADD CONSTRAINT "enforce_srid_geom" CHECK (st_srid('||quote_ident(edge_geometry_column_name)||') = '||edge_geometry_table_srid||')';
	EXECUTE 'ALTER TABLE '||quote_ident(unique_table_name)||' ADD CONSTRAINT "enforce_geotype_geom" CHECK (geometrytype('||quote_ident(edge_geometry_column_name)||') = ''MULTILINESTRING''::text OR geometrytype('||quote_ident(edge_geometry_column_name)||') = ''LINESTRING''::text OR '||quote_ident(edge_geometry_column_name)||' IS NULL)';
	
	EXECUTE 'SELECT COUNT(*) FROM information_schema.tables WHERE table_name = '||quote_literal(unique_table_name) INTO unique_table_exists;
	
	--return the result 
	IF unique_table_exists > 0 THEN
		RETURN unique_table_name;
	ELSE
		RETURN '';
	END IF;
	
END
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION ni_data_proc_detect_and_combine_duplicate_edges(character varying, character varying, character varying, integer, character varying, character varying) OWNER TO postgres;
