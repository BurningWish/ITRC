-- Function: ni_create_interdependency_tables(character varying, character varying)

-- DROP FUNCTION ni_create_interdependency_tables(character varying, character varying);

CREATE OR REPLACE FUNCTION ni_create_interdependency_tables(character varying, character varying)
  RETURNS boolean AS
$BODY$ 
DECLARE
    --network prefixes
    network_1_table_prefix ALIAS for $1;
    network_2_table_prefix ALIAS for $2;
    
    --to store existence of relevant parts of a valid graph i.e. Nodes, Edges and Edge_Geometry table
    network_1_exists boolean := FALSE;
    network_2_exists boolean := FALSE;
    
    --default parent interdependency table names
    interdependency_table_name varchar := 'Interdependency';
    interdependency_edge_table_name varchar := 'Interdependency_Edges';
    
    --new interdependency tables to create (based on the supplied prefixes for the two networks that are 'interdependent'
    new_interdependency_table_name varchar := '';
    new_interdependency_edge_table_name varchar := '';
    
    --equivalent graph ids of respective networks
    network_1_graph_id integer := 0;
    network_2_graph_id integer := 0;
    
    --table name storing all interdependencies created
    global_interdependency_table_name varchar := 'Global_Interdependency';
    
    --network node table names
    network_1_node_table_name varchar := '';
    network_2_node_table_name varchar := '';
    
    --network edge table names
    network_1_edge_table_name varchar := '';
    network_2_edge_table_name varchar := '';
    
    --network graph ids
    network_1_graphid integer := 0;
    network_2_graphid integer := 0;
    
BEGIN
    
    --create the new table names based on the supplied table prefixes and the constant suffixes
    new_interdependency_table_name := network_1_table_prefix||'_'||network_2_table_prefix||'_'||interdependency_table_name;
    new_interdependency_edge_table_name := network_1_table_prefix||'_'||network_2_table_prefix||'_'||interdependency_edge_table_name;

    --check the network is created correctly
    EXECUTE 'SELECT * FROM ni_check_network_tables('||quote_literal(network_1_table_prefix)||')' INTO network_1_exists;
    EXECUTE 'SELECT * FROM ni_check_network_tables('||quote_literal(network_2_table_prefix)||')' INTO network_2_exists;
    
    --determine the equivalent GraphID values for the supplied networks
    EXECUTE 'SELECT "GraphID" FROM "Graphs" WHERE "GraphName" = '||quote_literal(network_1_table_prefix) INTO network_1_graph_id;
    EXECUTE 'SELECT "GraphID" FROM "Graphs" WHERE "GraphName" = '||quote_literal(network_2_table_prefix) INTO network_2_graph_id;
    
    --check that the networks have been created correctly.
    IF network_1_exists IS FALSE OR network_2_exists IS FALSE THEN
        RETURN FALSE;
    ELSE
    
        --retrieve the equivalent node table name for network 1
        EXECUTE 'SELECT "Nodes" FROM "Graphs" WHERE "GraphName" = '||quote_literal(network_1_table_prefix) INTO network_1_node_table_name;
        --retrieve the equivalent node table name for network 2
        EXECUTE 'SELECT "Nodes" FROM "Graphs" WHERE "GraphName" = '||quote_literal(network_2_table_prefix) INTO network_2_node_table_name;
        
        --retrieve the equivalent edge table name for network 1
        EXECUTE 'SELECT "Edges" FROM "Graphs" WHERE "GraphName" = '||quote_literal(network_1_table_prefix) INTO network_1_edge_table_name;
        --retrieve the equivalent edge table name for network 2
        EXECUTE 'SELECT "Edges" FROM "Graphs" WHERE "GraphName" = '||quote_literal(network_2_table_prefix) INTO network_2_edge_table_name;
        
        --retrieve the equivalent graph id for network 1
        EXECUTE 'SELECT "GraphID" FROM "Graphs" WHERE "GraphName" = '||quote_literal(network_1_table_prefix) INTO network_1_graphid;
        --retrieve the equivalent graph id for network 2
        EXECUTE 'SELECT "GraphID" FROM "Graphs" WHERE "GraphName" = '||quote_literal(network_2_table_prefix) INTO network_2_graphid;
        
        --Interdependency Table
        --create a child 'interdependency' table by inheriting from "Interdependency"
        EXECUTE 'CREATE TABLE '||quote_ident(new_interdependency_table_name)||'() INHERITS ('||quote_ident(interdependency_table_name)||')';
        
        --add the InterdependencyID column as a bigserial to the interdependency table
        EXECUTE 'ALTER TABLE '||quote_ident(new_interdependency_table_name)||' ADD COLUMN "InterdependencyID" bigserial ';
        --set the InterdependencyID column as the primary key for the interdependency table
        EXECUTE 'ALTER TABLE '||quote_ident(new_interdependency_table_name)||' ADD CONSTRAINT '||new_interdependency_table_name||'_prkey PRIMARY KEY ("InterdependencyID")';
        
        --Interdependency_Edge Table        
        --create a child 'interdependency_edge' table by inheriting from "Interdependency_Edge"
        EXECUTE 'CREATE TABLE '||quote_ident(new_interdependency_edge_table_name)||'() INHERITS ('||quote_ident(interdependency_edge_table_name)||')';
        
        --add the GeomID column as bigserial to the interdependency_edge table
        EXECUTE 'ALTER TABLE '||quote_ident(new_interdependency_edge_table_name)||' ADD COLUMN "GeomID" bigserial ';
        --set the GeomID column of the interdependency_edge table to be a primary key
        EXECUTE 'ALTER TABLE '||quote_ident(new_interdependency_edge_table_name)||' ADD CONSTRAINT '||new_interdependency_edge_table_name||'_prkey PRIMARY KEY ("GeomID")';       
        
        --FOREIGN KEYS
        --add a foreign key relationship to GraphID on Graph table for FROM
        EXECUTE 'ALTER TABLE '||quote_ident(new_interdependency_table_name)||' ADD CONSTRAINT "'||new_interdependency_table_name||'_Interdependency_Graphs_F_GraphID_frkey" FOREIGN KEY ("Interdependency_Graphs_F_GraphID") REFERENCES "Graphs" ("GraphID") MATCH SIMPLE ON UPDATE NO ACTION ON DELETE NO ACTION';
        
        --add a foreign key relationship to GraphID on Graph table for TO
        EXECUTE 'ALTER TABLE '||quote_ident(new_interdependency_table_name)||' ADD CONSTRAINT "'||new_interdependency_table_name||'_Interdependency_Graphs_T_GraphID_frkey" FOREIGN KEY ("Interdependency_Graphs_T_GraphID") REFERENCES "Graphs" ("GraphID") MATCH SIMPLE ON UPDATE NO ACTION ON DELETE NO ACTION';
        
        --add a foreign key relationship to equivalent node tables (network 1 = from, network 2 = to)
        --network 1 from 
        EXECUTE 'ALTER TABLE '||quote_ident(new_interdependency_table_name)||' ADD CONSTRAINT "'||new_interdependency_table_name||'_Interdependency_Nodes_F_NodeID_frkey" FOREIGN KEY ("Interdependency_Nodes_F_NodeID") REFERENCES '||quote_ident(network_1_node_table_name)||' ("NodeID") MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION';
        
        --network 2 to
        EXECUTE 'ALTER TABLE '||quote_ident(new_interdependency_table_name)||' ADD CONSTRAINT "'||new_interdependency_table_name||'_Interdependency_Nodes_T_NodeID_frkey" FOREIGN KEY ("Interdependency_Nodes_T_NodeID") REFERENCES '||quote_ident(network_2_node_table_name)||' ("NodeID") MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION';
        
        --add a foreign key relationship to GeomID of equivalent Interdependency_Edge table
        EXECUTE 'ALTER TABLE '||quote_ident(new_interdependency_table_name)||' ADD CONSTRAINT "'||new_interdependency_table_name||'_Interdependency_Interdependency_Edges_GeomID_frkey" FOREIGN KEY ("GeomID") REFERENCES '||quote_ident(new_interdependency_edge_table_name)||' MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE CASCADE';
        
        --Global Interdependency Table
        --insert a new record in to the Global_Interdependency table        
		EXECUTE 'SELECT * FROM ni_add_global_interdependency_record ('||network_1_graph_id||', '||network_2_graph_id||', '||quote_literal(new_interdependency_table_name)||', '||quote_literal(new_interdependency_edge_table_name)||')';
        RETURN TRUE;
    END IF;
    RETURN FALSE;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION ni_create_interdependency_tables(character varying, character varying) OWNER TO postgres;
