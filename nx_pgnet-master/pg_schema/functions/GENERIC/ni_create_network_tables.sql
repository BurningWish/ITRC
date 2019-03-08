
CREATE OR REPLACE FUNCTION ni_create_network_tables(character varying, integer, boolean, boolean)
  RETURNS boolean AS
$BODY$
DECLARE

    --table prefix to assign to nodes, edge and edge_geometry table
    table_prefix ALIAS for $1;
	
    --srid to apply to the nodes and edge_geometry tables (if -1, then assume an aspatial network i.e. empty geometries for all nodes and edges will be supplied)
    srid ALIAS for $2;

    --directed network boolean
    directed ALIAS for $3;
    
    --multigraph network boolean
    multigraph ALIAS for $4;
    
	--check srid result
	check_srid_result boolean := False;
	
    --to store the results of running the individual create network table functions
    create_network_table_nodes_result boolean := FALSE;
    create_network_table_edge_result boolean := FALSE;
    create_network_table_edge_geometry_result boolean := FALSE;
    
BEGIN
    
	--check that the srid exists
	--(-1 denotes an aspatial network is being stored)
	EXECUTE 'SELECT * FROM ni_check_srid('||srid||')' INTO check_srid_result;
	
	IF check_srid_result IS FALSE THEN
		RETURN FALSE;
	END IF;
	
    --create network node table
    EXECUTE 'SELECT * FROM ni_create_network_table_nodes('||quote_literal(table_prefix)||', '||srid||')' INTO create_network_table_nodes_result;
    
    IF create_network_table_nodes_result IS FALSE THEN
        --need to rollback things created by nodes table
        RETURN FALSE;
    END IF;
    
    --create network edge_geometry table
    EXECUTE 'SELECT * FROM ni_create_network_table_edge_geometry('||quote_literal(table_prefix)||', '||srid||')' INTO create_network_table_edge_geometry_result;   
    
    IF create_network_table_edge_geometry_result IS FALSE THEN
        --need to rollback things created by edge_geometry table
        RETURN FALSE;
    END IF;
    
    --create network edges table
    EXECUTE 'SELECT * FROM ni_create_network_table_edges('||quote_literal(table_prefix)||')' INTO create_network_table_edge_result;
    
    IF create_network_table_edge_result IS FALSE THEN
        --need to rollback things created by edges table
        RETURN FALSE;
    END IF;
    
	--add foreign key constraints and a record to the graph table if the Node, Edge and Edge_Geometry tables were successfully created
    IF create_network_table_nodes_result IS TRUE AND create_network_table_edge_geometry_result IS TRUE AND create_network_table_edge_result IS TRUE THEN
        EXECUTE 'SELECT * FROM ni_add_fr_constraints('||quote_literal(table_prefix)||')';
        EXECUTE 'SELECT * FROM ni_add_graph_record('||quote_literal(table_prefix)||', '||directed||', '||multigraph||')';
    END IF;
    
    --return true when all tables successfully created
    RETURN TRUE;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION ni_create_network_tables(character varying, integer, boolean, boolean) OWNER TO postgres;
