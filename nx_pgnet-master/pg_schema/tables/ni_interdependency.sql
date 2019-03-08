
CREATE TABLE "Interdependency"
(
  "Interdependency_Graphs_F_GraphID" integer NOT NULL,
  "Interdependency_Graphs_T_GraphID" integer NOT NULL,
  "Interdependency_Nodes_F_NodeID" integer NOT NULL,
  "Interdependency_Nodes_T_NodeID" integer NOT NULL,
  "GeomID" integer NOT NULL,
  CONSTRAINT "Interdependency_Graphs_F_GraphID_frkey" FOREIGN KEY ("Interdependency_Graphs_F_GraphID")
      REFERENCES "Graphs" ("GraphID") MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT "Interdependency_Graphs_T_GraphID_frkey" FOREIGN KEY ("Interdependency_Graphs_T_GraphID")
      REFERENCES "Graphs" ("GraphID") MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION
)
WITH (
  OIDS=FALSE
);
ALTER TABLE "Interdependency" OWNER TO postgres;