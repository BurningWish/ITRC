-- Function: ni_data_proc_connect_hanging_edges_to_nodes_in_search(character varying, character varying, character varying, character varying, character varying, character varying, character varying, boolean, numeric)

-- DROP FUNCTION ni_data_proc_connect_hanging_edges_to_nodes_in_search(character varying, character varying, character varying, character varying, character varying, character varying, character varying, boolean, numeric);

CREATE OR REPLACE FUNCTION ni_data_proc_connect_hanging_edges_to_nodes_in_search(character varying, character varying, character varying, character varying, character varying, character varying, character varying, boolean, numeric)
  RETURNS SETOF record AS
$BODY$
DECLARE
	
	--name of input edge table
	edge_table_prefix ALIAS for $1;
	
	--edge_geometry column name
	edge_geometry_column_name ALIAS for $2;
	
	--edge table join key
	edge_join_key_column_name ALIAS for $3;
	
	--name of input node table
	node_table_prefix ALIAS for $4;
	
	--node geometry column name
	node_geometry_column_name ALIAS for $5;
	
	--node table join key
	node_join_key_column_name ALIAS for $6;
	
	--name of output table
	output_table_name ALIAS for $7;	
	--boolean to add output table to geometry columns
	add_to_geometry_columns ALIAS for $8;
	--search distance between node and nearest edge
	search_distance ALIAS for $9;
	
	--constants (could be exposed as parameters)
	schema_name varchar := 'public';
	dims integer := 2;			
	edge_geometry_table_srid integer := 27700;	
	node_table_srid integer := 27700;
	edge_geometry_type varchar := 'MULTILINESTRING';
	node_geometry_type varchar := 'POINT';
	
	--table suffixes
	node_table_suffix varchar := '_Nodes';
	edge_table_suffix varchar := '_Edges';
	edge_geometry_table_suffix varchar := '_Edge_Geometry';
	
	--derived from input prefixes and table suffixes (see above)
	edge_table_name varchar := '';
	edge_geometry_table_name varchar := '';
	node_table_name varchar := '';
	
	--used to store outputs of node and edge_geometry tables (without needing to know the column structure)
	node_record RECORD;	
	edge_geometry_record RECORD;
	
	edge_table_exists integer := 0;
	edge_geometry_table_exists integer := 0;
	node_table_exists integer := 0;
	
	--distance to start point of edge from node
	distance_between_node_edge_start_point numeric := 0;
	--distance to end point of edge from node
	distance_between_node_edge_end_point numeric := 0;
	
	--end point of edge
	edge_end_point text := '';
	--start point of edge
	edge_start_point text := '';
		
	--the newly derived edge geometry
	new_edge_geometry text := '';
	--the newly combined edge geometry (new_edge_geometry + original geometry)
	new_combined_edge_geometry text := '';
	
	--derived from output_table_name + join_table_suffix
	join_table_name varchar := '';
	join_table_suffix varchar := '_join';
	
	--final unique table of records
	unique_table_name text := '';
	
	--NEW 
	line_string_geom_counter integer := 0;
	--used when looping around linestrings of a particular multilinestring
	edge_geometry_linestring_record RECORD;
	--to store the newly created geometry between node and the start point of an edge
	new_edge_to_start_point_geometry text := '';
	--to store the newly created geometry between node and the end point of an edge
	new_edge_to_end_point_geometry text := '';
	--to store the combined geometry between node, start_point and the original edge geometry
	new_combined_edge_geometry_to_start_point text := '';
	--to store the combined geometry between node, end_point and the original edge geometry
	new_combined_edge_geometry_to_end_point text := '';
	closest_point_on_edge_ranking_record RECORD;
