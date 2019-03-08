
CREATE OR REPLACE FUNCTION ni_delete_int_table_post_int_record_delete()
  RETURNS trigger AS
$BODY$
DECLARE 
BEGIN
	--drop interdependency table when Global Interdependency record deleted
    EXECUTE 'DROP TABLE IF EXISTS '||quote_ident(OLD."InterdependencyTableName")||' CASCADE';

RETURN NULL;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION ni_delete_int_table_post_int_record_delete() OWNER TO postgres;
