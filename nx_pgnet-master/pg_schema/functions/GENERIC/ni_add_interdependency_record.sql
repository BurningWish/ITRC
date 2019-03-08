
CREATE OR REPLACE FUNCTION ni_add_interdependency_record(character varying, integer, integer, integer, integer, integer)
  RETURNS void AS
$BODY$ 
DECLARE
	
	--prefix of interdependency table to add record to
	table_prefix ALIAS for $1;
	
	--graph id of from graph
	interdependency_graph_from_graphid ALIAS for $2;
	
	--graph id of to graph
	interdependency_graph_to_graphid ALIAS for $3;
	
	--node id of from node
	interdependency_nodes_from_nodeid ALIAS for $4;
	
	--node id of to node
	interdependency_nodes_to_nodeid ALIAS for $5;
	
	--geometry id of geometry representing edge
	geomid ALIAS for $6;
	
	--default parent interdependency table names
    interdependency_table_name varchar := '_Interdependency';

	--to store the full name of the instance of the interdependency table (to which we are adding a record here)
	full_interdependency_table_name varchar := '';
BEGIN
	
	--full name of interdependency table to add record to
	full_interdependency_table_name := table_prefix||interdependency_table_name;

	--insert into the instance interdependency table
	EXECUTE 'INSERT INTO '||quote_ident(full_interdependency_table_name)||' ("Interdependency_Graphs_F_GraphID", "Interdependency_Graphs_T_GraphID", "Interdependency_Nodes_F_NodeID", "Interdependency_Nodes_T_NodeID") VALUES ('||interdependency_graph_from_graphid||','||interdependency_graph_to_graphid||','||interdependency_nodes_from_nodeid||','||interdependency_nodes_to_nodeid||', '||geomid||')';
	RETURN;

END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION ni_add_interdependency_record(character varying, integer, integer, integer, integer, integer) OWNER TO postgres;
