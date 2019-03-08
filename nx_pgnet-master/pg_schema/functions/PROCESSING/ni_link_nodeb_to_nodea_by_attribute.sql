
CREATE OR REPLACE FUNCTION ni_link_nodeb_to_nodea_by_attribute(character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, boolean)
  RETURNS SETOF record AS
$BODY$
DECLARE

	--nodeset A table_name
	nodeset_A_table_name ALIAS for $1;
	
	--nodeset A prkey
	nodeset_A_prkey ALIAS for $2;
	
	--geometry column name of nodeset A table (could be exposed as a parameter)
	nodeset_A_geometry_column_name ALIAS for $3;
	
	--attribute of nodeset A table to relate to attribute of nodeset B table
	nodeset_A_attribute_name ALIAS for $4;
	
	--prefix for output columns from nodeset A
	nodeset_A_prefix ALIAS for $5;
	
	--nodeset B table_name
	nodeset_B_table_name ALIAS for $6;
	
	--nodeset B prkey
	nodeset_B_prkey ALIAS for $7;
	
	--geometry column name of nodeset B table (could be exposed as a parameter)
	nodeset_B_geometry_column_name ALIAS for $8;
	
	--attribute of nodeset B table to relate to attribute of nodeset A table
	nodeset_B_attribute_name ALIAS for $9;
	
	--prefix for output columns from nodeset A
	nodeset_B_prefix ALIAS for $10;
	
	--output table name 
	output_table_name ALIAS for $11;
	
	--indicates whether or not to add the resulting output table to the geometry columns table
	add_to_geometry_columns ALIAS for $12;
	
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
	
	--nodeset B prkey datatype
	nodeset_B_prkey_datatype varchar := '';
	
	--temporary table name
	temp_table_name varchar := '';

	information_schema_table_record RECORD;
	
	--to store column names of original node A table
	join_sql_table_A text := '';
	--to store column names of original node B table
	join_sql_table_B text := '';
	
	--column counter for creating sql string
	current_column_counter integer := 0;
	
	--column count of node A table
	column_count_nodeset_A integer := 0;
	--column count of node B table
	column_count_nodeset_B integer := 0;
	
	--string to store new column name for columns in node A table
	new_column_name_nodeset_A text := '';
	--string to store new column name for columns in node B table
	new_column_name_nodeset_B text := '';
	
	--to store table name of join between attribute tables of node A and node B tables
	temp_table_name_join text := '';
	
	--to store the column name of the new key for node A table i.e. nodeset_A_prefix||nodeset_A_attribute_name
	new_join_key_name text := '';
	
