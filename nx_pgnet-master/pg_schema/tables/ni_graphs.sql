
CREATE TABLE "Graphs"
(
  "GraphID" bigserial NOT NULL, 
  "GraphName" character varying NOT NULL, 
  "Nodes" character varying NOT NULL, 
  "Edges" character varying NOT NULL, 
  "Directed" boolean, 
  "MultiGraph" boolean,
  CONSTRAINT "Graphs_prkey" PRIMARY KEY ("GraphID"),
  CONSTRAINT "Graphs_GraphName_Unique" UNIQUE ("GraphName")
)
WITH (
  OIDS=FALSE
);
ALTER TABLE "Graphs" OWNER TO postgres;
COMMENT ON COLUMN "Graphs"."GraphID" IS 'Unique Sequence representing each network or graph i.e. electricity, water, wastewater, solid waste etc';
COMMENT ON COLUMN "Graphs"."GraphName" IS 'Name of the graph to which graphid refers e.g. electricity';
COMMENT ON COLUMN "Graphs"."Nodes" IS 'Name of the table to contain the nodes of a particular network (related to GraphID and with name GraphName)';
COMMENT ON COLUMN "Graphs"."Edges" IS 'Name of the table to contain the edges of a particular network (related to GraphID and with name GraphName)';
COMMENT ON COLUMN "Graphs"."Directed" IS 'Boolean to indicate if the particular network or graph being defined is directed (true), or undirected (false)';
CREATE TRIGGER ni_check_record_geometry_columns_table_post_graph_edges_update
  AFTER UPDATE OF "Edges"
  ON "Graphs"
  FOR EACH ROW
  EXECUTE PROCEDURE ni_check_record_geometry_columns_table_post_graph_edges_update();
CREATE TRIGGER ni_check_record_geometry_columns_table_post_graph_insert
  AFTER INSERT
  ON "Graphs"
  FOR EACH ROW
  EXECUTE PROCEDURE ni_check_record_geometry_columns_table_post_graph_insert();
CREATE TRIGGER ni_check_record_geometry_columns_table_post_graph_nodes_update
  AFTER UPDATE OF "Nodes"
  ON "Graphs"
  FOR EACH ROW
  EXECUTE PROCEDURE ni_check_record_geometry_columns_table_post_graph_nodes_update();
CREATE TRIGGER ni_delete_edges_geometry_table_post_delete_graph
  AFTER DELETE
  ON "Graphs"
  FOR EACH ROW
  EXECUTE PROCEDURE ni_delete_edges_geometry_table_post_delete_graph();
CREATE TRIGGER ni_delete_edges_table_post_delete_graph
  AFTER DELETE
  ON "Graphs"
  FOR EACH ROW
  EXECUTE PROCEDURE ni_delete_edges_table_post_delete_graph();
CREATE TRIGGER ni_delete_global_int_record_post_graph_record_delete
  AFTER DELETE
  ON "Graphs"
  FOR EACH ROW
  EXECUTE PROCEDURE ni_delete_global_int_record_post_graph_record_delete();
CREATE TRIGGER ni_delete_int_tables_post_delete_graph
  AFTER DELETE
  ON "Graphs"
  FOR EACH ROW
  EXECUTE PROCEDURE ni_delete_int_tables_post_delete_graph();
CREATE TRIGGER ni_delete_nodes_table_post_delete_graph
  AFTER DELETE
  ON "Graphs"
  FOR EACH ROW
  EXECUTE PROCEDURE ni_delete_nodes_table_post_delete_graph();
CREATE TRIGGER ni_delete_record_geometry_columns_table_post_delete_graph
  AFTER DELETE
  ON "Graphs"
  FOR EACH ROW
  EXECUTE PROCEDURE ni_delete_record_geometry_columns_table_post_delete_graph();