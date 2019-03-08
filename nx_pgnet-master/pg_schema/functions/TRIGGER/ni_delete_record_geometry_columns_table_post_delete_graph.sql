
CREATE OR REPLACE FUNCTION ni_delete_record_geometry_columns_table_post_delete_graph()
  RETURNS trigger AS
$BODY$
DECLARE

    --constant geometry columns table name
    geometry_columns_table_name varchar := 'geometry_columns';
	
	--stores the position of _Edges in old edge table name
    pos integer := 0;
	
	--stores the base table name i.e. network name	
    base_table_name varchar := '';
	
	--default edge geometry table suffix
    edge_geometry_suffix varchar := '_Edge_Geometry';
	
	--to store old node, edge and edge_geometry table names
    old_node_table_name varchar := '';
    old_edge_table_name varchar := '';
    old_edge_geometry_table_name varchar := '';    
    
BEGIN

    --determining the names of the tables just removed when the Graphs record was deleted
    old_node_table_name := OLD."Nodes";
    old_edge_table_name := OLD."Edges";
    
    --to determine prefix
    pos := position('_Edges' in old_edge_table_name);
    base_table_name := substring(old_edge_table_name FROM 0 FOR pos);

    --equivalent edge geometry table name
    old_edge_geometry_table_name := base_table_name||edge_geometry_suffix;
    
    --remove the nodes and edge_geometry references from the geometry_columns table
    EXECUTE 'DELETE FROM geometry_columns WHERE f_table_name = '||quote_literal(old_node_table_name);
    EXECUTE 'DELETE FROM geometry_columns WHERE f_table_name = '||quote_literal(old_edge_geometry_table_name);
    
RETURN NULL;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION ni_delete_record_geometry_columns_table_post_delete_graph() OWNER TO postgres;
