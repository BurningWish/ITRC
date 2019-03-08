
CREATE OR REPLACE FUNCTION ni_node_attribute_equality_check(character varying, character varying, node_value anyelement)
RETURNS integer AS
$BODY$ 
DECLARE

    --table prefix used to identify which node tables to check
    table_prefix ALIAS for $1;    
    
    --key/column/attribute to check
    node_key ALIAS for $2;
	
	--node_value - could feasibly be any type
    
    --geometry ID of matched node_geometry record (do we need this to be a value only we know e.g. -1)
    matched_node_id integer := -1;

    --node geometry table name derived from table_prefix and node_table_suffix
    node_table_name varchar := '';
    --constant suffixes used on different network tables
    node_table_suffix varchar := '_Nodes';

BEGIN
		
    --create node table name
    node_table_name := table_prefix||node_table_suffix;
    
	EXECUTE 'SELECT node_table."NodeID" FROM '||quote_ident(node_table_name)||' AS node_table WHERE node_table.'||quote_ident(node_key)||' = '||quote_literal(node_value) INTO matched_node_id;
	
	--return matched node id
    RETURN matched_node_id;
    
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION ni_node_attribute_equality_check(character varying, character varying, node_value anyelement) OWNER TO postgres;