
CREATE OR REPLACE FUNCTION ni_create_network_table_edges(character varying)
  RETURNS boolean AS
$BODY$ 
DECLARE
    
    --supplied table prefix e.g. Electricity
    table_prefix ALIAS for $1;
	
	--constant edge table suffix
    edge_table_suffix varchar := '_Edges';
    
    --base edge table to inherit from
    inherit_edge_table_name varchar := 'Edges';
    
    --new edge table name to create
    new_edge_table_name varchar := '';
    
    --equivalent edge geometry table name, that will be "paired" with the edge table created as a result of running this function
    equivalent_edge_geometry_table_name varchar := '';
    
    --constant edge_geometry table suffix
    equivalent_edge_geometry_table_suffix varchar := '_Edge_Geometry';
    
    --equivalent node table name, that will be referenced by the Node_F_ID and Node_T_ID attributes of the edge table created as a result of running this function
    equivalent_node_table_name varchar := '';
    
    --constant node table suffix
    equivalent_node_table_suffix varchar := '_Nodes';
    
    --these checks attempt to ensure that the equivalent edge_geometry and node tables already exist prior to creating the edge table
    --boolean to store check if edge table of supplied name already exists
    edge_table_exists boolean := FALSE;
    
    --boolean to store check if an edge_geometry table "paired" with "this" edge table already exists
    edge_geometry_table_exists boolean := FALSE;
    
    --boolean to store check if the node table "paired" with "this" edge table already exists
    node_table_exists boolean := FALSE;
BEGIN

    --generate appropriate table names for edge, edge_geometry and node tables
    new_edge_table_name := table_prefix||edge_table_suffix;
    equivalent_edge_geometry_table_name := table_prefix||equivalent_edge_geometry_table_suffix;
    equivalent_node_table_name := table_prefix||equivalent_node_table_suffix;
    
    --check if the nodes table exists
    EXECUTE 'SELECT EXISTS (SELECT * FROM information_schema.tables WHERE table_name = '||quote_literal(equivalent_node_table_name)||')' INTO node_table_exists;
    
    IF node_table_exists IS FALSE THEN
        --if the equivalent nodes table does not exist, return FALSE, because the foreign key constraints implemented on the nodes table will fail    
        RETURN FALSE;
    END IF;
    
    --check if the edge_geometry table exists
    EXECUTE 'SELECT EXISTS (SELECT * FROM information_schema.tables WHERE table_name = '||quote_literal(equivalent_edge_geometry_table_name)||')' INTO edge_geometry_table_exists;
    
    IF edge_geometry_table_exists IS FALSE THEN
        --if the equivalent edge_geometry table does not exist, return FALSE because the foreign key constraints implemented on the edge table will fail
        RETURN FALSE;
    END IF;
    
    --check if an edges table of the same name has already been created
    EXECUTE 'SELECT EXISTS (SELECT * FROM information_schema.tables WHERE table_name = '||quote_literal(new_edge_table_name)||')' INTO edge_table_exists;
    
    IF edge_table_exists IS TRUE THEN
        --if a table of <table_prefix>_Edges already exists in the database, return FALSE
        RETURN FALSE;
    ELSE
        
        --create the edge table based on the provided table suffix (arg1) and the constant edge_table_suffix, by inheriting from the base edges table (inherit_edge_table_name)      
        EXECUTE 'CREATE TABLE '||quote_ident(new_edge_table_name)||'() INHERITS ('||quote_ident(inherit_edge_table_name)||')';
        
        --to ensure that a new sequence exists for each new edge table
        EXECUTE 'ALTER TABLE '||quote_ident(new_edge_table_name)||' ADD COLUMN "EdgeID" bigserial';
        
        --to ensure that the new sequence is used as the primary key
        EXECUTE 'ALTER TABLE '||quote_ident(new_edge_table_name)||' ADD CONSTRAINT '||new_edge_table_name||'_prkey PRIMARY KEY ("EdgeID")';
        
        RETURN TRUE;
    END IF;
   
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION ni_create_network_table_edges(character varying) OWNER TO postgres;
