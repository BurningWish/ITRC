
CREATE OR REPLACE FUNCTION ni_delete_edges_geometry_table_post_delete_graph()
  RETURNS trigger AS
$BODY$
DECLARE 
	
	--stores position of _Edges suffix in edge table name
    pos integer := 0;
	
	--will store the base table name for the edge geometry table
    base_table_name varchar := '';
	
	--default edge geometry table suffix
    edge_geometry_suffix varchar := '_Edge_Geometry';
	
	--will store the edge geometry table name, derived from base table name and edge geometry suffix
	equivalent_edge_geometry_tablename varchar := '';
	
BEGIN

	--store position of _Edges suffix in edge table name
    pos := position('_Edges' in OLD."Edges");
	
	--stores the equivalent base table name i.e. the name given by the user on creation
    base_table_name := substring(OLD."Nodes" FROM 0 FOR pos);
	
	--stores the equivalent edge_geometry table, derived from the edge table name
    equivalent_edge_geometry_tablename := base_table_name||edge_geometry_suffix;
        
	--drops the edge_geometry table 
	EXECUTE 'DROP TABLE IF EXISTS '||quote_ident(equivalent_edge_geometry_tablename)|| 'CASCADE';
    
RETURN NULL;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION ni_delete_edges_geometry_table_post_delete_graph() OWNER TO postgres;
