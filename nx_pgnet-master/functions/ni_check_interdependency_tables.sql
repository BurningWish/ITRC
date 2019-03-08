-- Function: ni_check_interdependency_tables(character varying, character varying)

-- DROP FUNCTION ni_check_interdependency_tables(character varying, character varying);

CREATE OR REPLACE FUNCTION ni_check_interdependency_tables(character varying, character varying)
  RETURNS boolean AS
$BODY$ 
DECLARE
	
	--network 1 name / prefix
    network_1_table_prefix ALIAS for $1;
	
	--network 2 name / prefix
    network_2_table_prefix ALIAS for $2;
    
    --used to create appropriate interdependency table names
    equivalent_interdependency_table_name varchar := '';
    equivalent_interdependency_edge_table_name varchar := '';
    
    --constant suffixes used for interdependency tables
    interdependency_table_suffix varchar := 'Interdependency';
    interdependency_edge_table_suffix varchar := 'Interdependency_Edges';
    
    --to store existence of necessary interdependency tables
    interdependency_table_exists boolean := FALSE;
    interdependency_edge_table_exists boolean := FALSE;
    
BEGIN
    
    --create appropriate interdependency table names
    equivalent_interdependency_table_name := network_1_table_prefix||'_'||network_2_table_prefix||'_'||interdependency_table_suffix;
    equivalent_interdependency_edge_table_name := network_1_table_prefix||'_'||network_2_table_prefix||'_'||interdependency_edge_table_suffix;
    
    --check if interdependency table exists
    EXECUTE 'SELECT EXISTS (SELECT * FROM information_schema.tables WHERE table_name = '||quote_literal(equivalent_interdependency_table_name)||')' INTO interdependency_table_exists;
    
    --check if interdependency edge table exists
    EXECUTE 'SELECT EXISTS (SELECT * FROM information_schema.tables WHERE table_name = '||quote_literal(equivalent_interdependency_edge_table_name)||')' INTO interdependency_edge_table_exists;
    
	--return false if interdependency table does not exist
    IF interdependency_table_exists IS FALSE THEN
        RETURN FALSE;
    END IF;
    
	--return false if interdependency_edge table does not exist
    IF interdependency_edge_table_exists IS FALSE THEN
        RETURN FALSE;
    END IF;
    
    RETURN TRUE;    
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION ni_check_interdependency_tables(character varying, character varying) OWNER TO postgres;
