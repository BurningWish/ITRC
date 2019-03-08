-- Function: ni_graph_to_csv(character varying, character varying, character varying, character varying)

-- DROP FUNCTION ni_graph_to_csv(character varying, character varying, character varying, character varying);

CREATE OR REPLACE FUNCTION ni_graph_to_csv(character varying, character varying, character varying, character varying)
  RETURNS void AS
$BODY$ 
DECLARE
    --name of the graph to output to csv
    graph_name ALIAS for $1;
    
    --default geometry column name
    default_geometry_column_name ALIAS for $2;
    
	--default schema name
	default_schema char(6) := 'public';
	
    --prefix for all files generated
    output_file_prefix ALIAS for $3;    
    --e.g. prefix_Graph_Record
    --e.g. prefix_Nodes
    --e.g. prefix_Edges
    --e.g. prefix_Edge_Geometry
    
    --output path for generated .csv files
    output_path ALIAS for $4;
    
    --variables to hold paths and file names to resultant csv outputs
    graph_record_csv_file_path_and_name text := '';
    global_interdependency_record_csv_file_path_and_name text := '';
    node_record_csv_file_path_and_name text := '';
    edge_record_csv_file_path_and_name text := '';
    edge_geometry_csv_file_path_and_name text := '';
    interdependency_record_csv_file_path_and_name text := '';
    interdependency_edge_record_csv_file_path_and_name text := '';
    
    --the structure of Graphs and Global_Interdependency ALWAYS remains the same, as they are overraching control tables, rather than being network specific.
    --used to hold outputs when selecting from Graphs table
    graph "Graphs"%ROWTYPE;
    
    --used to hold outputs when selecting from Global_Interdependency table
    global_interdependency "Global_Interdependency"%ROWTYPE;
    global_interdependency_table_name varchar := '';
    global_interdependency_edge_table_name varchar := '';
    
    edge_geometry_record RECORD;
    edge_record RECORD;
    node_record RECORD;
    interdependency_record RECORD;
    interdependency_edge_record RECORD;
    
    edge_geometry_table_name text := '';
    interdependency_table_name text := '';
    interdependency_edge_table_name text := '';

    pos integer := 0;
    
    --node view 
    node_view_suffix varchar := '_View_Nodes';
    node_view_name varchar := '';
    node_view_record RECORD;
    node_view_csv_file_path_and_name text := '';
    
    --edge / edge geometry view
    edge_edge_geometry_view_suffix varchar := '_View_Edges_Edge_Geometry';
    edge_edge_geometry_view_name varchar := '';
    edge_edge_geometry_record RECORD;
    edge_edge_geometry_csv_file_path_and_name text := '';
    
    --interdependency / interdependency edge view
    interdependency_interdependency_edge_view_suffix varchar := '_View_Interdependency_Interdependency_Edges';
    interdependency_interdependency_edge_view_name varchar := '';
    interdependency_interdependency_edge_record RECORD;
    interdependency_interdependency_edge_csv_file_path_and_name text := '';
    
	node_table_type varchar := 'node';
	edge_table_type varchar := 'edge';
	edge_geometry_table_type varchar := 'edge_geometry';
	interdependency_table_type varchar := 'interdependency';
	
	node_table_column_string varchar := '';
	edge_table_column_string varchar := '';
	edge_geometry_table_column_string varchar := '';
	interdependency_table_column_string varchar := '';
	
	node_view_column_string varchar := '';
	edge_view_column_string varchar := '';
	interdependency_view_column_string varchar := '';
	
