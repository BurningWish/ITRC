
CREATE OR REPLACE FUNCTION ni_union_geometry_distinct_records(character varying, character varying, character varying, character varying, boolean)
  RETURNS SETOF record AS
$BODY$
DECLARE
	
	--table to query
	table_name_to_query ALIAS for $1;
	
	--distinct column name from table to query
	distinct_column_name ALIAS for $2;
	
	--name of geometry column to union from table to query
	geometry_column_name ALIAS for $3;
	
	--name of new table to create to store unioned geometry
	table_name_to_create ALIAS for $4;
	
	--boolean to denote whether to add the result to the geometry columns table
	add_to_geometry_columns ALIAS for $5;
	
	--empty record for looping edge table
	union_record RECORD;
	
	--result of union geometry;
	union_geometry text := '';
	
	--data type of distinct column
	distinct_column_datatype text := '';
	
	--epsg coord system 
	srid integer := 27700;
	
	--schema name
	schema_name varchar := 'public';
	
	--geometry type of geometry column to union
	geometry_type varchar := '';
	
	--snapping tolerance
	snap_distance float := 1;
	
	simplify_distance float := 1;
	
	new_simplify_distance float := 0.0;
	
	new_snap_distance float := 0.0;
	
	geometry_type_post_union varchar := '';
	
	counter integer := 0;
	
	simplify_distance_increment float := 0.1;
	
	snap_distance_increment float := 0.1;
	
	linestring_geom text := '';
	
	num_linestrings integer := 0;
	