BEGIN
	
	--create a temporary table to store the final results, then need to join the original table back to this table
	temp_table_name := output_table_name||'_temp';
	
	--determine the datatype of nodeset A prkey
	EXECUTE 'SELECT data_type FROM information_schema.columns WHERE table_name = '||quote_literal(nodeset_A_table_name)||' AND column_name = '||quote_literal(nodeset_A_prkey) INTO nodeset_A_prkey_datatype;
	
	--determine the datatype of nodeset B prkey
	EXECUTE 'SELECT data_type FROM information_schema.columns WHERE table_name = '||quote_literal(nodeset_B_table_name)||' AND column_name = '||quote_literal(nodeset_B_prkey) INTO nodeset_B_prkey_datatype;
	
	--drop the previous temporary table
	EXECUTE 'DROP TABLE IF EXISTS '||quote_ident(temp_table_name);
		
	--perform a join 
	--creates a temporary table from the left outer join performed between nodesetA and nodesetB
	EXECUTE 'CREATE TEMPORARY TABLE '||quote_ident(temp_table_name)||' AS SELECT '||quote_ident(nodeset_A_table_name)||'.'||quote_ident(nodeset_A_prkey)||' AS "node_A_id", '||quote_ident(nodeset_A_table_name)||'.'||quote_ident(nodeset_A_geometry_column_name)||' AS "node_A_geom", '||quote_ident(nodeset_A_table_name)||'.'||quote_ident(nodeset_A_attribute_name)||' AS "node_A_attr", '||quote_ident(nodeset_B_table_name)||'.'||quote_ident(nodeset_B_prkey)||' AS "node_B_id", '||quote_ident(nodeset_B_table_name)||'.'||quote_ident(nodeset_B_geometry_column_name)||' AS "node_B_geom", '||quote_ident(nodeset_B_table_name)||'.'||quote_ident(nodeset_B_attribute_name)||' AS "node_B_attr" FROM '||quote_ident(nodeset_A_table_name)||' LEFT OUTER JOIN '||quote_ident(nodeset_B_table_name)||' ON ('||quote_ident(nodeset_A_table_name)||'.'||quote_ident(nodeset_A_attribute_name)||' = '||quote_ident(nodeset_B_table_name)||'.'||quote_ident(nodeset_B_attribute_name)||');';
	
	EXECUTE 'ALTER TABLE '||quote_ident(temp_table_name)||' ADD COLUMN "node_AB_line" geometry;';
	EXECUTE 'ALTER TABLE '||quote_ident(temp_table_name)||' ADD COLUMN "node_AB_distance" numeric;';
	
	EXECUTE 'UPDATE '||quote_ident(temp_table_name)||' SET "node_AB_line" = ST_MakeLine("node_A_geom", "node_B_geom");';
	RAISE NOTICE 'updated node_AB_line';
	
	--NEED TO UPDATE THE VALUES FOR "node_AB_distance" - this uses the distance between the two input geometries
	--EXECUTE 'UPDATE '||quote_ident(temp_table_name)||' SET "node_AB_distance" = ST_Distance('||quote_ident(nodeset_A_geometry_column_name)||','||quote_ident(nodeset_B_geometry_column_name)||')';
	
	--NEED TO UPDATE THE VALUES FOR "node_AB_distance" - this uses the length of the result geometry?
	EXECUTE 'UPDATE '||quote_ident(temp_table_name)||' SET "node_AB_distance" = ST_Length("node_AB_line");';
	RAISE NOTICE 'updated distance column';
	
	--THE RESULTANT TEMPORARY OUTPUT TABLE LOOKS LIKE THIS:
		  --"node_A_id" double precision, (prkey)
		  --"node_A_geom" geometry,
		  --"node_A_attr" double precision, (join attribute)
		  --"node_B_id" double precision, (prkey)
		  --"node_B_geom" geometry,
		  --"node_B_attr" double precision, (join attribute)
		  --"node_AB_line" geometry,
		  --"node_AB_distance" numeric
	
	--query information_schema.columns to grab in order all columns for table = nodeset_A_table_name
	--count of number of columns of table A: 
	--EXECUTE 'SELECT COUNT(column_name) FROM information_schema.columns WHERE table_name = '||quote_literal(nodeset_A_table_name) INTO column_count_nodeset_A;	
	--join_sql_table_a will hold all values for columns from nodeset_A
	--current_column_counter = 0
	--e.g. 
	--FOR information_schema_table_record IN EXECUTE 'SELECT column_name FROM information_schema.columns WHERE table_name='||quote_literal(nodeset_A_table_name) LOOP
	--	current_column_counter := current_column_counter + 1;
	--	new_column_name_nodeset_A := '';
	--	new_column_name_nodeset_A := nodeset_A_prefix||information_schema_table_record.column_name;
	--	IF column_count_nodeset_A > current_column_counter THEN
	--		join_sql_table_A = join_sql_table_A||quote_ident(nodeset_A_table_name)||'.'||information_schema_table_record.column_name||' AS '||quote_ident(new_column_name_nodeset_A)||', ';
	--	ELSE
	--		join_sql_table_A = join_sql_table_A||quote_ident(nodeset_A_table_name)||'.'||information_schema_table_record.column_name||' AS '||quote_ident(new_column_name_nodeset_A);
	--	END IF;
	--END LOOP;
	
	EXECUTE 'SELECT * FROM ni_create_new_column_names_for_join('||quote_literal(nodeset_A_prefix)||','||quote_literal(nodeset_A_table_name)||')' INTO join_sql_table_A;
	RAISE NOTICE 'join_sql_table_A: %', join_sql_table_A;
	--query information_schema.columns to grab in order all columns for table = nodeset_B_table_name
	--count of number of columns of table B: 
	--EXECUTE 'SELECT COUNT(column_name) FROM information_schema.columns WHERE table_name = '||quote_literal(nodeset_B_table_name) INTO column_count_nodeset_B;	
	--join_sql_table_b will hold all values for columns from nodeset_B 
	--e.g. 
	--current_column_counter := 0;
	--FOR information_schema_table_record IN EXECUTE 'SELECT column_name FROM information_schema.columns WHERE table_name='||quote_literal(nodeset_B_table_name) LOOP
	--	current_column_counter := current_column_counter + 1;
	--	new_column_name_nodeset_B := '';
	--	new_column_name_nodeset_B := nodeset_B_prefix||information_schema_table_record.column_name;
	--	IF column_count_nodeset_B > current_column_counter THEN
	--		join_sql_table_B = join_sql_table_B||quote_ident(nodeset_B_table_name)||'.'||information_schema_table_record.column_name||' AS '||quote_ident(new_column_name_nodeset_B)||', ';
	--	ELSE
	--		join_sql_table_B = join_sql_table_B||quote_ident(nodeset_B_table_name)||'.'||information_schema_table_record.column_name||' AS '||quote_ident(new_column_name_nodeset_B);
	--	END IF;
	--END LOOP;
	
	EXECUTE 'SELECT * FROM ni_create_new_column_names_for_join('||quote_literal(nodeset_B_prefix)||','||quote_literal(nodeset_B_table_name)||')' INTO join_sql_table_B;
	RAISE NOTICE 'join_sql_table_B: %', join_sql_table_B;
	--create a temporary table name for joining the two attribute tables of nodeset_A and nodeset_B
	temp_table_name_join := 'nodeset_A_join_nodeset_B';
	
	--drop the temporary table if it exists
	EXECUTE 'DROP TABLE IF EXISTS '||quote_ident(temp_table_name_join);
	
	--create the temporary table as a join between nodeset_A table and nodeset_B table, based upon common attributes supplied
	EXECUTE 'CREATE TEMPORARY TABLE '||quote_ident(temp_table_name_join)||' AS SELECT '||join_sql_table_A||', '||join_sql_table_B||' FROM '||quote_ident(nodeset_A_table_name)||' LEFT OUTER JOIN '||quote_ident(nodeset_B_table_name)||' ON ('||quote_ident(nodeset_A_table_name)||'.'||quote_ident(nodeset_A_attribute_name)||' = '||quote_ident(nodeset_B_table_name)||'.'||quote_ident(nodeset_B_attribute_name)||');';
	
	--create the final join key based on the prefix supplied and the attribute of nodeset_A
	new_join_key_name := nodeset_A_prefix||nodeset_A_attribute_name;
	
	--drop the output table (name given as parameter)
	EXECUTE 'DROP TABLE IF EXISTS '||quote_ident(output_table_name);
	
	--create the output table as a join between the newly joined two tables (nodeset_A, nodeset_B), and the new table containing the link geometry and distance
	EXECUTE 'CREATE TABLE '||quote_ident(output_table_name)||' AS SELECT '||quote_ident(temp_table_name_join)||'.*, "node_A_id", "node_A_attr", "node_A_geom", "node_B_id", "node_B_attr", "node_B_geom", "node_AB_line", "node_AB_distance" FROM '||quote_ident(temp_table_name_join)||' LEFT OUTER JOIN '||quote_ident(temp_table_name)||' ON ('||quote_ident(new_join_key_name)||' = "node_A_attr");';
	
	--delete old temp table (of nodeset_A, nodeset_B)
	EXECUTE 'DROP TABLE IF EXISTS '||quote_ident(temp_table_name_join);
	--delete old temp table (of join table containing new geometry and distance of link between node sets)
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
ALTER FUNCTION ni_link_nodeb_to_nodea_by_attribute(character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, boolean) OWNER TO postgres;