BEGIN

	--do I need to change this so that the input node and edge table names are presumed to NOT be loaded as _Nodes and _Edges and therefore the edge geometry is actually stored in the edge table itself.
	
	--create node and edge, edge_geometry table names
	--edge_table_name := edge_table_prefix||edge_table_suffix;	
	--edge_geometry_table_name := edge_table_prefix||edge_geometry_table_suffix;
	--node_table_name := node_table_prefix||node_table_suffix;
	edge_table_name := edge_table_prefix;
	edge_geometry_table_name := edge_table_name;
	node_table_name := node_table_prefix;
	
	--check the edge table exists
	EXECUTE 'SELECT COUNT(*) FROM information_schema.tables WHERE table_name = '||quote_literal(edge_table_name) INTO edge_table_exists;
	--check the edge_geometry table exists
	EXECUTE 'SELECT COUNT(*) FROM information_schema.tables WHERE table_name = '||quote_literal(edge_geometry_table_name)  INTO edge_geometry_table_exists;
	--check the node table exists
	EXECUTE 'SELECT COUNT(*) FROM information_schema.tables WHERE table_name = '||quote_literal(node_table_name) INTO node_table_exists;
	
	--raise exception if the tables do not exist or there are multiple tables of same name
	IF edge_table_exists <> 1 OR edge_geometry_table_exists <> 1 OR node_table_exists <> 1 THEN
		--there are either duplicates of the same name or the table does not exist
		RAISE EXCEPTION 'Either the edge table, corresponding edge_geometry table or the node table specified do not exist in the current database.';
	END IF;
	
	--drop the previous temporary output table
	EXECUTE 'DROP TABLE IF EXISTS '||quote_ident(output_table_name);	
	
	--create a temporary table to store the new derived and combined geometry
	EXECUTE 'CREATE TEMP TABLE '||quote_ident(output_table_name)||' (gid_copy integer, connection_point_geom geometry, additional_geom geometry, additional_combined_geom geometry, start_point_distance numeric(10,0), end_point_distance numeric(10,0))';		

	--add geometry checks for the connection point geometry to the temporary table (connection_point_geom)
	EXECUTE 'ALTER TABLE '||quote_ident(output_table_name)||' ADD CONSTRAINT "enforce_srid_connection_point_geom" CHECK (st_srid(connection_point_geom) = '||edge_geometry_table_srid||')';
	EXECUTE 'ALTER TABLE '||quote_ident(output_table_name)||' ADD CONSTRAINT "enforce_geotype_connection_point_geom" CHECK (geometrytype(connection_point_geom) = ''POINT''::text OR connection_point_geom IS NULL)';
	
	--add geometry checks for the newly derived geometry to the temporary table (additional_geom)
	EXECUTE 'ALTER TABLE '||quote_ident(output_table_name)||' ADD CONSTRAINT "enforce_srid_additional_geom" CHECK (st_srid(additional_geom) = '||edge_geometry_table_srid||')';
	EXECUTE 'ALTER TABLE '||quote_ident(output_table_name)||' ADD CONSTRAINT "enforce_geotype_additional_geom" CHECK (geometrytype(additional_geom) = ''MULTILINESTRING''::text OR geometrytype(additional_geom) = ''LINESTRING''::text OR additional_geom IS NULL)';
	
	--add a geometry checks for the newly derived geometry + original geometry to the temporary table (additional_combined_geom)
	EXECUTE 'ALTER TABLE '||quote_ident(output_table_name)||' ADD CONSTRAINT "enforce_srid_additional_combined_geom" CHECK (st_srid(additional_combined_geom) = '||edge_geometry_table_srid||')';
	EXECUTE 'ALTER TABLE '||quote_ident(output_table_name)||' ADD CONSTRAINT "enforce_geotype_additional_combined_geom" CHECK (geometrytype(additional_combined_geom) = ''MULTILINESTRING''::text OR geometrytype(additional_combined_geom) = ''LINESTRING''::text OR additional_combined_geom IS NULL)';
	
	--loop around every node in the node table
	FOR node_record IN EXECUTE 'SELECT ST_AsText('||quote_ident(node_geometry_column_name)||') AS geom, node_table.* FROM '||quote_ident(node_table_name)||' AS node_table ORDER BY '||quote_ident(node_join_key_column_name)||' ASC' LOOP
		--loop around every edge in the edge table			
		
		
		
		FOR edge_geometry_record IN EXECUTE 'SELECT ST_NumGeometries('||quote_ident(edge_geometry_column_name)||') as edge_geom_count, ST_AsText('||quote_ident(edge_geometry_column_name)||') AS geom, edge_geometry_table.'||quote_ident(edge_join_key_column_name)||' as gid, edge_geometry_table.* FROM '||quote_ident(edge_geometry_table_name)||' AS edge_geometry_table WHERE ST_Distance(ST_GeomFromText('||quote_literal(node_record.geom)||', '||node_table_srid||'), '||quote_ident(edge_geometry_column_name)||') <= '||search_distance||' ORDER BY '||quote_ident(edge_join_key_column_name)||' ASC' LOOP		
			
			IF (edge_geometry_record.edge_geom_count IS NULL) OR (edge_geometry_record.edge_geom_count = 1) THEN
				--find the closest edge
				--get the start point of the edge
				EXECUTE 'SELECT ST_AsText(ST_StartPoint(ST_GeomFromText('||quote_literal(edge_geometry_record.geom)||', '||edge_geometry_table_srid||')))' INTO edge_start_point;
				
				--get the end point of the edge
				EXECUTE 'SELECT ST_AsText(ST_EndPoint(ST_GeomFromText('||quote_literal(edge_geometry_record.geom)||', '||edge_geometry_table_srid||')))' INTO edge_end_point;
				
				--calculate distance between node and the start point of the chosen edge
				EXECUTE 'SELECT ST_Distance(ST_GeomFromText('||quote_literal(edge_start_point)||', '||edge_geometry_table_srid||'), ST_GeomFromText('||quote_literal(node_record.geom)||', '||node_table_srid||'))' INTO distance_between_node_edge_start_point;
				
				--calculate distance between node and the end point of the chosen edge
				EXECUTE 'SELECT ST_Distance(ST_GeomFromText('||quote_literal(edge_end_point)||', '||edge_geometry_table_srid||'), ST_GeomFromText('||quote_literal(node_record.geom)||', '||node_table_srid||'))' INTO distance_between_node_edge_end_point;
				
				--determine if the distance to start or end point of edge is within the search distance specified
				IF (distance_between_node_edge_start_point <= search_distance) OR (distance_between_node_edge_end_point <= search_distance) THEN
								
					IF (distance_between_node_edge_start_point < distance_between_node_edge_end_point) AND (distance_between_node_edge_start_point <= search_distance) THEN
					
						--make a new line between the start point and node
						EXECUTE 'SELECT ST_AsText(ST_MakeLine(ST_GeomFromText('||quote_literal(node_record.geom)||', '||node_table_srid||'), ST_GeomFromText('||quote_literal(edge_start_point)||', '||edge_geometry_table_srid||')))' INTO new_edge_geometry;
						--make a new geometry of the old geometry + new line created above
						EXECUTE 'SELECT ST_AsText(ST_Union(ST_GeomFromText('||quote_literal(edge_geometry_record.geom)||', '||edge_geometry_table_srid||'), ST_GeomFromText('||quote_literal(new_edge_geometry)||', '||edge_geometry_table_srid||')))' INTO new_combined_edge_geometry;
					
						--insert the record in to the temporary output table
						EXECUTE 'INSERT INTO '||quote_ident(output_table_name)|| '(gid_copy, start_point_distance, end_point_distance, connection_point_geom, additional_geom, additional_combined_geom) VALUES ('||edge_geometry_record.gid||', '||distance_between_node_edge_start_point||', '||distance_between_node_edge_end_point||', ST_GeomFromText('||quote_literal(edge_start_point)||', '||node_table_srid||'), ST_GeomFromText('||quote_literal(new_edge_geometry)||', '||edge_geometry_table_srid||'),ST_GeomFromText('||quote_literal(new_combined_edge_geometry)||', '||edge_geometry_table_srid||'))';
						
					ELSIF (distance_between_node_edge_start_point > distance_between_node_edge_end_point) AND (distance_between_node_edge_end_point <= search_distance) THEN
						
						--make a new line between the end point and node
						EXECUTE 'SELECT ST_AsText(ST_MakeLine(ST_GeomFromText('||quote_literal(node_record.geom)||', '||node_table_srid||'), ST_GeomFromText('||quote_literal(edge_end_point)||', '||edge_geometry_table_srid||')))' INTO new_edge_geometry;	
						--make a new geometry of the old geometry + new line created above
						EXECUTE 'SELECT ST_AsText(ST_Union(ST_GeomFromText('||quote_literal(edge_geometry_record.geom)||', '||edge_geometry_table_srid||'), ST_GeomFromText('||quote_literal(new_edge_geometry)||', '||edge_geometry_table_srid||')))' INTO new_combined_edge_geometry;
					
						--insert the record in to the temporary output table
						EXECUTE 'INSERT INTO '||quote_ident(output_table_name)|| '(gid_copy, start_point_distance, end_point_distance, connection_point_geom, additional_geom, additional_combined_geom) VALUES ('||edge_geometry_record.gid||', '||distance_between_node_edge_start_point||', '||distance_between_node_edge_end_point||', ST_GeomFromText('||quote_literal(edge_end_point)||', '||node_table_srid||'), ST_GeomFromText('||quote_literal(new_edge_geometry)||', '||edge_geometry_table_srid||'),ST_GeomFromText('||quote_literal(new_combined_edge_geometry)||', '||edge_geometry_table_srid||'))';
					END IF;							
				END IF;
			ELSIF (edge_geometry_record.edge_geom_count IS NOT NULL) OR (edge_geometry_record.edge_geom_count > 1) THEN
				--remove the temporary table used to store the distances between node in question and start/end and nearest points on edge
				EXECUTE 'DROP TABLE IF EXISTS closest_point_on_edge_ranking_like ';
				--create a temp table to store the ranked values on linestring
				EXECUTE 'CREATE TEMP TABLE closest_point_on_edge_ranking_like (gid_copy integer, connection_point_geom geometry, node_to_point_distance numeric, additional_geom geometry, additional_combined_geom geometry)';
				
				--1-based index for ST_GeometryN
				line_string_geom_counter := 1;
				
				--loop around every geometry because we cannot use the line_locate_point function on multilinestring								
				FOR i IN 1..edge_geometry_record.edge_geom_count LOOP
				
					--get the current geometry whilst looping all linestrings of multilinestring
					EXECUTE 'SELECT ST_AsText(ST_GeometryN(ST_GeomFromText('||quote_literal(edge_geometry_record.geom)||', '||edge_geometry_table_srid||'), '||line_string_geom_counter||')) as edge_linestring_geom' INTO edge_geometry_linestring_record;
					
					--find the start point of the current line string geometry
					EXECUTE 'SELECT ST_AsText(ST_StartPoint(ST_GeomFromText('||quote_literal(edge_geometry_linestring_record.edge_linestring_geom)||', '||edge_geometry_table_srid||')))' INTO edge_start_point;
					
					--find the end point of the current line string geometry
					EXECUTE 'SELECT ST_AsText(ST_EndPoint(ST_GeomFromText('||quote_literal(edge_geometry_linestring_record.edge_linestring_geom)||', '||edge_geometry_table_srid||')))' INTO edge_end_point;
					
					--calculate distance between node and the start point of the chosen edge
					EXECUTE 'SELECT ST_Distance(ST_GeomFromText('||quote_literal(edge_start_point)||', '||edge_geometry_table_srid||'), ST_GeomFromText('||quote_literal(node_record.geom)||', '||node_table_srid||'))' INTO distance_between_node_edge_start_point;
					
					--calculate distance between node and the end point of the chosen edge
					EXECUTE 'SELECT ST_Distance(ST_GeomFromText('||quote_literal(edge_end_point)||', '||edge_geometry_table_srid||'), ST_GeomFromText('||quote_literal(node_record.geom)||', '||node_table_srid||'))' INTO distance_between_node_edge_end_point;
					
					IF (distance_between_node_edge_start_point <= search_distance) AND (distance_between_node_edge_start_point < distance_between_node_edge_end_point) THEN
						--create a new line (between the edge start point) and the node in question
						EXECUTE 'SELECT ST_AsText(ST_MakeLine(ST_GeomFromText('||quote_literal(node_record.geom)||', '||node_table_srid||'), ST_GeomFromText('||quote_literal(edge_start_point)||', '||edge_geometry_table_srid||')))' INTO new_edge_to_start_point_geometry;
						
						--create a line that combines the original edge geometry with the newly derived geometry (to the start point of the edge)
						EXECUTE 'SELECT ST_AsText(ST_Union(ST_GeomFromText('||quote_literal(edge_geometry_record.geom)||', '||edge_geometry_table_srid||'), ST_GeomFromText('||quote_literal(new_edge_to_start_point_geometry)||', '||edge_geometry_table_srid||')))' INTO new_combined_edge_geometry_to_start_point;
						
						--add the newly created values (for the start point)
						EXECUTE 'INSERT INTO closest_point_on_edge_ranking_like (gid_copy, node_to_point_distance, connection_point_geom, additional_geom, additional_combined_geom) VALUES ('||edge_geometry_record.gid||', '||distance_between_node_edge_start_point||', ST_GeomFromText('||quote_literal(edge_start_point)||', '||node_table_srid||'), ST_GeomFromText('||quote_literal(new_edge_to_start_point_geometry)||', 27700), ST_GeomFromText('||quote_literal(new_combined_edge_geometry_to_start_point)||', 27700))';	
						
					ELSIF (distance_between_node_edge_end_point <= search_distance) AND (distance_between_node_edge_end_point < distance_between_node_edge_start_point) THEN
						--create a new line (between the edge end point) and the node in question
						EXECUTE 'SELECT ST_AsText(ST_MakeLine(ST_GeomFromText('||quote_literal(node_record.geom)||', '||node_table_srid||'), ST_GeomFromText('||quote_literal(edge_end_point)||', '||edge_geometry_table_srid||')))' INTO new_edge_to_end_point_geometry;
						
						--create a line that combines the original edge geometry with the newly derived geometry (to the end point of the edge)
						EXECUTE 'SELECT ST_AsText(ST_Union(ST_GeomFromText('||quote_literal(edge_geometry_record.geom)||', '||edge_geometry_table_srid||'), ST_GeomFromText('||quote_literal(new_edge_to_end_point_geometry)||', '||edge_geometry_table_srid||')))' INTO new_combined_edge_geometry_to_end_point;
						
						--add the newly created values (for the end point)
						EXECUTE 'INSERT INTO closest_point_on_edge_ranking_like (gid_copy, node_to_point_distance, connection_point_geom, additional_geom, additional_combined_geom) VALUES ('||edge_geometry_record.gid||', '||distance_between_node_edge_end_point||', ST_GeomFromText('||quote_literal(edge_end_point)||', '||node_table_srid||'), ST_GeomFromText('||quote_literal(new_edge_to_end_point_geometry)||', 27700), ST_GeomFromText('||quote_literal(new_combined_edge_geometry_to_end_point)||', 27700))';	
						
					END IF;
					
					--increment the linestring counter
					line_string_geom_counter := line_string_geom_counter + 1;
				END LOOP;
				
				--retrieve only the new point and new line geometries based on the smallest distance (hence LIMIT 1)
				FOR closest_point_on_edge_ranking_record IN EXECUTE 'SELECT gid_copy as gid_copy, ST_AsText(additional_geom) as additional_geom, ST_AsText(connection_point_geom) as connection_point_geom, ST_AsText(additional_combined_geom) as additional_combined_geom, node_to_point_distance as node_to_point_distance FROM closest_point_on_edge_ranking_like ORDER BY node_to_point_distance ASC LIMIT 1' LOOP
					
					--IF closest_point_on_edge_ranking_record.node_to_point_distance <= search_distance THEN
					EXECUTE 'INSERT INTO '||quote_ident(output_table_name)|| ' (gid_copy, connection_point_geom, additional_geom, additional_combined_geom) VALUES ('||edge_geometry_record.gid||', ST_GeomFromText('||quote_literal(closest_point_on_edge_ranking_record.connection_point_geom)||','||node_table_srid||'), ST_GeomFromText('||quote_literal(closest_point_on_edge_ranking_record.additional_geom)||', 27700), ST_GeomFromText('||quote_literal(closest_point_on_edge_ranking_record.additional_combined_geom)||', 27700))';
					--END IF;
				END LOOP;
			END IF;
			
			
		END LOOP;
	END LOOP;

	--create the new join table name as a combination of the join suffix and supplied output table name
	join_table_name := output_table_name||join_table_suffix;
	
	--drop the join table
	EXECUTE 'DROP TABLE IF EXISTS '||quote_ident(join_table_name);
	
	--create the new join table between the edge table and the generated output table based on key matches
	EXECUTE 'CREATE TABLE '||quote_ident(join_table_name)||' AS SELECT * FROM '||quote_ident(edge_table_name)||' LEFT OUTER JOIN '||quote_ident(output_table_name)||' ON ('||quote_ident(edge_table_name)||'.'||quote_ident(edge_join_key_column_name)||' = '||quote_ident(output_table_name)||'.gid_copy)';
	
	--add a comment stating what function was used to create the output table
	EXECUTE 'COMMENT ON TABLE '||quote_ident(join_table_name)|| ' IS ''This table was created using the ni_connect_hanging_edges_to_nodes function. Please see the network_interdependency schema for more details of the parameters required for this function, and what it does''';
	
	--add geometry checks for the connection point geometry to the join table (connection_point_geom)
	EXECUTE 'ALTER TABLE '||quote_ident(join_table_name)||' ADD CONSTRAINT "enforce_srid_connection_point_geom" CHECK (st_srid(connection_point_geom) = '||node_table_srid||')';
	EXECUTE 'ALTER TABLE '||quote_ident(join_table_name)||' ADD CONSTRAINT "enforce_geotype_connection_point_geom" CHECK (geometrytype(connection_point_geom) = ''POINT''::text OR connection_point_geom IS NULL)';
	
	--add geometry checks for geom column to the joined table
	EXECUTE 'ALTER TABLE '||quote_ident(join_table_name)||' ADD CONSTRAINT "enforce_srid_orig_geom" CHECK (st_srid('||quote_ident(edge_geometry_column_name)||') = '||edge_geometry_table_srid||')';
	EXECUTE 'ALTER TABLE '||quote_ident(join_table_name)||' ADD CONSTRAINT "enforce_geotype_orig_geom" CHECK (geometrytype('||quote_ident(edge_geometry_column_name)||') = ''MULTILINESTRING''::text OR geometrytype('||quote_ident(edge_geometry_column_name)||') = ''LINESTRING''::text OR '||quote_ident(edge_geometry_column_name)||' IS NULL)';
	
	--add geometry checks for the newly derived geometry to the joined table
	EXECUTE 'ALTER TABLE '||quote_ident(join_table_name)||' ADD CONSTRAINT "enforce_srid_additional_geom" CHECK (st_srid(additional_geom) = '||edge_geometry_table_srid||')';
	EXECUTE 'ALTER TABLE '||quote_ident(join_table_name)||' ADD CONSTRAINT "enforce_geotype_additional_geom" CHECK (geometrytype(additional_geom) = ''MULTILINESTRING''::text OR geometrytype(additional_geom) = ''LINESTRING''::text OR additional_geom IS NULL)';
	
	--add a geometry checks for the newly derived geometry + original geometry to the joined table
	EXECUTE 'ALTER TABLE '||quote_ident(join_table_name)||' ADD CONSTRAINT "enforce_srid_additional_combined_geom" CHECK (st_srid(additional_combined_geom) = '||edge_geometry_table_srid||')';
	EXECUTE 'ALTER TABLE '||quote_ident(join_table_name)||' ADD CONSTRAINT "enforce_geotype_additional_combined_geom" CHECK (geometrytype(additional_combined_geom) = ''MULTILINESTRING''::text OR geometrytype(additional_combined_geom) = ''LINESTRING''::text OR additional_combined_geom IS NULL)';	
	
	--remove the gid_copy column from the join table
	EXECUTE 'ALTER TABLE '||quote_ident(join_table_name)||' DROP COLUMN gid_copy';
	
	--remove the temporary output table
	EXECUTE 'DROP TABLE IF EXISTS '||quote_ident(output_table_name);
	
	EXECUTE 'SELECT * FROM ni_data_proc_detect_and_combine_duplicate_edges('||quote_literal(edge_table_name)||','||quote_literal(edge_join_key_column_name)||', '||quote_literal(edge_geometry_column_name)||', '||quote_literal(edge_geometry_table_srid)||', '||quote_literal(join_table_name)||', '||quote_literal(output_table_name)||')' INTO unique_table_name;
	
	--add the new output join table and unique edges records table geometry columns to the geomtry columns table (this has been joined back to the original data)
	IF add_to_geometry_columns IS TRUE THEN
		
		IF unique_table_name != '' THEN	
			--unique table
			RAISE NOTICE 'Adding to geometry columns (unique table) - geom';
			EXECUTE 'SELECT * FROM ni_add_to_geometry_columns('||quote_literal(unique_table_name)||', '''', '||quote_literal(schema_name)||','||quote_literal(edge_geometry_column_name)||','||dims||','||edge_geometry_table_srid||', '||quote_literal(edge_geometry_type)||')';
		END IF;
		
		--join table
		RAISE NOTICE 'Adding to geometry columns - geom';
		EXECUTE 'SELECT * FROM ni_add_to_geometry_columns('||quote_literal(join_table_name)||', '''', '||quote_literal(schema_name)||','||quote_literal(edge_geometry_column_name)||','||dims||','||edge_geometry_table_srid||', '||quote_literal(edge_geometry_type)||')';
		
		RAISE NOTICE 'Adding to geometry columns - connection_point_geom';
		EXECUTE 'SELECT * FROM ni_add_to_geometry_columns('||quote_literal(join_table_name)||', '''', '||quote_literal(schema_name)||',''connection_point_geom'','||dims||','||node_table_srid||', '||quote_literal(node_geometry_type)||')';
		
		RAISE NOTICE 'Adding to geometry columns - additional_geom';
		EXECUTE 'SELECT * FROM ni_add_to_geometry_columns('||quote_literal(join_table_name)||', '''', '||quote_literal(schema_name)||',''additional_geom'','||dims||','||edge_geometry_table_srid||', '||quote_literal(edge_geometry_type)||')';
		
		RAISE NOTICE 'Adding to geometry columns - additional_combined_geom';
		EXECUTE 'SELECT * FROM ni_add_to_geometry_columns('||quote_literal(join_table_name)||', '''', '||quote_literal(schema_name)||',''additional_combined_geom'','||dims||','||edge_geometry_table_srid||', '||quote_literal(edge_geometry_type)||')';
		
	END IF;
	RAISE NOTICE 'Returning records';
	RETURN QUERY EXECUTE 'SELECT * FROM '||quote_ident(join_table_name);
	
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION ni_data_proc_connect_hanging_edges_to_nodes_in_search(character varying, character varying, character varying, character varying, character varying, character varying, character varying, boolean, numeric) OWNER TO postgres;