BEGIN
	
	RAISE NOTICE 'table_name_to_create: %', table_name_to_create;
	RAISE NOTICE 'geometry_column_name: %', geometry_column_name;
	RAISE NOTICE 'distinct_column_name: %', distinct_column_name;
	RAISE NOTICE 'table_name_to_query: %', table_name_to_query;
	
	--get distinct column data type
	EXECUTE 'SELECT data_type FROM information_schema.columns WHERE table_name = '||quote_literal(table_name_to_query)||' AND column_name = '||quote_literal(distinct_column_name) INTO distinct_column_datatype;

	RAISE NOTICE 'distinct_column_datatype: %' , distinct_column_datatype;
	
	--get geometry type
	EXECUTE 'SELECT "type" FROM geometry_columns WHERE f_table_catalog = '''' AND f_table_schema = '||quote_literal(schema_name)||' AND f_table_name = '||quote_literal(table_name_to_query)||' AND f_geometry_column = '||quote_literal(geometry_column_name) INTO geometry_type;
	
	RAISE NOTICE 'geometry_type: %', geometry_type;
	
	--drop the previous table
	EXECUTE 'DROP TABLE IF EXISTS '||quote_ident(table_name_to_create);
	
	--create an empty table based on the input table
	--EXECUTE 'CREATE TABLE '||quote_ident(table_name_to_create)||' ('||quote_ident(distinct_column_name)||' '||distinct_column_datatype||', '||quote_ident(geometry_column_name)||' geometry)'; 
	--EXECUTE 'CREATE TABLE '||quote_ident(table_name_to_create)||' AS SELECT '||quote_ident(distinct_column_name)||', ST_LineMerge(ST_Union(ST_SnapToGrid(ST_Simplify(f.'||quote_ident(geometry_column_name)||', '||simplify_distance||'), '||snap_distance||'))) as geom FROM '||quote_ident(table_name_to_query)||' AS f GROUP BY '||quote_ident(distinct_column_name);
	--EXECUTE 'CREATE TABLE '||quote_ident(table_name_to_create)||' AS SELECT '||quote_ident(distinct_column_name)||', ST_LineMerge(ST_SnapToGrid(ST_Simplify('||quote_ident(geometry_column_name)||', '||simplify_distance||'), '||snap_distance||')) as geom FROM '||quote_ident(table_name_to_query);
	EXECUTE 'CREATE TABLE '||quote_ident(table_name_to_create)||' AS SELECT gid, '||quote_ident(distinct_column_name)||', ST_LineMerge(ST_SnapToGrid(ST_Simplify('||quote_ident(geometry_column_name)||', '||simplify_distance||'), '||snap_distance||')) as geom FROM '||quote_ident(table_name_to_query);
	
	FOR union_record IN EXECUTE 'SELECT gid, ST_AsText('||quote_ident(geometry_column_name)||') as geom, '||quote_ident(distinct_column_name)||' as distinct_ FROM '||quote_ident(table_name_to_create)||' WHERE ST_GeometryType('||quote_ident(geometry_column_name)||') = ''ST_MultiLineString'' ORDER BY '||quote_ident(distinct_column_name)||' ASC' LOOP
	
	
		--FOR i IN 1..union_record.num_geom LOOP
						
			--EXECUTE 'SELECT ST_AsText(ST_GeometryN(ST_GeomFromText('||quote_literal(union_record.geom)||', '||srid||'), '||i||'))' INTO linestring_geom;
			--RAISE NOTICE 'linestring_geom: %', linestring_geom;
			--EXECUTE 'INSERT INTO '||quote_ident(table_name_to_create)||' (gid, '||quote_ident(distinct_column_name)||', '||quote_ident(geometry_column_name)||') VALUES ('||union_record.gid||', '||quote_literal(union_record.distinct_)||', ST_GeomFromText('||quote_literal(linestring_geom)||', '||srid||'))';
			
		--END LOOP;
	
		
		--RAISE NOTICE 'union_record geom: %' , union_record.geom;
		RAISE NOTICE 'union_record pipe: %' , union_record.distinct_;
		counter := 0;
		counter := counter + 1;
		new_simplify_distance = simplify_distance + (simplify_distance_increment*counter);
		new_snap_distance = snap_distance + (snap_distance_increment*counter);
		
		--RAISE NOTICE 'new_simplify_distance: %', new_simplify_distance;
		--RAISE NOTICE 'new_snap_distance: %', new_snap_distance;
		
		--what can I do with these multilinestring records to make them valid "linestring" records
		--EXECUTE 'SELECT ST_AsText(ST_LineMerge(ST_Union(ST_SnapToGrid(ST_Simplify(ST_GeomFromText('||quote_literal(union_record.geom)||', '||srid||'), '||new_simplify_distance||'), '||new_snap_distance||'))))' INTO union_geometry;
		EXECUTE 'SELECT ST_AsText(ST_LineMerge(ST_SnapToGrid(ST_Simplify(ST_GeomFromText('||quote_literal(union_record.geom)||', '||srid||'), '||new_simplify_distance||'), '||new_snap_distance||')))' INTO union_geometry;
		
		EXECUTE 'SELECT ST_GeometryType(ST_GeomFromText('||quote_literal(union_record.geom)||', '||srid||')) ' INTO geometry_type_post_union;
		
		RAISE NOTICE 'geom type 1: %', geometry_type_post_union;
		
		IF geometry_type_post_union = 'ST_MultiLineString' THEN
			counter := 0;
			WHILE geometry_type_post_union = 'ST_MultiLineString' LOOP
				counter := counter + 1;
				new_simplify_distance = simplify_distance + (simplify_distance_increment*counter);
				new_snap_distance = snap_distance + (snap_distance_increment*counter);
				
				--new_simplify_distance := (simplify_distance*counter);
				--new_snap_distance := (snap_distance*counter);
				
				--EXECUTE 'SELECT ST_AsText(ST_LineMerge(ST_Union(ST_SnapToGrid(ST_Simplify(ST_GeomFromText('||quote_literal(union_record.geom)||', '||srid||'), '||new_simplify_distance||'), '||new_snap_distance||'))))' INTO union_geometry;
				EXECUTE 'SELECT ST_AsText(ST_LineMerge(ST_SnapToGrid(ST_Simplify(ST_GeomFromText('||quote_literal(union_record.geom)||', '||srid||'), '||new_simplify_distance||'), '||new_snap_distance||')))' INTO union_geometry;
				
				EXECUTE 'SELECT ST_GeometryType(ST_GeomFromText('||quote_literal(union_geometry)||', '||srid||')) ' INTO geometry_type_post_union;				
				--RAISE NOTICE 'new_simplify_distance: %', new_simplify_distance;
				--RAISE NOTICE 'new_snap_distance: %', new_snap_distance;
				RAISE NOTICE 'geom type 2: %', geometry_type_post_union;
				
				RAISE NOTICE 'union_geometry: %', union_geometry;
				
			END LOOP;
			
			--it is overwriting the other geometries due to only updating based on the distinct pipe_name			
			EXECUTE 'UPDATE '||quote_ident(table_name_to_create)||' SET '||quote_ident(geometry_column_name)||' = ST_GeomFromText('||quote_literal(union_geometry)||', '||srid||') WHERE '||quote_ident(distinct_column_name)||' = '||quote_literal(union_record.distinct_)||' AND gid = '||union_record.gid;
		END IF;
		
		RAISE NOTICE 'union_record pipe: %' , union_record.distinct_;
		
	END LOOP;
	
	--grab all records
	
	--EXECUTE 'INSERT INTO '||quote_ident(table_name_to_create)||' ('||quote_ident(distinct_column_name)||','||quote_ident(geometry_column_name)||') VALUES ('||quote_ident(distinct_column_name)||', (SELECT ST_LineMerge(ST_Multi(ST_Union(ST_SimplifyPreserveTopology('||quote_ident(geometry_column_name)||', 1)))) GROUP BY '||quote_ident(distinct_column_name)||'))';
	
	--loop distinct records
	/*FOR union_record IN EXECUTE 'SELECT DISTINCT('||quote_ident(distinct_column_name)||') as distinct_ FROM '||quote_ident(table_name_to_query)||' ORDER BY '||quote_ident(distinct_column_name) LOOP

		RAISE NOTICE 'union_record distinct: %' , union_record.distinct_;
		
		--union the geometry of distinct records
		EXECUTE 'SELECT ST_AsText(ST_LineMerge(ST_Union(ST_SimplifyPreserveTopology('||quote_ident(geometry_column_name)||', 1)))) FROM '||quote_ident(table_name_to_query)||' WHERE '||quote_ident(distinct_column_name)||' = '||quote_literal(union_record.distinct_) INTO union_geometry;	

		RAISE NOTICE 'union_geometry: %' , union_geometry;
		
		IF union_geometry IS NOT NULL OR union_geometry != '' THEN
			
			--add the unioned geometry to the new table
			EXECUTE 'INSERT INTO '||quote_ident(table_name_to_create)||' ('||quote_ident(distinct_column_name)||','||quote_ident(geometry_column_name)||') VALUES ('||quote_literal(union_record.distinct_)||', ST_GeomFromText('||quote_literal(union_geometry)||','||srid||'))';
		
		END IF;
		
	END LOOP;*/
		
	EXECUTE 'UPDATE '||quote_ident(table_name_to_create)||' SET '||quote_ident(geometry_column_name)||' = ST_SnapToGrid('||quote_ident(geometry_column_name)||', '||snap_distance||') WHERE ST_GeometryType('||quote_ident(geometry_column_name)||') = ''ST_MultiLineString''';
		
	IF add_to_geometry_columns IS TRUE THEN
			
		--unique table
		RAISE NOTICE 'Adding to geometry columns (unique table) - geom';
		EXECUTE 'SELECT * FROM ni_add_to_geometry_columns('||quote_literal(table_name_to_create)||', '''', '||quote_literal(schema_name)||','||quote_literal(geometry_column_name)||','||dims||','||srid||', '||quote_literal(geometry_type)||')';
	
	END IF;
	RAISE NOTICE 'Returning records';
	RETURN QUERY EXECUTE 'SELECT * FROM '||quote_ident(table_name_to_create);
	
END
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION ni_union_geometry_distinct_records(character varying, character varying, character varying, character varying, boolean) OWNER TO postgres;
