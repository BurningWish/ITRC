-- Function: ni_nearest_point_to_line_segment(character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, double precision, double precision, character varying, boolean)

-- DROP FUNCTION ni_nearest_point_to_line_segment(character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, double precision, double precision, character varying, boolean);

CREATE OR REPLACE FUNCTION ni_nearest_point_to_line_segment(character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, double precision, double precision, character varying, boolean)
  RETURNS SETOF record AS
$BODY$
DECLARE

	--line table name
	line_table_name ALIAS for $1;
	
	--geometry column name of line table
	line_table_geometry_column_name ALIAS for $2;
	
	--primary key of line dataset
	line_table_prkey ALIAS for $3;
	
	--line_table_name prefix - prefixes all line_table_name attributes for the join to avoid duplicate column names	
	line_geom_prefix ALIAS for $4;
	
	--point table name
	point_table_name ALIAS for $5;
	
	--geometry column name of point dataset
	point_table_geometry_column_name ALIAS for $6;
	
	--primary key or point dataset
	point_table_prkey ALIAS for $7;
	
	--point_table_name prefix - prefixes all point_table_name attributes for the join to avoid duplicate column names	
	point_geom_prefix ALIAS for $8;
	
	--to split each line by a set distance
	line_split_distance ALIAS for $9;
	
	--for buffering each line segment
	buffer_distance ALIAS for $10;
	
	--output table name 
	output_table_name ALIAS for $11;
	
	--indicates whether or not to add the resulting output table to the geometry columns table
	add_to_geometry_columns ALIAS for $12;
	
	--record structure for holding rows from the point dataset
	point_table_record RECORD;
	
	--record structure for holding rows from the line dataset
	line_table_record RECORD;
	
	--temporary table to store the segments of each line split by the line_split_distance
	temp_table_name text;
	
	--used to store the maximum length of a line in the line table provided
	max_line_length double precision;
	
	--used to store the raw number of iterations needed across the line table
	raw_series_length double precision;
	
	--used to store the rounded number of iterations needed across the line table
	round_series_length integer := 0;
	
	--record to hold the table structure for the link with shortest distance from line table to point
	smallest_line_link RECORD;
	
	--record to hold table structure for looping line table
	line_segment_record RECORD;
	
	--used to store the number of points that lie within the buffered section of the line segment
	num_buffer_points integer;
	
	--used to determine if the line section is a MULTILINESTRING or a LINESTRING (currently MULTILINESTRINGS founds after ST_LineMerge are ignored)
	strpos_ integer;
	
	--temporary table to store the initial results of the point to line operation (with the following structure)
	--point_prkey - point table primary key
	--point_geom - input point geometry
	--point_fraction - fraction of line along which point lies
	--perp_point_on_line - point on line
	--point_to_perp_point_line - new geometry linking line segment with nearest point to line segment
	--point_to_perp_point_line_length - length of new geometry
	initial_results_temp_table_name text := '';
	
	--temporary table to store the initial results point the point to line operation JOINED to the line input data
	line_join_temp_table_name text := '';
	
	--auto-generated column names and aliases sql based on line_geom_prefix and column names from line_table_name
	join_sql_line_table text := '';
	
	--auto-generated column names and aliases sql based on point_geom_prefix and column names from point_table_name
	join_sql_point_table text := '';
	
	--dimensions 
	dims integer := 2;
	
	--schema_name 
	schema_name varchar := 'public';
	
	--srid of line table
	line_geom_table_srid integer := 27700;
	
	--srid of point table
	point_geom_table_srid integer := 27700;
	
