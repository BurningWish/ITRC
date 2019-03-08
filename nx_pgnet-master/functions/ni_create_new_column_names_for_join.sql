-- Function: ni_create_new_column_names_for_join(character varying, character varying)

-- DROP FUNCTION ni_create_new_column_names_for_join(character varying, character varying);

CREATE OR REPLACE FUNCTION ni_create_new_column_names_for_join(character varying, character varying)
  RETURNS text AS
$BODY$
DECLARE
	
	--prefix for all columns in the given table (param 2)
	table_prefix ALIAS for $1;
	
	--table to prefix all columns with table_prefix (param 1)
	table_name ALIAS for $2;
	
	--sql string to return to user, with newly columns names based on table_prefix (param 1)
	sql_string text := '';
	
	--stores count of number of columns in given table (param 1)
	column_count integer := 0;
	
	--counter to help determine when on last column
	current_column_counter integer := 0;
	
	--to store new column name as a combination of table prefix (param 1) and column names from the table in param 2
	new_column_name text := '';

	--to store column name, when looping information_schema.columns
	information_schema_table_record RECORD;
	
BEGIN
	
	--count columns in information schema
	EXECUTE 'SELECT COUNT(column_name) FROM information_schema.columns WHERE table_name = '||quote_literal(table_name) INTO column_count;	
	
	current_column_counter := 0;
	
	--loop all columns in given table (param 2)
	FOR information_schema_table_record IN EXECUTE 'SELECT column_name FROM information_schema.columns WHERE table_name='||quote_literal(table_name) LOOP
		current_column_counter := current_column_counter + 1;
		new_column_name := '';
		new_column_name := table_prefix||information_schema_table_record.column_name;
		IF column_count > current_column_counter THEN
			sql_string = sql_string||quote_ident(table_name)||'.'||information_schema_table_record.column_name||' AS '||quote_ident(new_column_name)||', ';
		ELSE
			sql_string = sql_string||quote_ident(table_name)||'.'||information_schema_table_record.column_name||' AS '||quote_ident(new_column_name);
		END IF;
	END LOOP;
	
	--e.g. if columns in input table are (A, B, C, D), and table prefix is 'Test_'
	--the resultant sql_string will be Test_A, Test_B, Test_C, Test_D
	
	--return sql string to user		
	RETURN sql_string;
	
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION ni_create_new_column_names_for_join(character varying, character varying) OWNER TO postgres;
