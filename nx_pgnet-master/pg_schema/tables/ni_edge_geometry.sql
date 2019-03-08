
CREATE TABLE "Edge_Geometry"
(
  geom geometry NOT NULL
  --CONSTRAINT enforce_dims_geom CHECK (st_ndims(geom) = 2),
  --CONSTRAINT enforce_geotype_geom CHECK (geometrytype(geom) = 'LINESTRING'::text OR geom IS NULL)
)
WITH (
  OIDS=FALSE
);
ALTER TABLE "Edge_Geometry" OWNER TO postgres;
COMMENT ON TABLE "Edge_Geometry" IS 'If we want to have a giant Edges_Geometry table for ALL geometry across ALL loaded networks, then we would need to have a foreign key reference to the Graphs table to identify which graph the geometry belongs to. Currently, the schema will lead to individual edge geometry tables per network loaded';