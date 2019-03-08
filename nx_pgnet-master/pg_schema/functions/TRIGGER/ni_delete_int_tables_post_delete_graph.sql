
CREATE OR REPLACE FUNCTION ni_delete_int_tables_post_delete_graph()
  RETURNS trigger AS
$BODY$ 
DECLARE
	--stores position of _Edges suffix 
    pos integer := 0;
	
	--stores base table name i.e. network name
    base_table_name text := '';
	
	--stores equivalent interdependency and interdependency edge table names, based on interdependency / interdependency_edge suffixes and base table name
	equivalent_interdependency_tablename text := '';
    equivalent_interdependency_edge_tablename text := '';
	
	--interdependency table suffixes
    interdependency_table_suffix varchar := '_Interdependency';
    interdependency_edge_table_suffix varchar := '_Interdependency_Edges';
    
	--interdependency view suffix
    interdependency_interdependency_view_suffix varchar := '_Join_Interdependency_Interdependency_Edges';
    
	--stores records from information_schema.views
    information_schema_record RECORD;
	
	--default schema
	schema_name varchar := 'public';
    
BEGIN
	--calculate position of _Edges in old edges table name
    pos := position('_Edges' in OLD."Edges");
	
	--determine base table name (i.e. network name)
    base_table_name := substring(OLD."Nodes" FROM 0 FOR pos);
	
	--set the equivalent interdependency and interdependency edge table names
    equivalent_interdependency_tablename := base_table_name||interdependency_table_suffix;        
    equivalent_interdependency_edge_tablename := base_table_name||interdependency_edge_table_suffix;

	--remove interdependency and interdependency edge tables
    EXECUTE 'DROP TABLE IF EXISTS '||quote_ident(equivalent_interdependency_tablename)||' CASCADE';
    EXECUTE 'DROP TABLE IF EXISTS '||quote_ident(equivalent_interdependency_edge_tablename)||' CASCADE';
    
    FOR information_schema_record IN EXECUTE 'SELECT * FROM information_schema.views WHERE table_schema = ''public'' AND table_name LIKE ''%'||interdependency_interdependency_view_suffix||'''' LOOP
        --remove the interdependency and edge views
        EXECUTE 'DROP VIEW IF EXISTS'||quote_ident(information_schema_record.table_name)||' CASCADE';
        --remove the view from the geometry columns table
        EXECUTE 'DELETE FROM geometry_columns WHERE f_table_name = '||quote_literal(information_schema_record.table_name);
    END LOOP;
    
RETURN NULL;    
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION ni_delete_int_tables_post_delete_graph() OWNER TO postgres;
