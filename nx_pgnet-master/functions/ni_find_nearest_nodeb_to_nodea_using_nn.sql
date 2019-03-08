-- Function: ni_find_nearest_nodeb_to_nodea_using_nn(character varying, character varying, character varying, character varying, character varying, character varying, character varying, boolean)

-- DROP FUNCTION ni_find_nearest_nodeb_to_nodea_using_nn(character varying, character varying, character varying, character varying, character varying, character varying, character varying, boolean);

CREATE OR REPLACE FUNCTION ni_find_nearest_nodeb_to_nodea_using_nn(character varying, character varying, character varying, character varying, character varying, character varying, character varying, boolean)
  RETURNS SETOF record AS
$BODY$
DECLARE

	--nodeset A table_name
	nodeset_A_table_name ALIAS for $1;
	
	--nodeset A prkey
	nodeset_A_prkey ALIAS for $2;
	
	--geometry column name of nodeset A table (could be exposed as a parameter)
	nodeset_A_geometry_column_name ALIAS for $3;
	
	--nodeset B table_name
	nodeset_B_table_name ALIAS for $4;
	
	--nodeset B prkey
	nodeset_B_prkey ALIAS for $5;
	
	--geometry column name of nodeset B table (could be exposed as a parameter)
	nodeset_B_geometry_column_name ALIAS for $6;
	
	--output table name 
	output_table_name ALIAS for $7;
	
	--indicates whether or not to add the resulting output table to the geometry columns table
	add_to_geometry_columns ALIAS for $8;
	
	--dimensions 
	dims integer := 2;
	
	--schema_name 
	schema_name varchar := 'public';
	
	--could be exposed as a parameter?
	nodeset_A_srid integer := 27700;
	
	--could be exposed as a parameter?
	nodeset_B_srid integer := 27700;
	
	--srid of resultant line between nodeA and closest node of nodeset B
	node_AB_line_srid integer := 27700;
	
	--search distance result of iterations
	search_distance numeric := 0.0;
	
	--nodeset A prkey datatype
	nodeset_A_prkey_datatype varchar := '';
	
	nodeset_A_prkey_datatype_length integer := 0;
	
	--nodeset B prkey datatype
	nodeset_B_prkey_datatype varchar := '';
	
	nodeset_B_prkey_datatype_length integer := 0;
	
	--temporary table name
	temp_table_name varchar := '';
		
	temp_table_sql text := '';	
		
