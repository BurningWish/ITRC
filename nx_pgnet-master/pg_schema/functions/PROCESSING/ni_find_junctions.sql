
CREATE OR REPLACE FUNCTION ni_find_junctions(character varying, character varying, character varying, character varying, character varying)
  RETURNS void AS
$BODY$ 
DECLARE
	
	--name of original input line data
	original_line_table_name ALIAS for $1;	
	
	--name of original input line data, split by all vertices
	split_line_table_name ALIAS for $2;
	
	--unique key for split_line_table_name
	original_line_table_unique_key ALIAS for $3;
	
	--junction table name to create
	junction_table_name ALIAS for $4;
	
	--attribute value to apply to junctions (i.e. all cases where intersection count != 1)
	junction_attribute_value ALIAS for $5;
	
	--to store the intersection count results
	intersect_count_table_name varchar := '';
	
	--unique junction table name
	junction_table_name_unique varchar := '';
	
	--to store the tables of start and end points
	start_point_line_table_name varchar := '';
	end_point_line_table_name varchar := '';
	both_end_point_line_table_name varchar := '';
	
	--sequence name for combined start and end point table generated
	sequence_name varchar := '';
	
BEGIN
	
	--create the table names for the start, end and start/end tables
	start_point_line_table_name := original_line_table_name||'_Start_Pts';
	end_point_line_table_name := original_line_table_name||'_End_Pts';
	both_end_point_line_table_name := original_line_table_name||'_Start_End_Pts';	
	intersect_count_table_name := original_line_table_name||'_Intersect_count';
	junction_table_name_unique := junction_table_name||'_unique';
	
	--define the sequence name for the start and end point table
	sequence_name := 'union_seq_'||both_end_point_line_table_name;
	
	--create the start points (2)
	EXECUTE 'DROP TABLE IF EXISTS '||quote_ident(start_point_line_table_name);	
	EXECUTE 'CREATE TABLE '||quote_ident(start_point_line_table_name)||' AS SELECT '||quote_ident(original_line_table_name)||'.*, ST_StartPoint(geom) as geom_ FROM '||quote_ident(original_line_table_name);
	
	--create the end points (3)
	EXECUTE 'DROP TABLE IF EXISTS '||quote_ident(end_point_line_table_name);	
	EXECUTE 'CREATE TABLE '||quote_ident(end_point_line_table_name)||' AS SELECT '||quote_ident(original_line_table_name)||'.*, ST_EndPoint(geom) as geom_ FROM '||quote_ident(original_line_table_name);
	
	--union the start and end points (4)
	EXECUTE 'DROP TABLE IF EXISTS '||quote_ident(both_end_point_line_table_name);	
	EXECUTE 'CREATE TABLE '||quote_ident(both_end_point_line_table_name)||' AS SELECT '||quote_ident(start_point_line_table_name)||'.* FROM '||quote_ident(start_point_line_table_name)||' UNION ALL SELECT '||quote_ident(end_point_line_table_name)||'.* FROM '||quote_ident(end_point_line_table_name);
	
	--add a unique id column to the start and end point table, and create a sequence to uniquely identify each	
	EXECUTE 'ALTER TABLE '||quote_ident(both_end_point_line_table_name)||' ADD COLUMN unique_id INTEGER';
	EXECUTE 'DROP SEQUENCE IF EXISTS '||quote_ident(sequence_name)||' CASCADE';
	EXECUTE 'CREATE SEQUENCE '||quote_ident(sequence_name);
	EXECUTE 'UPDATE '||quote_ident(both_end_point_line_table_name)||' SET unique_id = nextval('''||quote_ident(sequence_name)||''')';
	EXECUTE 'ALTER TABLE '||quote_ident(both_end_point_line_table_name)|| 'ALTER COLUMN unique_id SET DEFAULT nextval('''||quote_ident(sequence_name)||''')';
	
	--drop the both index
	EXECUTE 'DROP INDEX IF EXISTS '||quote_ident(both_end_point_line_table_name||'_gist');	
	--create the both index
	EXECUTE 'CREATE INDEX '||quote_ident(both_end_point_line_table_name||'_gist')||' ON '||quote_ident(both_end_point_line_table_name)||' USING gist(geom_)';
	
	--delete the intersection count table
	EXECUTE 'DROP TABLE IF EXISTS '||quote_ident(intersect_count_table_name);	
	--create the intersection count table		
	EXECUTE 'CREATE TABLE '||quote_ident(intersect_count_table_name)||' AS SELECT '||quote_ident(both_end_point_line_table_name)||'.unique_id, COUNT(*) as intersect_count FROM '||quote_ident(both_end_point_line_table_name)||', '||quote_ident(split_line_table_name)||' WHERE ST_Intersects('||quote_ident(split_line_table_name)||'.geom, '||quote_ident(both_end_point_line_table_name)||'.geom_) GROUP BY ('||quote_ident(both_end_point_line_table_name)||'.unique_id) ORDER BY unique_id ASC';
	
	--delete all those with intersection count = 2
	EXECUTE 'DELETE FROM '||quote_ident(intersect_count_table_name)||' WHERE intersect_count = 2';
	
	--remove the old junction table (contains duplicates)
	EXECUTE 'DROP TABLE IF EXISTS '||quote_ident(junction_table_name);
	
	--create the junction table by joining back to the original data	
	EXECUTE 'CREATE TABLE '||quote_ident(junction_table_name)||' AS SELECT '||quote_ident(both_end_point_line_table_name)||'.*, '||quote_ident(intersect_count_table_name)||'.intersect_count FROM '||quote_ident(both_end_point_line_table_name)||', '||quote_ident(intersect_count_table_name)||' WHERE '||quote_ident(both_end_point_line_table_name)||'.unique_id = '||quote_ident(intersect_count_table_name)||'.unique_id';
	
	--remove the old unique junction table (no duplicates)
	EXECUTE 'DROP TABLE IF EXISTS '||quote_ident(junction_table_name_unique);
	
	--create a unique version of the table (no duplicates)	
	EXECUTE 'CREATE TABLE '||quote_ident(junction_table_name_unique)||' AS SELECT min('||quote_ident(original_line_table_unique_key)||') AS '||quote_ident(original_line_table_unique_key)||', min(intersect_count) as intersect_count, geom_ FROM '||quote_ident(junction_table_name)||' GROUP BY geom_ ORDER BY '||quote_ident(original_line_table_unique_key);
	
	--rename column geom_ to geom
	EXECUTE 'ALTER TABLE '||quote_ident(junction_table_name_unique)||' RENAME COLUMN geom_ TO geom';	
	
	--add the usual constraints to the output table
	EXECUTE 'ALTER TABLE '||quote_ident(junction_table_name_unique)||' ADD CONSTRAINT enforce_dims_geom CHECK (st_ndims(geom) = 2)';
	EXECUTE 'ALTER TABLE '||quote_ident(junction_table_name_unique)||' ADD CONSTRAINT enforce_geotype_geom CHECK (geometrytype(geom) = ''POINT''::text OR geom IS NULL)';
	EXECUTE 'ALTER TABLE '||quote_ident(junction_table_name_unique)||' ADD CONSTRAINT enforce_srid_geom CHECK (st_srid(geom) = 27700)';
	
	--drop the spatial index on the unique junction table
	EXECUTE 'DROP INDEX IF EXISTS '||quote_ident(junction_table_name_unique)||'_gist';	
	--create the spatial index on the unique junction table	
	EXECUTE 'CREATE INDEX '||quote_ident(junction_table_name_unique)||'_gist ON '||quote_ident(junction_table_name_unique)||' USING gist(geom)';
	
	--add type attribute and assign end of line or junction values depending on intersect_count
	EXECUTE 'ALTER TABLE '||quote_ident(junction_table_name_unique)|| ' ADD COLUMN "type" varchar(50)';	
	
	--update the type attribute with appropriate values
	EXECUTE 'UPDATE '||quote_ident(junction_table_name_unique)|| ' SET "type" = ''End of line'' WHERE intersect_count = 1';
	EXECUTE 'UPDATE '||quote_ident(junction_table_name_unique)|| ' SET "type" = '||quote_literal(junction_attribute_value)||' WHERE intersect_count != 1';	
	
	--delete the start point table
	EXECUTE 'DROP TABLE IF EXISTS '||quote_ident(start_point_line_table_name);
	
	--delete the end point table
	EXECUTE 'DROP TABLE IF EXISTS '||quote_ident(end_point_line_table_name);
	
	--delete the union start and end point table
	EXECUTE 'DROP TABLE IF EXISTS '||quote_ident(both_end_point_line_table_name);
	
	--delete the non-unique junction table
	EXECUTE 'DROP TABLE IF EXISTS '||quote_ident(junction_table_name);
	
	--delete the intersect count table
	EXECUTE 'DROP TABLE IF EXISTS '||quote_ident(intersect_count_table_name);
	
END
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION ni_find_junctions(character varying, character varying, character varying, character varying, character varying) OWNER TO postgres;
