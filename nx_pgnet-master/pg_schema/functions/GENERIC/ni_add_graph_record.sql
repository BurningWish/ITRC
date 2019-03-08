
CREATE OR REPLACE FUNCTION ni_add_graph_record(character varying, boolean, boolean)
  RETURNS void AS
$BODY$ 
DECLARE
    
    --table prefix to identify a particular graph/network
    table_prefix ALIAS for $1;
    
    --denotes if the network is directed (true if directed)    
    directed ALIAS for $2;
    
    --denotes if the network is a multigraph (true if directed)d
    multigraph ALIAS for $3;
    
    --constant table suffixes 
    node_table_suffix varchar := '_Nodes';
    edge_table_suffix varchar := '_Edges';
	
	--to store node and edge table names
	node_table_name varchar := '';
	edge_table_name varchar := '';
	
BEGIN
	
	--setting node and edge table names
	node_table_name := table_prefix||node_table_suffix;
	edge_table_name := table_prefix||edge_table_suffix;

    --add the new network/graph record to the Graphs table
    EXECUTE 'INSERT INTO "Graphs" ("GraphName", "Nodes", "Edges", "Directed", "MultiGraph") VALUES ('||quote_literal(table_prefix)||', '||quote_literal(node_table_name)||', '||quote_literal(edge_table_name)||', '||directed||', '||multigraph||')';
    RETURN;
    
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION ni_add_graph_record(character varying, boolean, boolean) OWNER TO postgres;
