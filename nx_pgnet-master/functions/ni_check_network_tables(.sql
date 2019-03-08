-- Function: ni_check_network_tables(character varying)

-- DROP FUNCTION ni_check_network_tables(character varying);

CREATE OR REPLACE FUNCTION ni_check_network_tables(character varying)
  RETURNS boolean AS
$BODY$ 
DECLARE
    --table prefix used to identify which network tables to check
    table_prefix ALIAS for $1;
    
    --to store derived table names
    node_table_name varchar := '';
    edge_table_name varchar := '';
    edge_geometry_table_name varchar := '';
    
    --to store existence of network tables
    node_table_exists boolean := FALSE;
    edge_table_exists boolean := FALSE;
    edge_geometry_table_exists boolean := FALSE;
    
    --constant suffixes used on different network tables
    edge_geometry_table_suffix varchar := '_Edge_Geometry';
    edge_table_suffix varchar := '_Edges';
    node_table_suffix varchar := '_Nodes';
    
    --count of graph records matching given node, edge and edge_geometry table names
    graph_record_exists integer := 0;
    
BEGIN
    
    --create appropriate tables names
    node_table_name := table_prefix||node_table_suffix;
    edge_table_name := table_prefix||edge_table_suffix;
    edge_geometry_table_name := table_prefix||edge_geometry_table_suffix;
    
    --check if node tables exists    
    EXECUTE 'SELECT EXISTS (SELECT * FROM information_schema.tables WHERE table_name = '||quote_literal(node_table_name)||')' INTO node_table_exists;
    
    IF node_table_exists IS FALSE THEN
        RETURN FALSE;
    END IF;
    
    --check if edge table exists    
    EXECUTE 'SELECT EXISTS (SELECT * FROM information_schema.tables WHERE table_name = '||quote_literal(edge_table_name)||')' INTO edge_table_exists;
    
    IF edge_table_exists IS FALSE THEN
        RETURN FALSE;
    END IF;
    
    --check if edge_geometry table exists    
    EXECUTE 'SELECT EXISTS (SELECT * FROM information_schema.tables WHERE table_name = '||quote_literal(edge_geometry_table_name)||')' INTO edge_geometry_table_exists;
    
    IF edge_geometry_table_exists IS FALSE THEN
        RETURN FALSE;
    END IF;
        
    RETURN TRUE;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION ni_check_network_tables(character varying) OWNER TO postgres;