BEGIN
	
	--create a temporary table to store the final results, then need to join the original table back to this table
	temp_table_name := output_table_name||'_temp';
	
	--determine the datatype of nodeset A prkey
	EXECUTE 'SELECT data_type FROM information_schema.columns WHERE table_name = '||quote_literal(nodeset_A_table_name)||' AND column_name = '||quote_literal(nodeset_A_prkey) INTO nodeset_A_prkey_datatype;
	
	--determine the datatype of nodeset B prkey
	EXECUTE 'SELECT data_type FROM information_schema.columns WHERE table_name = '||quote_literal(nodeset_B_table_name)||' AND column_name = '||quote_literal(nodeset_B_prkey) INTO nodeset_B_prkey_datatype;
	
	--drop the previous temporary table
	EXECUTE 'DROP TABLE IF EXISTS '||quote_ident(temp_table_name);
	
	--create a new temporary table to store the outputs generated as a result of the function. We will then join to this table the original data
	--node A geometry (POINT)
	--node A id (unknown data type)
	--node B geometry (POINT) - closest point to node A
	--node B id (unknown data type)
	--node_AB_line - derived geometry between node A and node B (closest)
	--distance of node_AB_line
	--switch to non-temp table, then delete after join?
	--RAISE NOTICE 'create temp table start';
	
	IF nodeset_A_prkey_datatype = 'character' OR nodeset_A_prkey_datatype = 'character varying' THEN
		EXECUTE 'SELECT character_maximum_length FROM information_schema.columns WHERE table_name = '||quote_literal(nodeset_A_table_name)||' AND column_name = '||quote_literal(nodeset_A_prkey) INTO nodeset_A_prkey_datatype_length;
	END IF;
	
	IF nodeset_B_prkey_datatype = 'character' OR nodeset_B_prkey_datatype = 'character varying' THEN
		EXECUTE 'SELECT character_maximum_length FROM information_schema.columns WHERE table_name = '||quote_literal(nodeset_B_table_name)||' AND column_name = '||quote_literal(nodeset_B_prkey) INTO nodeset_B_prkey_datatype_length;
	END IF;
	
	IF nodeset_A_prkey_datatype = 'character' OR nodeset_A_prkey_datatype = 'character varying' THEN	
		temp_table_sql := 'CREATE TEMPORARY TABLE '||quote_ident(temp_table_name)||' ("node_A_id" '||nodeset_A_prkey_datatype||' ('||nodeset_A_prkey_datatype_length||'), "node_A_geom" geometry, ';
	ELSE
		temp_table_sql := 'CREATE TEMPORARY TABLE '||quote_ident(temp_table_name)||' ("node_A_id" '||nodeset_A_prkey_datatype||', "node_A_geom" geometry, ';
	END IF;
	
	IF nodeset_B_prkey_datatype = 'character' OR nodeset_B_prkey_datatype = 'character varying' THEN	
		temp_table_sql := temp_table_sql || '"node_B_id" '||nodeset_B_prkey_datatype||' ('||nodeset_B_prkey_datatype_length||'), "node_B_geom" geometry, "node_AB_line" geometry, "node_AB_distance" numeric)';
	ELSE
		temp_table_sql := temp_table_sql || '"node_B_id" '||nodeset_B_prkey_datatype||', "node_B_geom" geometry, "node_AB_line" geometry, "node_AB_distance" numeric)';
	END IF;
	
	EXECUTE temp_table_sql;
	
	--RAISE NOTICE 'create temp table end';
	--EXECUTE 'INSERT INTO '||quote_ident(temp_table_name)||' ("node_A_id", "node_A_geom", "node_B_id", "node_B_geom", "node_AB_line", "node_AB_distance") SELECT DISTINCT ON("node_A_set".'||quote_ident(nodeset_A_prkey)||') "node_A_set".'||quote_ident(nodeset_A_prkey)||', "node_A_set".'||quote_ident(nodeset_A_geometry_column_name)||', "node_B_set".'||quote_ident(nodeset_B_prkey)||', "node_B_set".'||quote_ident(nodeset_B_geometry_column_name)||', ST_MakeLine("node_A_set".'||quote_ident(nodeset_A_geometry_column_name)||', "node_B_set".'||quote_ident(nodeset_B_geometry_column_name)||'), ST_Distance("node_A_set".'||quote_ident(nodeset_A_geometry_column_name)||', "node_B_set".'||quote_ident(nodeset_B_geometry_column_name)||') FROM '||quote_ident(nodeset_A_table_name)||' AS "node_A_set", '||quote_ident(nodeset_B_table_name)||' AS "node_B_set" ORDER BY "node_A_set".'||quote_ident(nodeset_A_prkey)||', "node_A_set".'||quote_ident(nodeset_A_geometry_column_name)||' <-> "node_B_set".'||quote_ident(nodeset_B_geometry_column_name);
	
	--do we need to use ST_DWithin at this point or something similar to limit the number of necessary searches?
	
	--RAISE NOTICE 'insert in to temp table';
	--RAISE NOTICE 'nodeset_A_prkey: %', nodeset_A_prkey;
	--find the closest node from set B to each node in set A
	EXECUTE 'INSERT INTO '||quote_ident(temp_table_name)||' ("node_A_id", "node_A_geom", "node_B_id", "node_B_geom", "node_AB_line", "node_AB_distance") SELECT DISTINCT ON("node_A_set".'||quote_ident(nodeset_A_prkey)||') "node_A_set".'||quote_ident(nodeset_A_prkey)||', "node_A_set".'||quote_ident(nodeset_A_geometry_column_name)||', "node_B_set".'||quote_ident(nodeset_B_prkey)||', "node_B_set".'||quote_ident(nodeset_B_geometry_column_name)||', ST_MakeLine("node_A_set".'||quote_ident(nodeset_A_geometry_column_name)||', "node_B_set".'||quote_ident(nodeset_B_geometry_column_name)||'), ST_Distance("node_A_set".'||quote_ident(nodeset_A_geometry_column_name)||', "node_B_set".'||quote_ident(nodeset_B_geometry_column_name)||') FROM '||quote_ident(nodeset_A_table_name)||' AS "node_A_set", '||quote_ident(nodeset_B_table_name)||' AS "node_B_set" ORDER BY "node_A_set".'||quote_ident(nodeset_A_prkey)||', "node_A_set".'||quote_ident(nodeset_A_geometry_column_name)||' <-> "node_B_set".'||quote_ident(nodeset_B_geometry_column_name);
	--RAISE NOTICE 'finish insert in to temp table';
	--how can we speed this up?
	--INSERT INTO closest_elecsubstation_to_os_airports_temp ("node_A_id", "node_A_geom", "node_B_id", "node_B_geom", "node_AB_line", "node_AB_distance") SELECT DISTINCT ON("node_A_set".gid) "node_A_set".gid, "node_A_set".geom, "node_B_set".gid, "node_B_set".geom, ST_MakeLine("node_A_set".geom, "node_B_set".geom), ST_Distance("node_A_set".geom, "node_B_set".geom) FROM "OS_Airports" AS "node_A_set", "OS_ElectricitySubStations" AS "node_B_set" ORDER BY "node_A_set".geom <-> "node_B_set".geom, "node_A_set".gid
	--RAISE NOTICE 'pre-join';
	--drop the previous table
	EXECUTE 'DROP TABLE IF EXISTS '||quote_ident(output_table_name);
	
	--create the output table joined back to the original input node set A table
	EXECUTE 'CREATE TABLE '||quote_ident(output_table_name)||' AS SELECT * FROM '||quote_ident(temp_table_name)||' LEFT OUTER JOIN '||quote_ident(nodeset_A_table_name)||' ON ('||quote_ident(temp_table_name)||'."node_A_id" = '||quote_ident(nodeset_A_table_name)||'.'||quote_ident(nodeset_A_prkey)||')';
	
	--delete old temp table
	EXECUTE 'DROP TABLE IF EXISTS '||quote_ident(temp_table_name);
	
	--add the output to the geometry columns table
	IF add_to_geometry_columns IS TRUE THEN

		RAISE NOTICE 'Adding to geometry columns (node_A_geom)';
		EXECUTE 'SELECT * FROM ni_add_to_geometry_columns('||quote_literal(output_table_name)||', '''', '||quote_literal(schema_name)||','||quote_literal(nodeset_A_geometry_column_name)||','||dims||','||nodeset_A_srid||', ''POINT'')';
		
		RAISE NOTICE 'Adding to geometry columns (node_B_geom)';
		EXECUTE 'SELECT * FROM ni_add_to_geometry_columns('||quote_literal(output_table_name)||', '''', '||quote_literal(schema_name)||','||quote_literal(nodeset_B_geometry_column_name)||','||dims||','||nodeset_B_srid||', ''POINT'')';
		
		RAISE NOTICE 'Adding to geometry columns (node_AB_line)';
		EXECUTE 'SELECT * FROM ni_add_to_geometry_columns('||quote_literal(output_table_name)||', '''', '||quote_literal(schema_name)||',''node_AB_line'','||dims||','||node_AB_line_srid||', ''POINT'')';
		
	END IF;
	
	RAISE NOTICE 'Returning records';
	RETURN QUERY EXECUTE 'SELECT * FROM '||quote_ident(output_table_name);
	
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION ni_find_nearest_nodeb_to_nodea_using_nn(character varying, character varying, character varying, character varying, character varying, character varying, character varying, boolean) OWNER TO postgres;