BEGIN
    
    --ensure if \ found, replace with /
    output_path := replace(output_path, E'\\', '/');
    
    --there will only be 1 record in graphs per graph
    graph_record_csv_file_path_and_name := output_path||'/'||output_file_prefix||'_graph_record.csv';
    --there could be many records in the global_interdependency table refering to many 'relations' / 'interdependencies' between the user's chosen graph and all other present graphs
    global_interdependency_record_csv_file_path_and_name := output_path||'/'||output_file_prefix||'_global_interdependency_record.csv';
    --there will only be one nodeset per graph (in graphs table)
    node_record_csv_file_path_and_name := output_path||'/'||output_file_prefix||'_node_record.csv';
    --there will only be one edge set per graph (in graphs table)    
    edge_record_csv_file_path_and_name := output_path||'/'||output_file_prefix||'_edge_record.csv';
    --there will only be one edge geometry per graph (in graphs table)
    edge_geometry_csv_file_path_and_name := output_path||'/'||output_file_prefix||'_edge_geometry_record.csv';
    
    --node view full name
    node_view_name := graph_name||node_view_suffix;
    node_view_csv_file_path_and_name := output_path||'/'||node_view_name||'.csv';
    
    --edge edge geometry view full name
    edge_edge_geometry_view_name := graph_name||edge_edge_geometry_view_suffix;
    edge_edge_geometry_csv_file_path_and_name := output_path||'/'||edge_edge_geometry_view_name||'.csv';
    
    --interdependency edge view full name
    interdependency_interdependency_edge_view_name := graph_name||interdependency_interdependency_edge_view_suffix;
    interdependency_interdependency_edge_csv_file_path_and_name := output_path||'/'||interdependency_interdependency_edge_view_name||'.csv';
    
    --will need to interrogate Graphs to retrieve the GraphID based on name supplied 
        --i.e. SELECT * FROM Graphs WHERE GraphName = '''||graph_name||'''';
        --this should only ever return one record as GraphNames are unique
    EXECUTE 'SELECT * FROM "Graphs" WHERE "GraphName" = '||quote_literal(graph_name)||'' INTO graph;
        
    --output the whole graph record to csv
    EXECUTE 'COPY (SELECT * FROM "Graphs" WHERE "GraphName" = '||quote_literal(graph_name)||')  TO '||quote_literal(graph_record_csv_file_path_and_name)||' WITH DELIMITER '','' CSV HEADER';
    
    --output the global interdependency record to csv
    EXECUTE 'COPY (SELECT * FROM "Global_Interdependency" WHERE "InterdependencyFromGraphID" = '||quote_literal(graph."GraphID")||' OR "InterdependencyToGraphID" = '||quote_literal(graph."GraphID")||') TO '''||global_interdependency_record_csv_file_path_and_name||''' WITH DELIMITER '',''  CSV HEADER';
    
	--get the column names for the node table
	EXECUTE 'SELECT * FROM ni_get_all_table_column_names('||quote_literal(default_schema)||', '||quote_literal(graph."GraphName")||', '||quote_literal(node_table_type)||', '||quote_literal(default_geometry_column_name)||')' INTO node_table_column_string;
	
    --output the correct nodes table to csv
	EXECUTE 'COPY (SELECT '||node_table_column_string||', (''srid=''||(ST_SRID(geom)::text)||'';''||(ST_AsText('||quote_ident(default_geometry_column_name)||'::text)::text)) as geom_text FROM '||quote_ident(graph."Nodes")||') TO '''||node_record_csv_file_path_and_name||''' WITH DELIMITER AS '',''  CSV HEADER';
    
    --outputs the correct edges table to csv
    EXECUTE 'COPY (SELECT * FROM '||quote_ident(graph."Edges")||') TO '''||edge_record_csv_file_path_and_name||''' WITH DELIMITER AS '',''  CSV HEADER';
    
    --outputs the correct edge geometry table to csv
    pos := position('_Edges' in graph."Edges");
    edge_geometry_table_name := substring(graph."Edges" FROM 0 FOR pos)||'_Edge_Geometry'; 

	--get the column names for the edge table
	EXECUTE 'SELECT * FROM ni_get_all_table_column_names('||quote_literal(default_schema)||', '||quote_literal(graph."GraphName")||', '||quote_literal(edge_geometry_table_type)||', '||quote_literal(default_geometry_column_name)||')' INTO edge_geometry_table_column_string; 
	
	EXECUTE 'COPY (SELECT '||edge_geometry_table_column_string||', (''srid=''||(ST_SRID(geom)::text)||'';''||(ST_AsText('||quote_ident(default_geometry_column_name)||'::text)::text)) as geom_text FROM '||quote_ident(edge_geometry_table_name)||') TO '''||edge_geometry_csv_file_path_and_name||''' WITH DELIMITER AS '',''  CSV HEADER';
    
    --will need to then use this GraphID to find all interdependencies from Global_Interdependency table     
    --loop around all interdependency records that exist between the chosen graph, and any other graph
    FOR global_interdependency IN EXECUTE 'SELECT * FROM "Global_Interdependency" WHERE "InterdependencyFromGraphID" = '||quote_literal(graph."GraphID")||' OR "InterdependencyToGraphID" = '||quote_literal(graph."GraphID")||' ORDER BY "InterdependencyID" ASC' LOOP
        
        --reset interdependency / interdependency edge records
        interdependency_record_csv_file_path_and_name := '';
        interdependency_edge_record_csv_file_path_and_name := '';
        
        --retrieve the interdependency and interdependency_edge table names
        interdependency_table_name := global_interdependency.InterdependencyTableName;
        interdependency_edge_table_name := global_interdependency.InterdependencyEdgeTableName;
                
        --redefine the output paths for the interdependency and interdependency_edge tables        
        interdependency_record_csv_file_path_and_name := output_path||'/'||output_file_prefix||'_'||interdependency_table_name||'_interdependency_record.csv';
        interdependency_edge_record_csv_file_path_and_name := output_path||'/'||output_file_prefix||'_'||interdependency_edge_table_name||'_interdependency_edge_record.csv';    
        
        --write
        EXECUTE 'COPY (SELECT * FROM '||quote_ident(interdependency_table_name)||') TO '''||interdependency_record_csv_file_path_and_name||''' WITH DELIMITER AS '',''  CSV HEADER';
		
		--get the column names for the interdependency edge table
		EXECUTE 'SELECT * FROM ni_get_all_view_column_names('||quote_literal(default_schema)||', '||quote_literal(graph."GraphName")||', '||quote_literal(interdependency_table_type)||', '||quote_literal(default_geometry_column_name)||')' INTO interdependency_table_column_string;
		
		EXECUTE 'COPY (SELECT '||interdependency_table_column_string||', (''srid=''||(ST_SRID(geom)::text)||'';''||(ST_AsText('||quote_ident(default_geometry_column_name)||'::text)::text)) as geom_text FROM '||quote_ident(interdependency_edge_table_name)||') TO '''||interdependency_edge_record_csv_file_path_and_name||''' WITH DELIMITER AS '',''  CSV HEADER';
        
    END LOOP;
    
    --output the node view
    FOR node_view_record IN EXECUTE 'SELECT table_name FROM information_schema.views WHERE table_schema = ''public'' AND table_name = '||quote_literal(node_view_name) LOOP    
	
		--get the columns names for the node view
		EXECUTE 'SELECT * FROM ni_get_all_view_column_names('||quote_literal(default_schema)||', '||quote_literal(graph."GraphName")||', '||quote_literal(node_table_type)||', '||quote_literal(default_geometry_column_name)||')' INTO node_view_column_string;
	   
		EXECUTE 'COPY (SELECT '||node_view_column_string||', (''srid=''||(ST_SRID(geom)::text)||'';''||(ST_AsText('||quote_ident(default_geometry_column_name)||'::text)::text)) as geom_text FROM '||quote_ident(node_view_record.table_name)||') TO '''||node_view_csv_file_path_and_name||''' WITH DELIMITER AS '',''  CSV HEADER';
		
    END LOOP;
    
    --output the views edge and edge_geometry
    FOR edge_edge_geometry_record IN EXECUTE 'SELECT table_name FROM information_schema.views WHERE table_schema = ''public'' AND table_name = '||quote_literal(edge_edge_geometry_view_name)||'' LOOP    
		
		--get the columns names for the edge view
		EXECUTE 'SELECT * FROM ni_get_all_view_column_names('||quote_literal(default_schema)||', '||quote_literal(graph."GraphName")||', '||quote_literal(edge_geometry_table_type)||', '||quote_literal(default_geometry_column_name)||')' INTO edge_view_column_string;
    
		EXECUTE 'COPY (SELECT '||edge_view_column_string||', (''srid=''||(ST_SRID(geom)::text)||'';''||(ST_AsText('||quote_ident(default_geometry_column_name)||'::text)::text)) as geom_text FROM '||quote_ident(edge_edge_geometry_record.table_name)||') TO '''||edge_edge_geometry_csv_file_path_and_name||''' WITH DELIMITER AS '',''  CSV HEADER';
		
    END LOOP;
    
    --output the interdependency views
    FOR interdependency_interdependency_edge_record IN EXECUTE 'SELECT table_name FROM information_schema.views WHERE table_schema = ''public'' AND table_name = '||quote_literal(interdependency_interdependency_edge_view_name)||'' LOOP  

		--get the columns names for the interdependency interdependency edge view
		EXECUTE 'SELECT * FROM ni_get_all_view_column_names('||quote_literal(default_schema)||', '||quote_literal(graph."GraphName")||', '||quote_literal(interdependency_table_type)||', '||quote_literal(default_geometry_column_name)||')' INTO interdependency_view_column_string;
	
		EXECUTE 'COPY (SELECT '||interdependency_view_column_string||', (''srid=''||(ST_SRID(geom)::text)||'';''||(ST_AsText('||quote_ident(default_geometry_column_name)||'::text)::text)) as geom_text FROM '||quote_ident(interdependency_interdependency_edge_record.table_name)||') TO '''||interdependency_interdependency_edge_csv_file_path_and_name||''' WITH DELIMITER AS '',''  CSV HEADER';
		
    END LOOP;
        
RETURN;    
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION ni_graph_to_csv(character varying, character varying, character varying, character varying) OWNER TO postgres;