BEGIN
	
	--define the temporary table name for all the individual line segments and their buffers
	temp_table_name := 'temp_'||output_table_name;
	
	--initial results temporary table
	initial_results_temp_table_name := 'temp_results_'||output_table_name;
	
	--table name to hold initial result joined to line table attributes
	line_join_temp_table_name := 'line_join_'||initial_results_temp_table_name;
	
	--drop the initial results temporary table joined to the line attribute table
	EXECUTE 'DROP TABLE IF EXISTS '||quote_ident(line_join_temp_table_name);
	
	--drop the initial results temporary table
	EXECUTE 'DROP TABLE IF EXISTS '||quote_ident(initial_results_temp_table_name);
	
	--delete the temporary table
	EXECUTE 'DROP TABLE IF EXISTS '||quote_ident(temp_table_name);
	
	--delete the output table if it exists
	EXECUTE 'DROP TABLE IF EXISTS '||quote_ident(output_table_name);
	
	--calculate the maximum line length for a line in the line table
	EXECUTE 'SELECT MAX(ST_Length('||quote_ident(line_table_geometry_column_name)||')) FROM '||quote_ident(line_table_name) INTO max_line_length;
	
	--calculate the raw series length based on the maximum line length / supplied line split distance
	SELECT (max_line_length/line_split_distance) INTO raw_series_length;
	
	--round up the series length
	SELECT ceil(raw_series_length) INTO round_series_length;
	
	--this table contains all the original ids, and the newly created line segments i.e. multiple line segments per original id
	EXECUTE 'CREATE TEMPORARY TABLE '||quote_ident(temp_table_name)||' AS SELECT '||quote_ident(line_table_prkey)||', ST_LineMerge(ST_Line_Substring('||quote_ident(line_table_geometry_column_name)||', startfrac, endfrac)) AS '||quote_ident(line_table_geometry_column_name)||' FROM (SELECT '||quote_ident(line_table_prkey)||', ('||line_split_distance||'*n/length) AS startfrac, CASE WHEN ('||line_split_distance||'*(n+1)) < length THEN ('||line_split_distance||'*(n+1)/length) ELSE 1 END AS endfrac, length, '||quote_ident(line_table_geometry_column_name)||' FROM (SELECT '||quote_ident(line_table_prkey)||', ST_LineMerge('||quote_ident(line_table_geometry_column_name)||') AS '||quote_ident(line_table_geometry_column_name)||', ST_Length('||quote_ident(line_table_geometry_column_name)||') AS length FROM '||quote_ident(line_table_name)||') t CROSS JOIN generate_series(0, '||round_series_length||') n WHERE n * '||line_split_distance||' / length < 1) AS segments';
	
	--add a length column to the temporary table
	EXECUTE 'ALTER TABLE '||quote_ident(temp_table_name)||' ADD COLUMN length double precision;';
	
	--calculate the length of each of the line segments. The result should be that we never see a line segment length < line_split_distance
	EXECUTE 'UPDATE '||quote_ident(temp_table_name)||' SET length = ST_Length('||quote_ident(line_table_geometry_column_name)||');';
	
	--add a column to the temporary table to contain the buffer for each line segment
	EXECUTE 'ALTER TABLE '||quote_ident(temp_table_name)||' ADD COLUMN buffer_geom geometry;';
	
	--calculate the buffer for each of the line segments, based on the supplied buffer distance
	EXECUTE 'UPDATE '||quote_ident(temp_table_name)||' SET buffer_geom = ST_SetSRID(ST_Buffer('||quote_ident(line_table_geometry_column_name)||', '||buffer_distance||'), '||line_geom_table_srid||')';
	
	--drop the table to contain the initial results prior to being rejoined
	EXECUTE 'DROP TABLE IF EXISTS '||quote_ident(initial_results_temp_table_name);
	
	--create the temporary table to store the initial results prior to being rejoined
	EXECUTE 'CREATE TEMPORARY TABLE '||quote_ident(initial_results_temp_table_name)||' (point_prkey integer, point_geom geometry, point_fraction double precision, perp_point_on_line geometry, point_to_perp_point_line geometry, point_to_perp_point_line_length double precision, line_prkey integer, line_geom geometry)';
	
	--drop the temporary table to contain the results of the buffer intersection
	EXECUTE 'DROP TABLE IF EXISTS points_intersect_buffer_geom';
	
	--create the temporary table to contain the results of the buffer intersection
	--point_prkey - point table primary key
	--point_geom - input point geometry
	--point_fraction - fraction of line along which point lies
	--perp_point_on_line - point on line
	--point_to_perp_point_line - new geometry linking line segment with nearest point to line segment
	--point_to_perp_point_line_length - length of new geometry
	EXECUTE 'CREATE TEMPORARY TABLE points_intersect_buffer_geom (point_prkey integer, point_geom geometry, point_fraction double precision, perp_point_on_line geometry, point_to_perp_point_line geometry, point_to_perp_point_line_length double precision)';
	
	--loop each line segment, to perform intersection with point data
	FOR line_segment_record IN EXECUTE 'SELECT '||quote_ident(line_table_prkey)||' AS line_prkey, ST_AsText(ST_LineMerge('||quote_ident(line_table_geometry_column_name)||')) AS line_geom, length AS length, ST_AsText(buffer_geom) AS buffer_geom FROM '||quote_ident(temp_table_name) LOOP
		
		--check if the line geometry is a MULTILINESTRING
		SELECT strpos(line_segment_record.line_geom, 'MULTI') INTO strpos_;
		
		--ignore multilinestring if linemerge still resulting in multilinestring
		IF strpos_ = 0 THEN 
			
			--add the points to the table that lie within the buffer of the line segment
			EXECUTE 'INSERT INTO points_intersect_buffer_geom (point_prkey, point_geom) SELECT '||quote_ident(point_table_prkey)||' AS point_prkey, ST_AsText('||quote_ident(point_table_geometry_column_name)||') AS point_geom FROM '||quote_ident(point_table_name)||' WHERE ST_Intersects(ST_GeomFromText('||quote_literal(line_segment_record.buffer_geom)||','||line_geom_table_srid||') , '||quote_ident(point_table_geometry_column_name)||')';
			
			--calculate the number of points in the buffer intersection
			EXECUTE 'SELECT COUNT(*) FROM points_intersect_buffer_geom' INTO num_buffer_points;
			
			--ensure that the point dataset has the BNG projection (COULD THIS BE A PARAMETER)
			EXECUTE 'UPDATE points_intersect_buffer_geom SET point_geom = ST_SetSRID (point_geom, '||point_geom_table_srid||')';
			
			IF num_buffer_points > 0 THEN
			
				--calculate the point fraction of the point along the line
				EXECUTE 'UPDATE points_intersect_buffer_geom SET point_fraction = ST_line_locate_point(ST_LineMerge(ST_GeomFromText('||quote_literal(line_segment_record.line_geom)||', '||point_geom_table_srid||')), point_geom)';
				
				--create a point on the line based on the fraction - this represents the perpendicular point on the line closest to each point in the buffer		
				EXECUTE 'UPDATE points_intersect_buffer_geom SET perp_point_on_line = ST_line_interpolate_point(ST_GeomFromText('||quote_literal(line_segment_record.line_geom)||', '||line_geom_table_srid||'), point_fraction)';
				
				--create the line
				EXECUTE 'UPDATE points_intersect_buffer_geom SET point_to_perp_point_line = ST_MakeLine(point_geom, perp_point_on_line)';
				
				--calculate the length of each line
				EXECUTE 'UPDATE points_intersect_buffer_geom SET point_to_perp_point_line_length = ST_Length(point_to_perp_point_line)';
					
				--grab the smallest point_to_perp_point_line_length as this is closest to the line	
				EXECUTE 'SELECT point_prkey AS point_prkey, ST_AsText(point_geom) AS point_geom, point_fraction AS point_fraction, ST_AsText(perp_point_on_line) AS perp_point_on_line, ST_AsText(point_to_perp_point_line) AS point_to_perp_point_line, point_to_perp_point_line_length As point_to_perp_point_line_length FROM points_intersect_buffer_geom ORDER BY point_to_perp_point_line_length ASC LIMIT 1' INTO smallest_line_link;
				
				--add the result to the initial results table
				EXECUTE 'INSERT INTO '||quote_ident(initial_results_temp_table_name)||' (point_prkey, point_geom, point_fraction, perp_point_on_line, point_to_perp_point_line, point_to_perp_point_line_length, line_prkey, line_geom) VALUES ('||smallest_line_link.point_prkey||', ST_GeomFromText('||quote_literal(smallest_line_link.point_geom)||','||point_geom_table_srid||'), '||smallest_line_link.point_fraction||', ST_GeomFromText('||quote_literal(smallest_line_link.perp_point_on_line)||', '||point_geom_table_srid||'), ST_GeomFromText('||quote_literal(smallest_line_link.point_to_perp_point_line)||', '||line_geom_table_srid||'), '||smallest_line_link.point_to_perp_point_line_length||', '||line_segment_record.line_prkey||', ST_GeomFromText('||quote_literal(line_segment_record.line_geom)||', '||line_geom_table_srid||'))';
				
			ELSE
				
				--insert empty values if no points are within the buffer
				EXECUTE 'INSERT INTO '||quote_ident(initial_results_temp_table_name)||' (line_prkey, line_geom) VALUES ('||line_segment_record.line_prkey||', ST_GeomFromText('||quote_literal(line_segment_record.line_geom)||', '||line_geom_table_srid||'))';
				
			END IF;
		
		END IF;
		
		--remove all rows from temporary table - rather than deleting / creating 
		EXECUTE 'TRUNCATE points_intersect_buffer_geom';
		
	END LOOP;
	
	--create the custom column names from nodeset_A
	EXECUTE 'SELECT * FROM ni_create_new_column_names_for_join('||quote_literal(line_geom_prefix)||','||quote_literal(line_table_name)||')' INTO join_sql_line_table;
	RAISE NOTICE 'join_sql_line_table: %', join_sql_line_table;
	
	--perform a join based on line_prkey to join line table attributes back to new output table	
	EXECUTE 'CREATE TEMPORARY TABLE '||quote_ident(line_join_temp_table_name)||' AS SELECT '||quote_ident(initial_results_temp_table_name)||'.*, '||join_sql_line_table||' FROM '||quote_ident(initial_results_temp_table_name)||' LEFT OUTER JOIN '||quote_ident(line_table_name)||' ON ('||quote_ident(initial_results_temp_table_name)||'.line_prkey = '||quote_ident(line_table_name)||'.'||quote_ident(line_table_prkey)||');';
	
	--create the custom column names for nodeset_B
	EXECUTE 'SELECT * FROM ni_create_new_column_names_for_join('||quote_literal(point_geom_prefix)||','||quote_literal(point_table_name)||')' INTO join_sql_point_table;
	RAISE NOTICE 'join_sql_point_table: %', join_sql_point_table;
	
	--perform a join based on the point_prkey to join the point table attributes back to new output table
	EXECUTE 'CREATE TABLE '||quote_ident(output_table_name)||' AS SELECT '||quote_ident(line_join_temp_table_name)||'.*, '||join_sql_point_table||' FROM '||quote_ident(line_join_temp_table_name)||' LEFT OUTER JOIN '||quote_ident(point_table_name)||' ON ('||quote_ident(line_join_temp_table_name)||'.point_prkey = '||quote_ident(point_table_name)||'.'||quote_ident(point_table_prkey)||');';
	
	--add the output to the geometry columns table
	IF add_to_geometry_columns IS TRUE THEN
		
		RAISE NOTICE 'Adding to geometry columns (point_geom)';
		EXECUTE 'SELECT * FROM ni_add_to_geometry_columns('||quote_literal(output_table_name)||', '''', '||quote_literal(schema_name)||',''point_geom'','||dims||','||point_geom_table_srid||', ''POINT'')';
		
		RAISE NOTICE 'Adding to geometry columns (line_geom)';
		EXECUTE 'SELECT * FROM ni_add_to_geometry_columns('||quote_literal(output_table_name)||', '''', '||quote_literal(schema_name)||',''line_geom'','||dims||','||line_geom_table_srid||', ''POINT'')';
		
		RAISE NOTICE 'Adding to geometry columns (point_to_perp_point_line)';
		EXECUTE 'SELECT * FROM ni_add_to_geometry_columns('||quote_literal(output_table_name)||', '''', '||quote_literal(schema_name)||',''point_to_perp_point_line'','||dims||','||line_geom_table_srid||', ''POINT'')';
		
	END IF;
	
	RAISE NOTICE 'Returning records';
	RETURN QUERY EXECUTE 'SELECT * FROM '||quote_ident(initial_results_temp_table_name);
	
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION ni_nearest_point_to_line_segment(character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, double precision, double precision, character varying, boolean) OWNER TO postgres;
