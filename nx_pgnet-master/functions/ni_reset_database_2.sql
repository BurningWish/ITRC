-- Function: ni_reset_database()

-- DROP FUNCTION ni_reset_database();

CREATE OR REPLACE FUNCTION ni_reset_database()
  RETURNS void AS
$BODY$
DECLARE

    --for storing records from the information_schema table
    information_schema_record RECORD;

BEGIN

    --drop tables (subsequent sequences will also then be dropped)
    --need to find all tables which will contain the name '_Nodes', '_Edges', '_Edge_Geometry', but not "Graphs", "Global_Interdependency", "geometry_columns", "spatial_ref_sys"
    FOR information_schema_record IN SELECT * FROM information_schema.tables WHERE table_name != 'Nodes' AND table_name != 'Edges' AND table_name != 'Edge_Geometry' AND table_name != 'Graphs' AND table_name != 'Global_Interdependency' AND table_name != 'geometry_columns' AND table_name != 'spatial_ref_sys' LOOP
        RAISE NOTICE 'table_name: %', information_schema_record.table_name;
        --EXECUTE 'DROP TABLE '||quote_ident(information_schema_record.table_name)||' CASCADE';
    END LOOP;
    
    --remove all records from the graph table
    --remove all records from the geometry_columns table    
    DELETE FROM "Graphs";
    DELETE FROM "geometry_columns";
    
    --reset graph sequence
    --reset global interdependency sequence
    ALTER SEQUENCE "Graphs_GraphID_seq" RESTART WITH 1;
    ALTER SEQUENCE "Global_Interdependency_InterdependencyID_seq" RESTART WITH 1;

    
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION ni_reset_database() OWNER TO postgres;
