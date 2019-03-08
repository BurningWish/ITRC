
CREATE TABLE "Interdependency_Edges"
(
  geom geometry NOT NULL
  --CONSTRAINT enforce_dims_geom CHECK (st_ndims(geom) = 2),
  --CONSTRAINT enforce_geotype_geom CHECK (geometrytype(geom) = 'LINESTRING'::text OR geom IS NULL),
  --CONSTRAINT enforce_srid_geom CHECK (st_srid(geom) = 27700)
)
WITH (
  OIDS=FALSE
);
ALTER TABLE "Interdependency_Edges" OWNER TO postgres;