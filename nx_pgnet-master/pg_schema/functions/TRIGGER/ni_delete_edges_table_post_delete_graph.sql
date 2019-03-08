CREATE OR REPLACE FUNCTION ni_delete_edges_table_post_delete_graph()
  RETURNS trigger AS
$BODY$
DECLARE 
BEGIN
	--drop Edge table after delete record from Graphs table
	EXECUTE 'DROP TABLE IF EXISTS '||quote_ident(OLD."Edges")|| 'CASCADE';
RETURN NULL;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION ni_delete_edges_table_post_delete_graph() OWNER TO postgres;
