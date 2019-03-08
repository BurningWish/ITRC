-- Function: ni_graph_to_gephi_edge_list(character varying, character varying, character varying, character varying, character varying, character varying)

-- DROP FUNCTION ni_graph_to_gephi_edge_list(character varying, character varying, character varying, character varying, character varying, character varying);

CREATE OR REPLACE FUNCTION ni_graph_to_gephi_edge_list(character varying, character varying, character varying, character varying, character varying, character varying)
  RETURNS character varying AS
$BODY$
DECLARE
	
	--path includes filename (.csv)
	output_path ALIAS for $1;
	
	--name of node view
	node_viewname ALIAS for $2;
	
	--name of edge view
	edge_viewname ALIAS for $3;
	
	--name of node geometry column e.g. geom
	node_geometry_column_name ALIAS for $4;
	
	--name of edge geometry column e.g. geom
	edge_geometry_column_name ALIAS for $5;
	
	--edge type e.g. either 'Undirected' or 'Directed'
	edge_type ALIAS for $6;

BEGIN
	
	--export the edges
	EXECUTE 'COPY (SELECT edge_table.*, ST_AsText(edge_table.'||quote_ident(edge_geometry_column_name)||') as geometry_text, ST_SRID(edge_table.'||quote_ident(edge_geometry_column_name)||') as srid, "Node_F_ID" as "Source", "Node_T_ID" as "Target", '||quote_literal(edge_type)||' AS "Type", ST_X(ST_Transform(ST_StartPoint(edge_table.'||quote_ident(edge_geometry_column_name)||'), 900913)) as google_startpoint_x, ST_Y(ST_Transform(ST_StartPoint(edge_table.'||quote_ident(edge_geometry_column_name)||'), 900913) as google_startpoint_y, ST_X(ST_Transform(ST_EndPoint(edge_table.'||quote_ident(edge_geometry_column_name)||'), 900913)) as google_endpoint_x, ST_Y(ST_Transform(ST_EndPoint(edge_table.'||quote_ident(edge_geometry_column_name)||'), 900913)) as google_endpoint_y, ST_X(ST_Transform(ST_StartPoint(edge_table.'||quote_ident(edge_geometry_column_name)||'), 4326)) as wgs84_startpoint_x, ST_Y(ST_Transform(ST_StartPoint(edge_table.'||quote_ident(edge_geometry_column_name)||'), 4326)) as wgs84_startpoint_y, ST_X(ST_Transform(ST_EndPoint(edge_table.'||quote_ident(edge_geometry_column_name)||'), 4326)) as wgs84_endpoint_x, ST_Y(ST_Transform(ST_EndPoint(edge_table.'||quote_ident(edge_geometry_column_name)||'), 4326)) FROM '||quote_ident(edge_viewname)|| ' AS edge_table) TO '||quote_literal(output_path)||' DELIMITER AS \',\' CSV HEADER';

	--export the nodes
	EXECUTE 'COPY (SELECT node_table.*, ST_AsText(node_table.'||quote_ident(node_geometry_column_name)||') as geometry_text, ST_SRID(node_table.'||quote_ident(node_geometry_column_name)||') as srid, ST_X(ST_AsText(ST_Transform(node_table.'||quote(node_geometry_column_name)||', 900913))) as google_node_x, ST_Y(ST_AsText(ST_Transform(node_table.'||quote_ident(node_geometry_column_name)||', 900913))) as google_node_y, ST_X(ST_AsText(ST_Transform(node_table.'||quote_ident(node_geometry_column_name)||', 4326))) as wgs84_node_x, ST_Y(ST_AsText(ST_Transform(node_table.'||quote_ident(node_geometry_column_name)||', 4326))) as wgs84_node_y FROM '||quote_ident(node_viewname)||' AS node_table) TO '||quote_literal(output_path)||' DELIMITER AS \',\' CSV HEADER';
	
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION ni_graph_to_gephi_edge_list(character varying, character varying, character varying, character varying, character varying, character varying) OWNER TO postgres;
