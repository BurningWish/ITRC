
CREATE OR REPLACE FUNCTION ni_get_all_view_column_names(varchar, varchar, varchar, varchar)
    RETURNS varchar AS
$BODY$
DECLARE
     --schema name
    schema_name ALIAS for $1;
    
    --view prefix
    view_prefix ALIAS for $2;
    view_name varchar := '';

    node_view_suffix varchar := '_View_Nodes';
    edge_geometry_view_suffix varchar := '_View_Edges_Edge_Geometry';
	interdependency_edge_view_suffix varchar := '_View_Interdependency_Interdependency_Edges';
        
    --view type (node, edge)
    view_type ALIAS for $3;
    
    --column to exclude name
    exclude_column_name ALIAS for $4;
    
    --to return
    column_string varchar := '';
        
    information_schema RECORD;    
        
BEGIN
    
    IF view_type = 'node' THEN        
        view_name := view_prefix||node_view_suffix;
    ELSIF view_type = 'edge_geometry' THEN        
        view_name := view_prefix||edge_geometry_view_suffix;
	ELSIF view_type = 'interdependency' THEN
		view_name := view_prefix||interdependency_edge_view_suffix;
    END IF;
    
    FOR information_schema IN EXECUTE 'SELECT column_name FROM information_schema.view_column_usage WHERE view_schema = '||quote_literal(schema_name)||' AND view_name = '||quote_literal(view_name)||' AND column_name != '||quote_literal(exclude_column_name) LOOP        
        column_string := column_string||quote_ident(information_schema.column_name)||' as '||quote_ident(information_schema.column_name)||', ';        
    END LOOP;
    
    column_string := rtrim(column_string, ', ');
    
RETURN column_string;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION ni_get_all_view_column_names(varchar, varchar, varchar, varchar) OWNER TO postgres;
    