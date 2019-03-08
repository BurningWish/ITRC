-- Function: ni_get_graph_id_by_prefix(character varying)

-- DROP FUNCTION ni_get_graph_id_by_prefix(character varying);

CREATE OR REPLACE FUNCTION ni_get_graph_id_by_prefix(character varying)
  RETURNS integer AS
$BODY$ 
DECLARE

	--unique table prefix e.g. Electricity
    table_prefix ALIAS for $1;

	--graph id returned from Graphs table
	graph_id integer := -1;
	
BEGIN
	
	--query Graphs table based on supplied table prefix / network name
	EXECUTE 'SELECT "GraphID" FROM "Graphs" WHERE "GraphName" = '||quote_literal(table_prefix) INTO graph_id;

	--return corresponding graph id
	RETURN graph_id;
	
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION ni_get_graph_id_by_prefix(character varying) OWNER TO postgres;
