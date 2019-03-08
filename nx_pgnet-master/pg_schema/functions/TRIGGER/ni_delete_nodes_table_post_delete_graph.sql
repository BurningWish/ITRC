
CREATE OR REPLACE FUNCTION ni_delete_nodes_table_post_delete_graph()
  RETURNS trigger AS
$BODY$
DECLARE 
BEGIN
	--delete node table when graph record deleted
	EXECUTE 'DROP TABLE IF EXISTS '||quote_ident(OLD."Nodes")|| 'CASCADE';
RETURN NULL;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION ni_delete_nodes_table_post_delete_graph() OWNER TO postgres;
