
CREATE TABLE "Nodes"
(
  "GraphID" integer NOT NULL,
  geom geometry NOT NULL,
  CONSTRAINT "Nodes_Graphs_GraphID_frkey" FOREIGN KEY ("GraphID")
      REFERENCES "Graphs" ("GraphID") MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION
  --CONSTRAINT enforce_dims_geom CHECK (st_ndims(geom) = 2),
  --CONSTRAINT enforce_geotype_geom CHECK (geometrytype(geom) = 'POINT'::text OR geom IS NULL)
)
WITH (
  OIDS=FALSE
);
ALTER TABLE "Nodes" OWNER TO postgres;