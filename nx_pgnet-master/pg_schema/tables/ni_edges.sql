
CREATE TABLE "Edges"
(
  "Node_F_ID" integer NOT NULL,
  "Node_T_ID" integer NOT NULL,
  "GraphID" integer NOT NULL,
  "Edge_GeomID" integer NOT NULL, 
  CONSTRAINT "Edges_Graphs_GraphID_frkey" FOREIGN KEY ("GraphID")
      REFERENCES "Graphs" ("GraphID") MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION
)
WITH (
  OIDS=FALSE
);
ALTER TABLE "Edges" OWNER TO postgres;