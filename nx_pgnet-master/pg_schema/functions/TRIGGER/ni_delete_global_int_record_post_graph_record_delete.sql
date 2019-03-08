
CREATE OR REPLACE FUNCTION ni_delete_global_int_record_post_graph_record_delete()
  RETURNS trigger AS
$BODY$
DECLARE 
BEGIN
	--delete record from Global Interdependency tables when graph record deleted
    EXECUTE 'DELETE FROM "Global_Interdependency" WHERE "InterdependencyFromGraphID" = '||quote_literal(OLD."GraphID")||' OR "InterdependencyToGraphID" = '||quote_literal(OLD."GraphID");

RETURN NULL;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION ni_delete_global_int_record_post_graph_record_delete() OWNER TO postgres;
