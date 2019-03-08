-- Function: ni_build_spatial_index(character varying)

-- DROP FUNCTION ni_build_spatial_index(character varying);

CREATE OR REPLACE FUNCTION ni_build_spatial_index(character varying)
  RETURNS void AS
$BODY$ 
DECLARE

	--prefix of tables to build spatial index on
	table_prefix ALIAS for $1;

	spatial_index_suffix varchar := '_geom_gist';
	
	--node table suffix
	node_table_suffix varchar := '_Nodes';
	node_table_name varchar := '';
	node_table_spatial_index_name varchar := '';
	
	--edge_geometry table suffix
	edge_geometry_table_suffix varchar := '_Edge_Geometry';
	edge_geometry_table_name varchar := '';
	edge_geometry_table_spatial_index_name varchar := '';
	
BEGIN
	
	--setting the node table name
	node_table_name := table_prefix||node_table_suffix;
	--setting the node table spatial index name
	node_table_spatial_index_name := node_table_name||spatial_index_suffix;
	
	--setting the edge geometry table name
	edge_geometry_table_name := table_prefix||edge_geometry_table_suffix;
	--settings the edge geometry table spatial index
	edge_geometry_table_spatial_index_name := edge_geometry_table_name||spatial_index_suffix;
	
	--drop the previous node table index
	EXECUTE 'DROP INDEX IF EXISTS '||quote_ident(node_table_spatial_index_name);
	
	--create the spatial index for the node table
	EXECUTE 'CREATE INDEX '||quote_ident(node_table_spatial_index_name)||' ON '||quote_ident(node_table_name)||' USING gist(geom)';
	
	--drop the previous edge geometry table index
	EXECUTE 'DROP INDEX IF EXISTS '||quote_ident(edge_geometry_table_spatial_index_name);
	
	--create the spatial index for the edge geometry table
	EXECUTE 'CREATE INDEX '||quote_ident(edge_geometry_table_spatial_index_name)||' ON '||quote_ident(edge_geometry_table_name)||' USING gist(geom)';
	
	RETURN;
	
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION ni_build_spatial_index(character varying) OWNER TO postgres;
