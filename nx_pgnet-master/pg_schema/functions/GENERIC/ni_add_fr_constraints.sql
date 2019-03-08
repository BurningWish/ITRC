
CREATE OR REPLACE FUNCTION ni_add_fr_constraints(character varying)
  RETURNS boolean AS
$BODY$ 
DECLARE
    
    --table prefix to identify particular network
    table_prefix ALIAS for $1;
    node_table_name varchar := '';
    edge_table_name varchar := '';
    edge_geometry_table_name varchar := '';
    
    --constant network interdependency table suffixes
    node_table_suffix varchar := '_Nodes';
    edge_table_suffix varchar := '_Edges';
    edge_geometry_table_suffix varchar := '_Edge_Geometry';
    
BEGIN
    
    --creates the appropriate table names based on the supplied prefix, and constant suffixes. 
    node_table_name := table_prefix||node_table_suffix;
    edge_table_name := table_prefix||edge_table_suffix;
    edge_geometry_table_name := table_prefix||edge_geometry_table_suffix;
    
    --NODES
    --add the foreign key constraint matching this new Node table to the correct record in the 'global' Graphs table    
    EXECUTE 'ALTER TABLE '||quote_ident(node_table_name)||' ADD CONSTRAINT '||node_table_name||'_Graphs_GraphID_frkey FOREIGN KEY ("GraphID") REFERENCES "Graphs" ("GraphID") MATCH SIMPLE ON UPDATE NO ACTION ON DELETE NO ACTION';
    
    --EDGES table foreign keys to nodes table
    --add foreign key Edges_Nodes_Node_F_ID_frkey    
    EXECUTE 'ALTER TABLE '||quote_ident(edge_table_name)||' ADD CONSTRAINT "'||edge_table_name||'_Edges_Nodes_Node_F_ID_frkey" FOREIGN KEY  ("Node_F_ID") REFERENCES '||quote_ident(node_table_name)||' ("NodeID") MATCH SIMPLE ON UPDATE NO ACTION ON DELETE NO ACTION';
    
    --add foreign key Edges_Nodes_Node_T_ID_frkey    
    EXECUTE 'ALTER TABLE '||quote_ident(edge_table_name)||' ADD CONSTRAINT "'||edge_table_name||'_Edges_Nodes_Node_T_ID_frkey" FOREIGN KEY ("Node_T_ID") REFERENCES '||quote_ident(node_table_name)||' ("NodeID") MATCH SIMPLE ON UPDATE NO ACTION ON DELETE NO ACTION';
    
    --edges table foreign keys to edge_geometry table
    EXECUTE 'ALTER TABLE '||quote_ident(edge_table_name)||' ADD CONSTRAINT "'||edge_table_name||'_Edges_Edge_Geometry_GeomID_frkey" FOREIGN KEY ("Edge_GeomID") REFERENCES '||quote_ident(edge_geometry_table_name)||' ("GeomID") MATCH SIMPLE ON UPDATE NO ACTION ON DELETE CASCADE';
    
    --foreign key to graphs (graphid) - Edges_Graph_GraphID_frkey - graphs table will ALWAYS exist    
    EXECUTE 'ALTER TABLE '||quote_ident(edge_table_name)||' ADD CONSTRAINT '||edge_table_name||'_Graph_GraphID_frkey FOREIGN KEY ("GraphID") REFERENCES "Graphs" ("GraphID") MATCH SIMPLE ON UPDATE NO ACTION ON DELETE NO ACTION';
    
RETURN TRUE;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION ni_add_fr_constraints(character varying) OWNER TO postgres;
