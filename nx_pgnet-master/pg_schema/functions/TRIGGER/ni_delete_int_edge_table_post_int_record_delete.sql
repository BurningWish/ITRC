
CREATE OR REPLACE FUNCTION ni_delete_int_edge_table_post_int_record_delete()
  RETURNS trigger AS
$BODY$
DECLARE 
BEGIN
	--drop interdependency edge table when record from Global Interdependency table deleted
    EXECUTE 'DROP TABLE IF EXISTS '||quote_ident(OLD."InterdependencyEdgeTableName")||' CASCADE';

RETURN NULL;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION ni_delete_int_edge_table_post_int_record_delete() OWNER TO postgres;
