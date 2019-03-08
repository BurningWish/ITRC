-- Function: ni_get_all_table_column_names(character varying, character varying, character varying, character varying)

-- DROP FUNCTION ni_get_all_table_column_names(character varying, character varying, character varying, character varying);

CREATE OR REPLACE FUNCTION ni_get_all_table_column_names(character varying, character varying, character varying, character varying)
  RETURNS character varying AS
$BODY$
DECLARE
     --schema name
    schema_name ALIAS for $1;
    
    --table prefix
    table_prefix ALIAS for $2;
    table_name varchar := '';

    node_table_suffix varchar := '_Nodes';
    edge_table_suffix varchar := '_Edges';
    edge_geometry_table_suffix varchar := '_Edge_Geometry';
	interdependency_table_suffix varchar := '_Interdependency_Edges';
    
    --table type (node, edge, edge_geometry)
    table_type ALIAS for $3;
    
    --column to exclude name
    exclude_column_name ALIAS for $4;
    
    --to return
    column_string varchar := '';
        
    information_schema RECORD;    
        
BEGIN
    
    IF table_type = 'node' THEN
        --column_string := '"GraphID", "NodeID", ';
        table_name := table_prefix||node_table_suffix;
    ELSIF table_type = 'edge' THEN
        --column_string := '"Node_F_ID", "Node_T_ID", "GraphID", "Edge_GeomID", "EdgeID", ';
        table_name := table_prefix||edge_table_suffix;
    ELSIF table_type = 'edge_geometry' THEN
        --column_string := '"GeomID", ';
        table_name := table_prefix||edge_geometry_table_suffix;
	ELSIF table_type = 'interdependency' THEN
		table_name := table_prefix||interdependency_table_suffix;
    END IF;
    
    FOR information_schema IN EXECUTE 'SELECT column_name FROM information_schema.columns WHERE table_schema = '||quote_literal(schema_name)||' AND table_name = '||quote_literal(table_name)||' AND column_name != '||quote_literal(exclude_column_name) LOOP        
        column_string := column_string||quote_ident(information_schema.column_name)||' as '||quote_ident(information_schema.column_name)||', ';        
    END LOOP;
    
    column_string := rtrim(column_string, ', ');
    
RETURN column_string;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION ni_get_all_table_column_names(character varying, character varying, character varying, character varying) OWNER TO postgres;
