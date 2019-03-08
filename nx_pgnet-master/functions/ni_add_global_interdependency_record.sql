-- Function: ni_add_global_interdependency_record(integer, integer, character varying, character varying)

-- DROP FUNCTION ni_add_global_interdependency_record(integer, integer, character varying, character varying);

CREATE OR REPLACE FUNCTION ni_add_global_interdependency_record(integer, integer, character varying, character varying)
  RETURNS void AS
$BODY$ 
DECLARE
	
	--id of graph from Graphs table for from graph
	interdependency_from_graph_id ALIAS for $1;
	
	--id of graph from Graphs table for to graph
	interdependency_to_graph_id ALIAS for $2;
	
	--name of table representing interdependencies between interdependency_from_graph_id and interdependency_to_graph_id
	interdependency_table_name ALIAS for $3;
	
	--name of table storing geometry representing interdependencies between interdependency_from_graph_id and interdependency_to_graph_id
	interdependency_edge_table_name ALIAS for $4;
	
BEGIN

	--insert into the global interdependency table
	EXECUTE 'INSERT INTO "Global_Interdependency" ("InterdependencyFromGraphID", "InterdependencyToGraphID", "InterdependencyTableName", "InterdependencyEdgeTableName") VALUES ('||interdependency_from_graph_id||','||interdependency_to_graph_id||','||quote_literal(interdependency_table_name)||','||quote_literal(interdependency_edge_table_name)||')';
	RETURN;

END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION ni_add_global_interdependency_record(integer, integer, character varying, character varying) OWNER TO postgres;
