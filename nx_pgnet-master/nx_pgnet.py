#!/usr/bin/env  python
# -*- coding: utf-8 -*-
"""
nx_pgnet - Read/write support for PostGIS network schema in NetworkX.

B{Introduction}

nx_pgnet is module for reading and writing NetworkX graphs to and from PostGIS
tables as specified by the Newcastle University PostGIS network schema.

Note that the terms 'graph' and 'network' are used interchangeably within the
software and documentation. To some extent a 'graph' refers to a topological
object (often in memory) with none or limited attribution, whilst a 'network'
refers to a graph object with attribution of edges and nodes and with
geography defined, although this is not always the case.

nx_pgnet operations

nisql: call database functions from Python

read: PostGIS (network schema) --> NetworkX

write: PostGIS (network schema) <-- NetworkX

import_graph: YAML, GraphML, Pajek .net, GEXF, GML, CSV --> NetworkX (PostGIS network schema compatible)

export_graph: NetworkX (PostGIS network schema compatible) --> YAML, GraphML, Pajek .net, GEXF, GML, CSV, JSON

publish_graph: NetworkX (PostGIS network schema compatible) --> Geoserver via REST API

B{Description}

NetworkX is a python library for graph analysis. Using edge and node
attribution it can be used for spatial network analysis (with geography stored
as node/edge attributes). This module supports the use of NetworkX for the
development of network analysis of spatial networks stored in a PostGIS
spatial database by acting as an interface to a predefined table structure
(the schema) in a PostGIS database from NetworkX Graph classes.

B{PostGIS Schema}

This module assumes that the required PostGIS network schema is available
within the target/source PostGIS database. The schema allows for a
collection of tables to represent a spatial network, storing
network geography and attributes. The definition of the schema and the
associated scripts for network creation are outside the scope of this
documentation however the schema can be briefly described as the following
tables:
	- Graphs:
		Holds a reference to all networks in the database, referencing
		Edge, Edge_Geometry and Node tables.

	- Nodes:
		Holds a respresentation of a network node by storing the geometry of the ndoe
		and node attributes. Contains foreign keys to the graph table.

	- Edges:
		Holds a representation of a network edge by storing source and
		destination nodes and edge attributes. Contains foreign keys
		to graph, edge_geometry and node tables.

	- Edge_Geometry:
		Holds geometry (PostGIS binary LINESTRING/MULTILINESTRING (empty for aspatial networks)
		representation).
		Edge geometry is stored separately to edges for storage/retrieval
		performance where more than one edge share the same geometry.

	- Global_Interdependency:
		Holds a reference to all tables representing dependencies / interdependencies between network
		stored within the schema

	- Interdependency:
		Holds interdependencies between networks.

	- Interdependency_Edges:
		Holds interdependency geometry.

B{Module structure	}

The module is split into a number of key classes:

	- read:
		Contains methods to read data from PostGIS network schema to a NetworkX
		graph.

	- write:
		Contains methods to write a NetworkX graph to PostGIS network schema
		tables.

	- nisql:
		Contains methods which act as a wrapper to the special PostGIS network
		schema functions.

	- import_graph:
		Contains methods allowing a NetworkX graph (PostGIS network schema compatible) to be created from varying network-based formats e.g. YAML, GraphML, Pajek .net, GEXF, GML, CSV

	- export_graph:
		Contains methods allowing a NetworkX graph to be exported to a variety of network-based formats e.g. YAML, GraphML, Pajek .net, GEXF, GML, CSV, JSON

	- publish_graph:
		Contains methods allowing a NetworkX graph stored within the PostGIS network compatible schema to be published to Geoserver for possible dissemination purposes

	- errors:
		Class containing error catching, reporting and logging methods.


Detailed documentation for each class can be found below contained in class
document strings. The highest level functions for reading and writing data are:

Read:
	>>> nx_pgnet.read(conn).pgnet()
	>>> # Reads a network from PostGIS network schema into a NetworkX graph instance.

Read (via csv):
	>>> nx_pgnet.read(conn).pgnet_via_csv()
	>>> # Reads a network from node, edge and edge_geometry csv files and creates a NetworkX graph instance (PostGIS Schema compatible)

Write:
	>>> nx_pgnet.write(conn).pgnet()
	>>> # Writes a NetworkX graph instance to PostGIS network schema tables.

Write (via csv):
	>>> nx_pgnet.write(conn).pgnet_via_csv()
	>>> # Writes a NetworkX graph instance to PostGIS network schema tables, using the COPY CSV function available in PostgreSQL

Read aspatial network from csv then write to schema (via csv):
	>>> nx_pgnet.write(conn).pgnet_read_empty_geometry_from_csv_file_write_to_db()
	>>> # Reads an aspatial network (POINT EMPTY, LINESTRING EMPTY for geometry) from a csv file, and writes the network to PostGIS network schema, via CSV and COPY

Write aspatial NetworkX network to schema (via csv):
	>>> nx_pgnet.write().pgnet_via_csv_empty_geometry()
	>>> # Writes an aspatial NetworkX network instance (POINT EMPTY, LINESTRING EMPTY for geometry) to the PostGIS network schema

B{Database connections}

Connections to PostGIS are created using the OGR simple feature library and are
passed to the read() and write() classes. See http://www.gdal.org/ogr

Connections are mutually exclusive between read() and write() and are contained
within each class (i.e. all methods within those classes inherit the :
connection), although you can of course read and write to the same database.
You must pass a valid connection to the read or write classes for the module
to work.

To create a connection using the OGR python bindings to a database
on localhost:

	>>> import osgeo.ogr as ogr
	>>> conn = ogr.Open("PG: host='127.0.0.1' dbname='database' user='postgres'
	>>>					password='password'",1)

B{Examples}

The following are examples of read and write network operations. For
more detailed information see method documentation below.

Reading a network from PostGIS schema to a NetworkX graph instance:

	>>> import nx_pgnet
	>>> import osgeo.ogr as ogr

	>>> # Create a connection
	>>> conn = ogr.Open("PG: host='127.0.0.1' dbname='database' user='postgres'
	>>>					password='password'",1)

	>>> # Read a network
	>>> # Note 'my_network' is the name of the network stored in the 'Graphs' table
	>>> network = nx_pgnet.read(conn).pgnet('my_network')

Reading a network from CSV files and creating PostGIS network schema compatible NetworkX graph instance:
	>>> import nx_pgnet
	>>> import osgeo.ogr as ogr

	>>> # Create a connection
	>>> conn = ogr.Open("PG: host='127.0.0.1' dbname='database' user='postgres'
	>>>					password='password'",1)

	>>> # Read a network from csv files
	>>> a_network = nx_pgnet.read(conn).pgnet_via_csv('A_Network', 'C://Temp//A_Network_Nodes.csv', 'C://Temp//A_Network_Nodes.csv', 'C://Temp//A_Network_Edge_Geometry.csv', False, False)

Writing a NetworkX graph instance to a PostGIS schema:

Write the network to the same database but under a different name.
'EPSG' is the EPSG code for the output network geometry.
NOTE: If 'overwrite=True' then an existing network in the database of the
same name will be overwritten.
NOTE: If a value of -1 is supplied as an epsg code, the database will expect to be storing an
aspatial network with POINT EMPTY geometry for nodes (WKT representation) and LINESTRING EMPTY geometry for edges (WKT representation)

	>>> epsg = 27700
	>>> nx_pgnet.write(conn).pgnet(network, 'new_network', epsg, overwrite=False)

Reading an aspatial network from csv files and writing to PostGIS schema, via CSV and COPY (Read + Write in one step):

	>>> epsg = -1
	>>> nx_pgnet.write(conn).pgnet_read_empty_geometry_from_csv_file_write_to_db(a_network, 'A_Network', 'C://Temp//A_Network_Nodes.csv', 'C://Temp//A_Network_Nodes.csv', 'C://Temp//A_Network_Edge_Geometry.csv', srs=epsg, False, False, False, 'C://Temp//')

Writing an aspatial network to PostGIS schema, via CSV and COPY:

	>>> epsg = -1
	>>> nx_pgnet.write(conn).pgnet_via_csv(a_network, 'A_Network', -1, False, False, False, 'C://Temp//')

Importing/Exporting:
References:

GEXF: GEXF: http://gexf.net/format/
Pajek: http://vlado.fmf.uni-lj.si/pub/networks/pajek/, http://pajek.imfm.si/doku.php, http://vlado.fmf.uni-lj.si/pub/networks/pajek/doc/pajekman.pdf
YAML: http://www.yaml.org/
GraphML: http://graphml.graphdrawing.org/index.html
GML: http://www.fim.uni-passau.de/en/fim/faculty/chairs/theoretische-informatik/projects.html
Gephi: https://gephi.org

Importing a graph:

Import from GEXF (spatial and aspatial):

	>>> nx_pgnet.import_graph().import_from_gexf('C://Temp//a_network.gexf', 'A_Network', str, False)

Import from Pajek (.net) (spatial):

	>>> nx_pgnet.import_graph().import_from_pajek('C://Temp//a_spatial_network.net', 'A_Spatial_Network', spatial=True, encoding='UTF-8')

Import from Pajek (.net) (aspatial):

	>>> nx_pgnet.import_graph().import_from_pajek('C://Temp//an_aspatial_network.net', 'An_Aspatial_Network', spatial=False, encoding='UTF-8')

Import from YAML (spatial and aspatial):

	>>> nx_pgnet.import_graph().import_from_yaml('C://Temp//a_network.yaml', 'A_Network')

Import from GraphML (spatial):

	>>> nx_pgnet.import_graph().import_from_graphml('C://Temp//a_spatial_network.graphml', 'A_Spatial_Network', spatial=True, nodetype=str)

Import from GraphML (aspatial):

	>>> nx_pgnet.import_graph().import_from_graphml('C://Temp//an_aspatial_network.graphml', 'An_Aspatial_Network', spatial=False, nodetype=str)

Import from GML (spatial and aspatial):

	>>> nx_pgnet.import_graph().import_from_gml('C://Temp//a_spatial_network.gml', 'A_Network', encoding='UTF-8')

Import from Gephi node-edge-list (spatial):

	>>> nx_pgnet.import_graph().import_from_gephi_node_edge_lists('C://Temp//nodes.csv', 'C://Temp//edges.csv', 'A_Spatial_Network', spatial=True, 'geometry_text', 'geometry_text', 'geom', 'geom')

Import from Gephi node-edge-list (aspatial):

	>>> nx_pgnet.import_graph().import_from_gephi_node_edge_lists('C://Temp//nodes.csv', 'C://Temp//edges.csv.', 'An_Aspatial_Network', spatial=False, 'geometry_text', 'geometry_text', 'geom', 'geom')

Importing from JSON (spatial):

	>>> nx_pgnet.import_graph().import_from_json('C://Temp//a_spatial_network.json', 'A_Spatial_Network', True)

Importing from JSON (aspatial):

	>>> nx_pgnet.import_graph().import_from_json('C://Temp//a_network.json', 'A_Network', False)

Exporting a graph:

Export to GEXF (spatial and aspatial):

	>>> nx_pgnet.export_graph(conn).export_to_gexf(a_network, 'C://Temp//', 'a_network', encoding='utf-8', prettyprint=True)

Export to Pajek (.net) (spatial):

	>>> nx_pgnet.export_graph(conn).export_to_pajek(a_network, 'C://Temp//', 'a_spatial_network', spatial=True)

Export to Pajek (.net) (aspatial):

	>>> nx_pgnet.export_graph(conn).export_to_pajek(a_network, 'C://Temp//', 'an_aspatial_network', spatial=False)

Export to YAML (spatial and aspatial):

	>>> nx_pgnet.export_graph(conn).export_to_yaml(a_network, 'C://Temp//', 'a_network', encoding='utf-8')

Export to GraphML (spatial and aspatial):

	>>> nx_pgnet.export_graph(conn).export_to_graphml(a_network, 'C://Temp//', 'a_network', encoding='utf-8', prettyprint=True)

Export to GML (spatial and aspatial):

	>>> nx_pgnet.export_graph(conn).export_to_gml(a_network, 'C://Temp//', 'a_network')

Export to Gephi node-edge-list (spatial):

	>>> nx_pgnet.export_graph(conn).export_to_gephi_node_edge_lists('C://Temp//', 'a_node_view_name', 'an_edge_view_name', spatial=True, 'geom', 'geom', False)

Export to Gephi node-edge-list (aspatial):

	>>> nx_pgnet.export_graph(conn).export_to_gephi_node_edge_lists('C://Temp//', 'a_node_view_name', 'an_edge_view_name', spatial=False)

Export to JSON (spatial and aspatial):

	>>> nx_pgnet.export_graph(conn).export_to_json(a_network, 'C://Temp//', 'a_network')

B{Dependencies}

Python 2.6 or later
NetworkX 1.6 or later
OGR 1.8.0 or later

B{Copyright (C)}

Tomas Holderness, David Alderson & Newcastle University

Developed by Tom Holderness & David Alderson at Newcastle University School of Civil Engineering
and Geosciences, geoinfomatics group:

Alistair Ford, Stuart Barr, Craig Robson.

B{License}

This software is released under a BSD style license. See LICENSE.TXT or type
nx_pgnet.license() for full details.

B{Credits}

Tomas Holderness, David Alderson, Alistair Ford, Stuart Barr and Craig Robson.

B{Contact}

tom.holderness@ncl.ac.uk
www.staff.ncl.ac.uk/tom.holderness

david.alderson@ncl.ac.uk\n
http://www.ncl.ac.uk/ceg/staff/profile/david.alderson

B{Development Notes}

Where possible the PEP8/PEP257 style guide has been implemented.\n
To do:
	1. Check attribution of nodes from schema and non-schema sources
		(blank old id fields are being copied over).
		2. Error  / warnings module.
		3. Investigate bug: "Warning 1: Geometry to be inserted is of type
			Line String, whereas the layer geometry type is Multi Line String.
		Insertion is likely to fail!"
		5. 3D geometry support.

"""
__created__ = "January 2012"
__version__ = "0.9.2"
__author__ = """\n""".join(['David Alderson (david.alderson@ncl.ac.uk)', 'Tomas Holderness (tom.holderness@ncl.ac.uk)', 'Alistair Ford (a.c.ford@ncl.ac.uk)',		 'Stuart Barr (stuart.barr@ncl.ac.uk)','Craig Robson (c.a.robson1@ncl.ac.uk)'])
__license__ = 'BSD style. See LICENSE.TXT'

import sys
import os
import networkx as nx
import osgeo.ogr as ogr
import osgeo.gdal as gdal
import csv
import re
import json

#new
#from geoserver.catalog import Catalog

# Ask ogr to use Python exceptions rather than stderr messages.
ogr.UseExceptions()

class Error(Exception):
	'''Class to handle network IO errors. '''
	# Error class.
	# Ref:http://en.wikibooks.org/wiki/Python_Programming/Exceptions

	def __init__(self, value):
		self.parameter = value
	def __str__(self):
		return repr(self.parameter)


class nisql:
	'''Contains wrappers for PostGIS network schema functions.

	Where possible avoid using this class directly. Uses the read and write
	classes instead.'''

	def __init__(self, db_conn):
		'''Setup connection to be inherited by methods.

		db_conn - ogr connection

		'''
		self.conn = db_conn
		if self.conn == None:
			raise Error('No connection to database.')

	def sql_function_check(self, function_name):
		'''Checks Postgres database for existence of specified function,
			if not found raises error.

		function_name - string - name of function to check database for

		'''

		sql = ("SELECT * FROM pg_proc WHERE proname = '%s';" % (function_name))
		result = None
		for row in self.conn.ExecuteSQL(sql):
			result = row
		if result == None:
			raise Error('Database error: SQL function %s does not exist.' %
							function_name)
		else:
			return None

	def create_network_tables(self, prefix, epsg=27700, directed=False, multigraph=False):
		'''Wrapper for ni_create_network_tables function.

		Creates empty network schema PostGIS tables.
		Requires graph 'prefix 'name and srid to create empty network schema
		PostGIS tables.

		Returns True if successful.

		prefix - string - name of graph/network, and will prefix all instance tables created in the database
		epsg - integer - epsg code of coordinate system of network data
		directed - boolean - true if a directed network is being written to the database
		multigraph - boolean - true if a multigraph network is being written to the database

		'''

		# Create network tables
		sql = ("SELECT * FROM ni_create_network_tables ('%s', %i, CAST(%i AS BOOLEAN), CAST(%i AS BOOLEAN));" % (prefix, epsg, directed, multigraph))
		
		result = None
		for row in self.conn.ExecuteSQL(sql):

			result = row.ni_create_network_tables

		return result

	def create_node_view(self, prefix):
		'''Wrapper for ni_create_node_view function.

		Creates a view containing node attributes and geometry values including
		int primary key suitable for QGIS.

		Requires network name ('prefix').

		Returns view name if successful.

		prefix - string - network name / table prefix

		'''

		viewname = None
		sql = "SELECT * FROM ni_create_node_view('%s')" % prefix
		for row in self.conn.ExecuteSQL(sql):
			viewname = row.ni_create_node_view
		if viewname == None:
			raise Error("Could not create node view for network %s" % (prefix))
		return viewname

	def create_edge_view(self, prefix):
		'''Wrapper for ni_create_edge_view function.

		Creates a view containing edge attributes and edge geometry values.
		Requires network name ('prefix').

		Returns view name if successful.

		prefix - string - network name / table prefix

		'''
		viewname = None
		sql = ("SELECT * FROM ni_create_edge_view('%s')" % (prefix))

		for row in self.conn.ExecuteSQL(sql):
			viewname = row.ni_create_edge_view
		if viewname == None:
			raise Error("Could not create edge view for network %s" % (prefix))
		return viewname

	def add_graph_record(self, prefix, directed=False, multigraph=False):
		'''
		Wrapper for ni_add_graph_record function.

		Creates a record in the Graphs table based on graph attributes.

		Returns new graph id of successful.

		prefix - string - graph / network name to add to Graphs table
		directed - boolean - true if a directed network will be written, false otherwise
		multigraph - boolean - true if a multigraph network will be written, false otherwise
		'''

		if ((directed==False) and (multigraph == False)):
			sql = ("SELECT * FROM ni_add_graph_record('%s', FALSE, FALSE);" % (prefix))

		elif ((directed == False) and (multigraph == True)):
			sql = ("SELECT * FROM ni_add_graph_record('%s', FALSE, TRUE);" % (prefix))

		elif ((directed == True) and (multigraph == False)):
			sql = ("SELECT * FROM ni_add_graph_record('%s', TRUE, FALSE);" % (prefix))

		elif ((directed == True) and (multigraph == True)):
			sql = ("SELECT * FROM ni_add_graph_record('%s', TRUE, TRUE);" % (prefix))

		result = self.conn.ExecuteSQL(sql)
		return result

	def ni_node_snap_geometry_equality_check(self, prefix, wkt, srs=27700, snap=0.1):
		'''Wrapper for ni_node_snap_geometry_equality_check function.

		Checks if geometry already eixsts in nodes table, based on input wkt and snap distance

		If not, returns None

		prefix - string - graph / network name
		wkt - string - point geometry to check as wkt
		srs - integer - epsg code of coordinate system of network data
		snap - float - snapping precision value

		'''
		sql = ("SELECT * FROM ni_node_snap_geometry_equality_check('%s', '%s', %s, %s);" % (prefix, wkt, srs, snap))
		result = None

		for row in self.conn.ExecuteSQL(sql):
			result = row.ni_node_snap_geometry_equality_check

		return result

	def node_attribute_equality_check(self, prefix, node_attribute_equality_key, node_attribute_equality_value):
		'''
			Wrapper for ni_node_attribute_equality_check function.

		Checks if a node with the same attribute (node_attribute_equality_key) value (node_attribute_equality_value) already exists in the nodes table

		If not, returns None

		prefix - string - graph / network name
		node_attribute_equality_key - string - name of a key (must exist in node table) to check against
		node_attribute_equality_value - unknown type - value to check against
		'''
		#need to map python types to PostgreSQL types (currently only support string, integer, and float
		if ((type(node_attribute_equality_value) == str) or (type(node_attribute_equality_value) == 'str')):
			sql = ("SELECT * FROM ni_node_attribute_equality_check('%s', '%s', '%s'::text);" % (prefix, node_attribute_equality_key, node_attribute_equality_value))
		elif ((type(node_attribute_equality_value) == int) or (type(node_attribute_equality_value) == 'int')):
			sql = ("SELECT * FROM ni_node_attribute_equality_check('%s', '%s', %s::integer);" % (prefix, node_attribute_equality_key, node_attribute_equality_value))
		elif ((type(node_attribute_equality_value) == float) or (type(node_attribute_equality_value) == 'float')):
			sql = ("SELECT * FROM ni_node_attribute_equality_check('%s', '%s', %s::float);" % (prefix, node_attribute_equality_key, node_attribute_equality_value))
		elif ((type(node_attribute_equality_value) == int) or (type(node_attribute_equality_value) == 'long')):
			sql = ("SELECT * FROM ni_node_attribute_equality_check('%s', '%s', %s::long);" % (prefix, node_attribute_equality_key, node_attribute_equality_value))

		result = None

		for row in self.conn.ExecuteSQL(sql):
			result = row.ni_node_attribute_equality_check

		return result

	def node_geometry_equality_check(self, prefix, wkt, srs=27700):
		'''Wrapper for ni_node_geometry_equality_check function.

		Checks if geometry already eixsts in nodes table.

		If not, returns None

		prefix - string - graph / network name
		wkt - string - point geometry to check as wkt
		srs - integer - epsg code of coordinate system of network data

		'''

		sql = ("SELECT * FROM ni_node_geometry_equality_check('%s', '%s', %s);" % (prefix, wkt, srs))
		result = None

		for row in self.conn.ExecuteSQL(sql):
			result = row.ni_node_geometry_equality_check
		return result

	def ni_edge_snap_geometry_equality_check(self, prefix, wkt, srs=27700, snap=0.1):
		'''Wrapper for ni_edge_snap_geometry_equality_check function.

		Checks if geometry already eixsts in edges table, based on input wkt and snap distance

		If not, returns None

		prefix - string - graph / network name
		wkt - string - line geometry to check as wkt
		srs - integer - epsg code of coordinate system of network data
		snap - float - snap precision

		'''

		sql = ("SELECT * FROM ni_edge_snap_geometry_equality_check('%s', '%s', %s, %s);" % (prefix, wkt, srs, snap))
		result = None

		for row in self.conn.ExecuteSQL(sql):
			result = row.ni_edge_snap_geometry_equality_check

		return result

	def edge_geometry_equality_check(self, prefix, wkt, srs=27700):
		'''Wrapper for ni_edge_geometry_equality_check function.

		Checks if geometry already eixsts in nodes table.

		If not, return None

		prefix - string - graph / network name
		wkt - string - line geometry to check as wkt
		srs - integer - epsg code of coordinate system of network data

		'''

		sql = ("SELECT * FROM ni_edge_geometry_equality_check('%s', '%s', %s);" % (prefix, wkt, srs))

		result = None
		for row in self.conn.ExecuteSQL(sql):
			result = row.ni_edge_geometry_equality_check
		return result

	def delete_network(self, prefix):
		'''Wrapper for ni_delete_network function.

		Deletes a network entry from the Graphs table and drops associated
		tables.

		prefix - string - graph / network name (as stored in Graphs table)

		'''

		sql = ("SELECT * FROM ni_delete_network('%s');" % (prefix))

		result = None
		for row in self.conn.ExecuteSQL(sql):
			result = row.ni_delete_network

		return result

	def graph_to_csv(self, prefix, output_path):
		'''Wrapper for the ni_graph_to_csv function.

		Outputs the tables related to the supplied prefix as .csv files, to the output path specified

		prefix - string - name of a network / graph as saved in the Graphs table
		output_path - string - path to save files to

		'''

		sql = ("SELECT * FROM ni_graph_to_csv('%s', '%s', '%s');" % (prefix, prefix, output_path))

		result = None
		for row in self.conn.ExecuteSQL(sql):
			result = row.ni_graph_to_csv
		return result

	def get_graph_id_by_prefix(self, prefix):
		'''TODO - need to write the equivalent function in the database

		Returns the graph id from the Graphs table based on the given network name

		prefix - string name of a network / graph as saved in the Graphs table

		'''

		sql = ("SELECT \"GraphID\" FROM \"Graphs\" WHERE \"GraphName\" = '%s'" % (prefix))
		result = None
		for row in self.conn.ExecuteSQL(sql):
			result = row.GraphID
		return result

class import_graph:
	'''
    Class to allow a user to import their network / graph from some other common format, that can then be written to PostGIS

    This class only allows importing of individual graphs i.e. we are not yet dealing with interdependencies etc through this

	Supported formats (for import and export) include:

		- GEXF
		- PAJEK - currently a single value or attribute can be used for edge attributes with Pajek format
		- YAML
		- GRAPHML
		- GML
		- GEPHI - compatible CSV node / edge lists
		- JSON
    '''

	def import_from_json(self, path, graphname, spatial=True):
		'''
		Import graph stored in JSON format

		path - string - path to JSON file on disk
		graphname - string - name of graph to assign once created
		spatial - boolean - true if spatial, false otherwise

		'''

		#check input path exists
		if os.path.isfile(path):
			import json

			#open input json file
			with open(path) as data_file:
				#read json data
				json_data = json.load(data_file)

				#get graph attributes
				#directed
				if 'directed' in json_data:
					directed = bool(json_data['directed'])
				else:
					directed = False

				#multigraph
				if 'multigraph' in json_data:
					multigraph = bool(json_data['multigraph'])
				else:
					multigraph = False

				'''#graph name
				if json_data.has_key('name'):
					name = json_data['name']
				else:
					name = 'A graph'''

				#determine type of graph to build
				if ((directed == False) and (multigraph == False)):
					graph = nx.Graph(name=graphname)
				elif ((directed == True) and (multigraph == False)):
					graph = nx.DiGraph(name=graphname)
				elif ((directed == False) and (multigraph == True)):
					graph = nx.MultiGraph(name=graphname)
				elif ((directed == True) and (multigraph == True)):
					graph = nx.MultiDiGraph(name=graphname)

				#check for nodes key
				if 'nodes' in json_data:

					#loop all nodes
					for node in json_data['nodes']:
						if spatial == True:
							if 'Wkt' in node:
								node_wkt = node['Wkt']

								#create a node geometry
								node_geom = ogr.CreateGeometryFromWkt(node_wkt)

								#node tuple containing node coordinates
								node_tuple = '(%s, %s)' % (node_geom.GetX(), node_geom.GetY())

								#add node
								graph.add_node(node_tuple, node)
							else:
								raise Error ('The input json data (%s) does not contain a WKT parameter denoting the geometry of nodes in the network' % (path))
						else:
							if 'NodeID' in node:
								node_id = node['NodeID']

								#add node
								graph.add_node(node_id, node)
							else:
								raise Error('The input json data (%s) does not contain a NodeID value' % (path))

					nodes = graph.nodes(data=True)
				else:
					raise Error('The input json data (%s) does not contain a nodes parameter.' % (path))

				#check for links key
				if 'links' in json_data:

					#loop all edges
					for edge in json_data['links']:
						if spatial == True:
							if 'Wkt' in edge:
								edge_wkt = edge['Wkt']

								#create an edge geometry
								edge_geom = ogr.CreateGeometryFromWkt(edge_wkt)

								#point count
								point_count = edge_geom.GetPointCount()

								#startpoint geom
								edge_startpoint_geom = edge_geom.GetPoint_2D(0)

								#endpoint geom
								edge_endpoint_geom = edge_geom.GetPoint_2D(point_count-1)

								#create tuples
								start_point_edge_tuple = '(%s, %s)' % (edge_startpoint_geom[0], edge_startpoint_geom[1])
								end_point_edge_tuple = '(%s, %s)' % (edge_endpoint_geom[0], edge_endpoint_geom[1])

								#add an edge to the graph
								if not multigraph:
									graph.add_edge(start_point_edge_tuple, end_point_edge_tuple, edge)
								else:
									#unique key expected or multigraphs (always labelled uuid)
									uuid = edge['uuid']
									graph.add_edge(start_point_edge_tuple, end_point_edge_tuple, uuid, edge)
							else:
								raise Error ('The input json data (%s) does not contain a WKT parameter denoting the geometry of edges in the network' % (path))
						else:
							if ('Node_F_ID' in edge and 'Node_T_ID' in edge):

								#from and to
								node_f_id = edge['Node_F_ID']
								node_t_id = edge['Node_T_ID']

								#add edge to the graph
								if not multigraph:
									graph.add_edge(node_f_id, node_t_id, edge)
								else:
									#unique key expected or multigraphs (always labelled uuid)
									uuid = edge['uuid']
									graph.add_edge(node_f_id, node_t_id, uuid, edge)

							else:
								raise Error('The input json data (%s) does not contain a NodeID value' % (path))
				else:
					raise Error('The input json data (%s) does not contain a links parameter.' % (path))

			return graph

	def import_from_gexf(self, path, graphname, node_type=str, relabel=False):
		''' Import graph from Graph Exchange XML Format (GEXF)

		path - string - path to GEXF file on disk
		graphname - string - name of graph to assign once created
		node_type - python type - denotes the Python-type that any string-based attributes will be converted to e.g. (int, float, long, str)
		relabel - boolean - if true relabel the nodes to use the GEXF node label attribute instead of the node id attribute as the NetworkX node label.

		'''

		#check if path to GEXF file exists
		if os.path.isfile(path):
			#build network from raw gexf
			graph_from_raw_gexf = nx.read_gexf(path, node_type=node_type, relabel=relabel)
			#assign network name
			graph_from_raw_gexf.graph['name'] = graphname
			#return network
			return graph_from_raw_gexf
		else:
			raise Error('The specified path %s does not exist' % (path))

	def import_from_pajek(self, path, graphname, spatial=True, encoding='utf-8'):
		'''Import graph from pajek format (.net)

		path - string - path to Pajek file on disk
		graphname - string - name of graph to assign once created
		spatial - boolean - denotes whether the network stored in the path is a 'spatial' or 'aspatial' network (true=spatial)

		A spatial network must have the node coordinates defined as the unique keys or each node e.g. (100,100)

		encoding - string - encoding option to

		'''
		#check if path to Pajek file exists
		if os.path.isfile(path):
			multigraph = False
			#build network from raw gexf
			graph_from_raw_pajek = nx.read_pajek(path, encoding=encoding)

			#create an empty graph (based on the type generated from the graphml input file)
			if isinstance(graph_from_raw_pajek, nx.classes.graph.Graph):
				graph = nx.Graph(name=graphname)
			elif isinstance(graph_from_raw_pajek, nx.classes.digraph.DiGraph):
				graph = nx.DiGraph(name=graphname)
			elif isinstance(graph_from_raw_pajek, nx.classes.multigraph.MultiGraph):
				graph = nx.MultiGraph(name=graphname)
				multigraph = True
			elif isinstance(graph_from_raw_graphml, nx.classes.multidigraph.MultiDiGraph):
				graph = nx.MultiDiGraph(name=graphname)
				multigraph = True
			else:
				raise Error('There was an error whilst trying to recognise the type of graph to be created. The Pajek file supplied is read into NetworkX, and so must contain data to create a: undirected graph (nx.Graph), directed graph (nx.DiGraph), undirected multigraph (nx.MultiGraph), directed multigraph (nx.MultiGraph). The type found was %s' % (str(type(graph_from_raw_pajek))))

			if spatial:

				#read nodes from raw pajek network, and copy to output network
				for node in graph_from_raw_pajek.nodes(data=True):
					coordinates = node[0]
					#convert to tuple
					coordinates = eval(coordinates)
					if len(node) > 0:
						node_attributes = node[1]
					else:
						node_attributes = {}
					#add a node, with attribute dictionary
					graph.add_node(coordinates, node_attributes)

				#read edges from raw pajek network, and copy to output network
				for edge in graph_from_raw_pajek.edges(data=True):
					st_coordinates = edge[0]
					ed_coordinates = edge[1]
					#convert to tuple(s)
					st_coordinates = eval(st_coordinates)
					ed_coordinates = eval(ed_coordinates)

					#grab the attributes for that edge
					if len(edge) > 1:
						edge_attributes = edge[2]
						#need to do something with the wkt
						if 'Wkt' in edge_attributes:
							wkt = edge_attributes['Wkt']
						#need to do something with json
						if 'Json' in edge_attributes:
							json = edge_attributes['Json']
					else:
						edge_attributes = {}

					#add an edge, and the attribute dictionary
					if not multigraph:
						graph.add_edge(st_coordinates, ed_coordinates, edge_attributes)
					else:
						uuid = edge_attributes['uuid']
						graph.add_edge(st_coordinates, ed_coordinates, uuid, edge_attributes)

				#set the graph name
				graph.graph['name'] = graphname
				return graph
			else:
				return graph_from_raw_pajek
		else:
			raise Error('The specified path %s does not exist' % (path))

	def import_from_yaml(self, path, graphname):
		'''Import graph from yaml format

		path - string - path to yaml file on disk
		graphname - string - name to assign to graph
		'''
		#check if path to yaml file exists
		if os.path.isfile(path):
			#build network from raw yaml file
			graph = nx.read_yaml(path)
			#assign network name
			graph.graph['name'] = graphname
			return graph

		else:
			raise Error('The specified path %s does not exist' % (path))

	def import_from_graphml(self, path, graphname, spatial=True, nodetype=str):
		'''Import graph from graphml format

		path - string - path to graphml file on disk
		graphname - string - name to assign to graph
		spatial - boolean - denotes whether the network stored in the path is a 'spatial' or 'aspatial' network (true=spatial)

		A spatial network must have the node coordinates defined as the unique keys or each node e.g. (100,100)
		nodetype - type - default Python type to convert all string elements to.

		'''

		#check if the path to the graphml file exists
		if os.path.isfile(path):
			multigraph = False
			#create a graph by reading the raw graphml input file
			graph_from_raw_graphml = nx.read_graphml(path)

			if spatial:

				#create an empty graph (based on the type generated from the graphml input file)
				if isinstance(graph_from_raw_graphml, nx.classes.graph.Graph):
					graph = nx.Graph(name=graphname)
				elif isinstance(graph_from_raw_graphml, nx.classes.digraph.DiGraph):
					graph = nx.DiGraph(name=graphname)
				elif isinstance(graph_from_raw_graphml, nx.classes.multigraph.MultiGraph):
					graph = nx.MultiGraph(name=graphname)
					multigraph = True
				elif isinstance(graph_from_raw_graphml, nx.classes.multidigraph.MultiDiGraph):
					graph = nx.MultiDiGraph(name=graphname)
					multigraph = True
				else:
					raise Error('There was an error whilst trying to recognise the type of graph to be created. The GraphML file supplied is read into NetworkX, and so must contain data to create a: undirected graph (nx.Graph), directed graph (nx.DiGraph), undirected multigraph (nx.MultiGraph), directed multigraph (nx.MultiGraph). The type found was %s' % (str(type(graph_from_raw_graphml))))

				#can we make the changes to the node ids here i.e. convert from string to tuple?
				for node in graph_from_raw_graphml.nodes(data=True):
					coordinates = node[0]
					#convert to tuple
					coordinates = eval(coordinates)
					if len(node) > 0:
						node_attributes = node[1]
					else:
						node_attributes = {}
					#add a node, and attributes
					graph.add_node(coordinates, node_attributes)

				for edge in graph_from_raw_graphml.edges(data=True):
					st_coordinates = edge[0]
					ed_coordinates = edge[1]
					#convert to tuple(s)
					st_coordinates = eval(st_coordinates)
					ed_coordinates = eval(ed_coordinates)

					#grab the attributes for that edge
					if len(edge) > 1:
						edge_attributes = edge[2]
					else:
						edge_attributes = {}

					#add an edge, and attributes
					if not multigraph:
						graph.add_edge(st_coordinates, ed_coordinates, edge_attributes)
					else:
						uuid = edge_attributes['uuid']
						graph.add_edge(st_coordinates, ed_coordinates, uuid, edge_attributes)

				graph.graph['name'] = graphname
				return graph
			else:
				return graph_from_raw_graphml
		else:
			raise Error('The specified path %s does not exist' % (path))

	def import_from_gml(self, path, graphname, relabel=False, encoding='utf-8'):
		'''Import graph from gml format

			path - string - path to input GML file
			graphname - string - name to assign to graph
			spatial - boolean - denotes whether the network stored in the path is a 'spatial' or 'aspatial' network (true=spatial)

			A spatial network must have the node coordinates defined as the unique keys or each node e.g. (100,100)
			relabel - boolean - If True use the GML node label attribute for node names otherwise use the node id.

		'''
		#check if the path to the input GML file exists
		if os.path.isfile(path):
			#create a graph from the raw input GML file
			graph = nx.read_gml(path, relabel=relabel, encoding=encoding)
			#assign graph given graph name
			graph.graph['name'] = graphname
			return graph
		else:
			raise Error('The specified path %s does not exist' % (path))

	def import_from_gephi_node_edge_lists(self, node_file_path, edge_file_path, graphname, spatial=True, node_file_geometry_text_key='geometry_text', edge_file_geometry_text_key='geometry_text', node_file_raw_geometry_key='geom', edge_file_raw_geometry_key='geom', directed=False):
		'''
		function to read a set of gephi-compatible csv files (nodes and edges separately) and create a network that can be stored wthin the database schema

		node_file_path - string - path to node gephi-compatible csv file
		edge_file_path - string - path to edge gephi-compatible csv file
		graphname - string - name to be given to resultant graph / network created from gephi csv files
		spatial - boolean - denotes whether the network stored in the path is a 'spatial' or 'aspatial' network (true=spatial)

		A spatial network must have the node coordinates defined as the unique keys or each node e.g. (100,100)
		node_file_geometry_text_key - string - column name / attribute name of node WKT geometry in input node csv file
		edge_file_geometry_text_key - string - column name / attribute name of node WKT geometry in input edge csv file (edge geometry must be a LINESTRING)
		node_file_raw_geometry_key - string - column name / attribute name of node raw geometry in input node csv file
		edge_file_raw_geometry_key - string - column name / attribute name of edge raw geometry in input edge csv file
		directed - boolean - denotes whether edges to be read from the input edge file are directed (mixed edge types are not allowed)
		'''
		#check that the input path to the node and edge csv files exist
		if ((os.path.isfile(node_file_path)) and (os.path.isfile(edge_file_path))):

			#currently no support for multigraph + gephi
			if directed == True:
				graph = nx.DiGraph(name=graphname)
			else:
				graph = nx.Graph(name=graphname)

			csv.field_size_limit(sys.maxsize)

			if spatial:

				#node csv file open
				node_csv_file = open(node_file_path, 'r')
				node_csv_reader = csv.reader(node_csv_file, delimiter=',', quoting=csv.QUOTE_MINIMAL)

				#geometry_text attribute should be a wkt version of the geometry representing either the node or the edge.

				node_csv_first_line = True
				node_header = []

				#set default index for each column in csv file
				NodeID_index = -1
				view_id_index = -1
				GraphID_index = -1
				node_geometry_text_index = -1
				wgs84_node_x_index = -1
				wgs84_node_y_index = -1
				google_node_x_index = -1
				google_node_y_index = -1
				node_raw_geometry_index = -1
				#will store indices to remove from node attribute values
				node_attr_value_indices_to_remove = []

				for node_line in node_csv_reader:
					if node_csv_first_line == True:
						#get the header from the node file
						node_header = list(node_line)

						if node_file_geometry_text_key in node_header:
							node_geometry_text_index = node_header.index('geometry_text')

						if 'NodeID' in node_header:
							NodeID_index = node_header.index('NodeID')
							node_attr_value_indices_to_remove.append(NodeID_index)
						if 'view_id' in node_header:
							view_id_index = node_header.index('view_id')
							node_attr_value_indices_to_remove.append(view_id_index)
						if 'GraphID' in node_header:
							GraphID_index = node_header.index('GraphID')
							node_attr_value_indices_to_remove.append(GraphID_index)
						if 'wgs84_node_x' in node_header:
							wgs84_node_x_index = node_header.index('wgs84_node_x')
							node_attr_value_indices_to_remove.append(wgs84_node_x_index)
						if 'wgs84_node_y' in node_header:
							wgs84_node_y_index = node_header.index('wgs84_node_y')
							node_attr_value_indices_to_remove.append(wgs84_node_y_index)
						if 'google_node_x' in node_header:
							google_node_x_index = node_header.index('google_node_x')
							node_attr_value_indices_to_remove.append(google_node_x_index)
						if 'google_node_y' in node_header:
							google_node_y_index = node_header.index('google_node_y')
							node_attr_value_indices_to_remove.append(google_node_y_index)
						if node_file_raw_geometry_key in node_header:
							node_raw_geometry_index = node_header.index(node_file_raw_geometry_key)
							node_attr_value_indices_to_remove.append(node_raw_geometry_index)

						#sort, then reverse indices to ensure last index is removed first
						node_attr_value_indices_to_remove.sort()
						node_attr_value_indices_to_remove.reverse()
						for index in node_attr_value_indices_to_remove:
							node_header.pop(index)

						node_csv_first_line = False
					else:
						#check node file for geometry [node_file_geometry_key]
						if node_geometry_text_index > -1:

							#create a node geometry
							node_geom = ogr.CreateGeometryFromWkt(node_line[node_geometry_text_index])

							#node tuple containing node coordinates
							node_tuple = '(%s, %s)' % (node_geom.GetX(), node_geom.GetY())

							#this dictionary should ignore any attributes called:
							#NodeID
							#view_id
							#GraphID
							node_attr_values = list(node_line)

							for index in node_attr_value_indices_to_remove:
								node_attr_values.pop(index)

							#create a node attribute dictionary
							node_attrs = dict(list(zip(node_header, node_attr_values)))

							#export this geometry to wkt, json, wkb
							#attach these as attributes to node
							graph.add_node(node_tuple, node_attrs)

						else:
							raise Error('There was no WKT geometry representation found in the node file %s, with WKT field name %s' % (node_file_path, node_file_geometry_text_key))

				#close the csv file
				node_csv_file.close()

				#edge csv file open
				edge_csv_file = open(edge_file_path, 'r')
				edge_csv_reader = csv.reader(edge_csv_file, delimiter=',', quoting=csv.QUOTE_MINIMAL)

				#set default index for each column in csv file
				GraphID_index = -1
				Edge_GeomID_index = -1
				EdgeID_index = -1
				Node_F_ID_index = -1
				Node_T_ID_index = -1
				view_id_index = -1
				edge_geometry_text_index = -1
				edge_geometry_raw_geometry_index = -1

				google_startpoint_x_index = -1
				google_startpoint_y_index =	-1
				google_endpoint_x_index = -1
				google_endpoint_y_index = -1

				wgs84_startpoint_x_index = -1
				wgs84_startpoint_y_index = -1
				wgs84_endpoint_x_index = -1
				wgs84_endpoint_y_index = -1

				edge_csv_first_line = True
				edge_header = []

				#will store indices to remove from node attribute values
				edge_attr_value_indices_to_remove = []

				for edge_line in edge_csv_reader:
					if edge_csv_first_line == True:
						#get the header from the edge file
						edge_header = list(edge_line)

						#check for WKT
						if edge_file_geometry_text_key in edge_header:
							edge_geometry_text_index = edge_header.index(edge_file_geometry_text_key)

						if 'GraphID' in edge_header:
							GraphID_index = edge_header.index('GraphID')
							edge_attr_value_indices_to_remove.append(GraphID_index)
						if 'Edge_GeomID' in edge_header:
							Edge_GeomID_index = edge_header.index('Edge_GeomID')
							edge_attr_value_indices_to_remove.append(Edge_GeomID_index)
						if 'EdgeID' in edge_header:
							EdgeID_index = edge_header.index('EdgeID')
							edge_attr_value_indices_to_remove.append(EdgeID_index)
						if 'Node_F_ID' in edge_header:
							Node_F_ID_index = edge_header.index('Node_F_ID')
							edge_attr_value_indices_to_remove.append(Node_F_ID_index)
						if 'Node_T_ID' in edge_header:
							Node_T_ID_index = edge_header.index('Node_T_ID')
							edge_attr_value_indices_to_remove.append(Node_T_ID_index)
						if 'view_id' in edge_header:
							view_id_index = edge_header.index('view_id')
							edge_attr_value_indices_to_remove.append(view_id_index)
						if 'google_startpoint_x' in edge_header:
							google_startpoint_x_index = edge_header.index('google_startpoint_x')
							edge_attr_value_indices_to_remove.append(google_startpoint_x_index)
						if 'google_startpoint_y' in edge_header:
							google_startpoint_y_index = edge_header.index('google_startpoint_y')
							edge_attr_value_indices_to_remove.append(google_startpoint_y_index)
						if 'google_endpoint_x' in edge_header:
							google_endpoint_x_index = edge_header.index('google_endpoint_x')
							edge_attr_value_indices_to_remove.append(google_endpoint_x_index)
						if 'google_endpoint_y' in edge_header:
							google_endpoint_y_index = edge_header.index('google_endpoint_y')
							edge_attr_value_indices_to_remove.append(google_endpoint_y_index)
						if 'wgs84_startpoint_x' in edge_header:
							wgs84_startpoint_x_index = edge_header.index('wgs84_startpoint_x')
							edge_attr_value_indices_to_remove.append(wgs84_startpoint_x_index)
						if 'wgs84_startpoint_y' in edge_header:
							wgs84_startpoint_y_index = edge_header.index('wgs84_startpoint_y')
							edge_attr_value_indices_to_remove.append(wgs84_startpoint_y_index)
						if 'wgs84_endpoint_x' in edge_header:
							wgs84_endpoint_x_index = edge_header.index('wgs84_endpoint_x')
							edge_attr_value_indices_to_remove.append(wgs84_endpoint_x_index)
						if 'wgs84_endpoint_y' in edge_header:
							wgs84_endpoint_y_index = edge_header.index('wgs84_endpoint_y')
							edge_attr_value_indices_to_remove.append(wgs84_endpoint_y_index)
						if edge_file_raw_geometry_key in edge_header:
							edge_geometry_raw_geometry_index = edge_header.index(edge_file_raw_geometry_key)
							edge_attr_value_indices_to_remove.append(edge_geometry_raw_geometry_index)

						#sort, then reverse indices to ensure last index is removed first
						edge_attr_value_indices_to_remove.sort()
						edge_attr_value_indices_to_remove.reverse()

						#remove all column headings (attributes) that are not to be transferred to db
						for index in edge_attr_value_indices_to_remove:
							edge_header.pop(index)

						edge_csv_first_line = False

					else:

						#check edge file for geometry ['geometry_text']
						if edge_geometry_text_index > -1:

							#create edge geometry
							edge_geom = ogr.CreateGeometryFromWkt(edge_line[edge_geometry_text_index])

							#point count of edge
							point_count = edge_geom.GetPointCount()

							#grab start point of edge
							start_point_edge_geom = edge_geom.GetPoint_2D(0)

							#grab end point of edge
							end_point_edge_geom = edge_geom.GetPoint_2D(point_count-1)

							#create tuples of start and end point coordinates
							start_point_edge_tuple = '(%s, %s)' % (start_point_edge_geom[0], start_point_edge_geom[1])
							end_point_edge_tuple = '(%s, %s)' % (end_point_edge_geom[0], end_point_edge_geom[1])

							#grab the csv line as a list
							edge_attr_values = list(edge_line)

							#remove all values from current line that are not to be transferred to db
							for index in edge_attr_value_indices_to_remove:
								edge_attr_values.pop(index)

							#create a edge attribute dictionary
							edge_attrs = dict(list(zip(edge_header, edge_attr_values)))

							graph.add_edge(start_point_edge_tuple, end_point_edge_tuple, edge_attrs)
						else:
							raise Error('There was no WKT geometry representation found in the edge file %s, with WKT field name %s' % (edge_file_path, edge_file_geometry_text_key))

				#close edge file
				edge_csv_file.close()
				return graph
			else:

				#edge csv file open
				edge_csv_file = open(edge_file_path, 'r')
				edge_csv_reader = csv.DictReader(edge_csv_file, delimiter=',', quoting=csv.QUOTE_MINIMAL)

				use_F_ID = True
				use_T_ID = True

				edge_csv_first_line = True
				for edge_data in edge_csv_reader:
					if edge_csv_first_line == True:

						if 'Node_F_ID' not in edge_data and 'Source' not in edge_data:
							raise Error('The specified edge file (%s) does not contain either a value for Node_F_ID or Source. Either or both of these values must be defined when importing from a Gephi edge list.' % (edge_file_path))
						if 'Node_T_ID' not in edge_data and 'Target' not in edge_data:
							raise Error('The specified edge file (%s) does not contain either a value for Node_T_ID or Target. Either or both of these values must be defined when importing from a Gephi edge list.' % (edge_file_path))
						if 'Edge_GeomID' not in edge_data:
							raise Error('The specified edge file (%s) does not contain a value for Edge_GeomID' % (edge_file_path))
						if 'EdgeID' not in edge_data:
							raise Error('The specified edge file (%s) does not contain a value for EdgeID' % (edge_file_path))

						#determine start of edge
						if 'Node_F_ID' in edge_data:
							from_ = edge_data['Node_F_ID']
							use_F_ID = True
						elif 'Source' in edge_data:
							from_ = edge_data['Source']
							use_F_ID = False

						#determine end of edge
						if 'Node_T_ID' in edge_data:
							to_ = edge_data['Node_T_ID']
							use_T_ID = True
						elif 'Target' in edge_data:
							to_ = edge_data['Target']
							use_T_ID = False

						#remove unnecessary attributes
						edge_attrs = edge_data
						if 'Node_F_ID' in edge_attrs:
							del edge_attrs['Node_F_ID']
						if 'Node_T_ID' in edge_attrs:
							del edge_attrs['Node_T_ID']
						if 'Source' in edge_attrs:
							del edge_attrs['Source']
						if 'Target' in edge_attrs:
							del edge_attrs['Target']

						graph.add_edge(from_, to_, edge_attrs)

						edge_csv_first_line = False
					else:
						edge_attrs = edge_data

						if use_F_ID == True:
							from_ = edge_attrs['Node_F_ID']
						else:
							from_ = edge_attrs['Source']
						if use_T_ID == True:
							to_ = edge_attrs['Node_T_ID']
						else:
							to_ = edge_attrs['Target']

						#remove unnecessary attributes
						edge_attrs = edge_data
						if 'Node_F_ID' in edge_attrs:
							del edge_attrs['Node_F_ID']
						if 'Node_T_ID' in edge_attrs:
							del edge_attrs['Node_T_ID']
						if 'Source' in edge_attrs:
							del edge_attrs['Source']
						if 'Target' in edge_attrs:
							del edge_attrs['Target']

						graph.add_edge(from_, to_, edge_attrs)

				edge_csv_file.close()
				return graph

		else:
			raise Error('The specified path to the node file (%s) or the path to the edge file (%s) does not exist. Please check that these files exist at the locations specified' % (node_file_path, edge_file_path))


class publish_graph:
	'''Class to publish a network held within the database schema to Geoserver via the REST API

	- would need to publish both the Node View, and Edge/Edge Geometry View

	'''
	def __init__(self, db_conn, geoserver_rest_url, geoserver_rest_username, geoserver_rest_password):
		'''Setup connection to be inherited by methods.'''
		self.conn = db_conn
		self.geoserver_rest_url = geoserver_rest_url
		self.geoserver_rest_username = geoserver_rest_username
		self.geoserver_rest_password = geoserver_rest_password

		#creates a catalog to the geoserver REST url supplied, using supplied credentials
		self.geoserver_catalog = Catalog(geoserver_rest_url, geoserver_rest_username, geoserver_rest_password)

		if ((self.geoserver_rest_url == None) or (self.geoserver_rest_username == None) or (self.geoserver_rest_password == None)):
			geoserver_connection_error_msg = 'Please ensure a valid value for the REST URL end point of the geoserver instance, the geoserver username and geoserver password have been supplied. (Geoserver REST URL (%s), Geoserver Username (%s), Geoserver Password (%s)' % (self.geoserver_rest_url, self.geoserver_rest_username, self.geoserver_rest_password)

			raise Error(geoserver_connection_error_msg)

		if self.conn == None:
			raise Error('No connection to database.')

	def get_db_parameter_from_connection(self, param='host'):
		'''
		Method to return the given parameter name from the current ogr connection
		'''
		if ((param != 'host') and (param != 'dbname') and (param != 'user') and (param != 'password') and (param != 'port')):
			raise Error('Cannot retrieve the given parameter from the current OGR connection. Please ensure the parameter is one of host, dbname, user, password or port')
		else:
			connection_string = self.conn.name

			#find the connection parameter from the connection string
			connection_param_start_pos = connection_string.find("%s='", (param))

			#means given parameter does not exist
			#return a default otherwise
			if connection_param_start_pos == -1:
				if param == 'port':
					return 5432
				elif param == 'user':
					return 'postgres'
				elif param == 'host':
					return 'localhost'
				else:
					parameter_error_msg = 'Given parameter cannot be found in current OGR connection, and defaults for it cannot be returned. Given parameter value (%s)', param
					raise Error(parameter_error_msg)
			else:
				connection_param_substring = connection_string[connection_param_start_pos:]
				connection_param_first_single_quote_pos = connection_param_substring.find("'")
				connection_param_first_substring = connection_param_substring[connection_param_first_single_quote_pos+1:]
				connection_param_second_single_quote_pos = connection_param_first_substring.find("'")
				connection_param = connection_param_first_substring[:connection_param_second_single_quote_pos]

				return connection_param

	def create_network_schema_datastore(self, datastore_name, workspace_name=None):
		'''
		Method to create a datastore in Geoserver based on the parameters used within the db_conn to create this publish_graph instance

		datastore_name - string - name of datastore to be used in Geoserver
		workspace_name - string - optional name of workspace under which to create network schema datastore (if workspace is None, a default workspace is used

		Returns:
			geoserver datastore object

		'''

		connection_host = self.get_db_parameter_from_connection('host')
		connection_dbname = self.get_db_parameter_from_connection('dbname')
		connection_user = self.get_db_parameter_from_connection('user')
		connection_password = self.get_db_parameter_from_connection('password')
		connection_port = self.get_db_parameter_from_connection('port')

		datastore = self.geoserver_catalog.create_datastore(datastore_name, workspace_name)

		datastore.connection_parameters.update(host=connection_host, port=connection_port, database=connection_dbname, user=connection_user, password=connection_password,dbtype="postgis")
		datastore.enabled = True
		self.geoserver_catalog.save(datastore)

		return datastore

	def publish_to_geoserver(self, graph_name_in_db, feature_store_name):
		'''
		Method to publish a network (node and edge/edge_geometry views) to geoserver

		- use the self.conn database connection to connect to PostGIS

		graph_name - string - name of graph stored in PostGIS network compatible schema
		feature_store_name - string - name given to feature store within Geoserver
		'''

		node_view_suffix = '_View_Nodes'
		edge_edge_geometry_view_suffix = '_View_Edges_Edge_Geometry'

		node_view_name = '%s%s' % (graph_name, node_view_suffix)
		edge_edge_geometry_view_name = '%s%s' % (graph_name, edge_edge_geometry_view_suffix)

		#want to create a feature store for the node view, and another for the edge view


class export_graph:
	'''Class to export networkx instances to chosen format supported by networkx

	Supported formats (for import and export) include:

		- GEXF
		- PAJEK - currently a single value or attribute can be used for edge attributes with Pajek format
		- YAML
		- GRAPHML
		- GML
		- GEPHI - compatible CSV node / edge lists
		- JSON
	'''
	def __init__(self, db_conn):
		'''Setup connection to be inherited by methods.'''
		self.conn = db_conn
		if self.conn == None:
			raise Error('No connection to database.')

	def export_to_json(self, graph, path, output_filename):

		'''
		Export the given graph to the given path, in JSON format

		graph - networkx graph to export
		path - path to export to
		output_filename - output JSON file name

		SEEMS TO ONLY BE WORKING CORRECTLY ONCE THE DATA HAS BEEN WRITTEN IN TO THE DATABASE, THEN READ OUT AGAIN

		'''

		#import json_graph
		from networkx.readwrite import json_graph

		#check the output path exists
		if os.path.isdir(path):

			#set the full output path to save the JSON file to
			full_path = '%s/%s.json' % (path, output_filename)

			#copy the graph
			graph_copy = graph.copy()

			for edge in graph_copy.edges(data=True):
				edge_attrs = edge[2]

				#remove the wkb attr from the edge attributes
				if 'Wkb' in edge_attrs:
					del edge[2]['Wkb']

				#remove the json attr from the edge attributes
				if 'Json' in edge_attrs:
					del edge[2]['Json']

			for node in graph_copy.nodes(data=True):
				node_attrs = node[1]

				#remove the wkb attrs from the node attributes
				if 'Wkb' in node_attrs:
					del node_attrs['Wkb']

				#remove the json attr from the node attributes
				if 'Json' in node_attrs:
					del node_attrs['Json']

			#get node link data (ready for json serializing)
			data = json_graph.node_link_data(graph_copy)

			#serialize the graph data
			json_data = json.dumps(data)

			#open the output file
			json_file = open(full_path, 'w')
			#write the json data to a file
			json_file.write(json_data)
			#close the output file
			json_file.close()

			#return the path to the json file
			return full_path
		else:
			raise Error('The specified path %s does not exist' % (path))

	def export_to_gexf(self, graph, path, output_filename, encoding='utf-8', prettyprint=True):
		'''
		Export the given graph to the given path, in Graph Exchange XML Format (GEXF)

		graph - graph to export
		path - path to export to
		output_filename - output GEXF file name
		encoding - string encoding e.g. utf-8
		prettyprint - boolean - if true, use line breaks and indenting in output GEXF file

		'''
		#check the output path exists
		if os.path.isdir(path):

			#set the full output path to save the gexf file to
			full_path = '%s/%s.gexf' % (path, output_filename)

			if graph.name:
				name = graph.name
			else:
				name = 'A graph'

			#create a networkx copy of the graph to export
			graph_copy = graph.copy()
			graph_copy.name=name

			#currently converting None type to "None"
			for edge in graph_copy.edges(data=True):
				edge_attrs = edge[2]

				#remove the wkb attr from the edge attributes
				if 'Wkb' in edge_attrs:
					del edge[2]['Wkb']

				#convert edge values from None to "None" so they can be handled by NetworkX gexf writer (NoneType unsupported)
				for edge_key in list(edge_attrs.keys()):
					edge_value = edge_attrs[edge_key]
					if edge_value == None:
						edge_value = 'None'
						edge_attrs[edge_key] = edge_value

			#convert node values from None to "None" so they can be handled by NetworkX gexf writer (NoneType unsupported)
			for node in graph_copy.nodes(data=True):

				node_attrs = node[1]

				#remove the wkb attrs from the edge attributes
				if 'Wkb' in node_attrs:
					del node_attrs['Wkb']

				for node_key in list(node_attrs.keys()):
					node_value = node_attrs[node_key]
					if node_value == None:
						node_value = 'None'
						node_attrs[node_key] = node_value

			#write the gexf file
			nx.write_gexf(graph_copy, full_path, encoding=encoding, prettyprint=prettyprint)
			return full_path
		else:
			raise Error('The specified path %s does not exist' % (path))

	'''worked - although there is an issue with exporting the edge geometry'''
	def export_to_pajek(self, graph, path, output_filename, spatial=True, node_attribute_label=None, edge_attribute_weight=1.0, encoding='utf-8'):
		'''
		Export the given graph to the given path as Pajek format
		all attribute values are dropped ... this is not great - how can we keep attributes...

		graph - graph to export
		path - path to export to
		output_filename - output pajek file name
		spatial - boolean - denotes whether the network stored in the path is a 'spatial' or 'aspatial' network (true=spatial)

		A spatial network must have the node coordinates defined as the unique keys or each node e.g. (100,100)
		node_attribute_label - name of attribute of node data to use as label for nodes in pajek (instead of just using coordinates) (can be a list)
		edge_attribute_weight - name of attribute of edge data to use as weight between start and end nodes of edge (can be a value to apply to all edges, or can be a single attribute name)

		'''

		#check the output path exists
		if os.path.isdir(path):

			#set the full output path to save the Pajek file to
			full_path = '%s/%s.net' % (path, output_filename)

			if graph.name:
				name = graph.name
			else:
				name = 'A graph'

			if spatial:

				#checking input graph type (regular graph)
				if isinstance(graph, nx.classes.graph.Graph):
					graph_copy = nx.Graph(name=name)
				#checking input graph type (directed graph)
				elif isinstance(graph, nx.classes.digraph.DiGraph):
					graph_copy = nx.DiGraph(name=name)
				#checking input graph type (multi graph)
				elif isinstance(graph, nx.classes.multigraph.MultiGraph):
					graph_copy = nx.MultiGraph(name=name)
				#checking input graph type (multi directed graph)
				elif isinstance(graph, nx.classes.multidigraph.MultiDiGraph):
					graph_copy = nx.MultiDiGraph(name=name)
				else:
					raise Error('There was an error whilst trying to recognise the type of graph to be created. The graph to be exported must be one of the following types: undirected graph (nx.Graph), directed graph (nx.DiGraph), undirected multigraph (nx.MultiGraph), directed multigraph (nx.MultiGraph). The type found was %s' % (str(type(graph))))

				#copy the nodes to the graph to be output as Pajek i.e. remove all node attributes
				#keep x and y to ensure the network
				for node in graph.nodes(data=True):
					if node_attribute_label is not None or node_attribute_label != '':
						key = '%s' % str(node_attribute_label)
						raw_value = str(node[1][node_attribute_label]).rstrip().lstrip()
						#add the node to the graph, with associated attribute
						graph_copy.add_node(node[0], {'x': float(node[0][0]), 'y':float(node[0][1]), key:raw_value})
					else:
						#add the node to the graph
						graph_copy.add_node(node[0], {'x': float(node[0][0]), 'y':float(node[0][1])})

				#copy the edges to the graph to be output as Pajek i.e. remove all edge attributes
				for edge in graph.edges(data=True):
					#user has specified an attribute name to use as values for edge weights
					if type(edge_attribute_weight) == str:
						#add the edge to the graph
						graph_copy.add_edge(edge[0], edge[1], {'weight': edge[2][edge_attribute_weight]})
					#user has supplied a constant value
					else:
						#add the edge to the graph
						graph_copy.add_edge(edge[0], edge[1], {'weight': edge_attribute_weight})

				#write the copy to the output path
				nx.write_pajek(graph_copy, full_path, encoding=encoding)
				return full_path
			else:
				#create copy of original graph
				graph_copy = graph.copy()

				#remove the empty node geometry attributes (Wkb, Wkt, Json)
				for node in graph_copy.nodes(data=True):
					if len(node) > 1:
						node_attrs = node[1]
						if 'Wkb' in node_attrs:
							del node_attrs['Wkb']
						'''if node_attrs.has_key('Wkt'):
							del node_attrs['Wkt']
						if node_attrs.has_key('Json'):
							del node_attrs['Json']'''

				#remove the empty edge geometry attributes (Wkb, Wkt, Json)
				for edge in graph_copy.edges(data=True):
					if len(edge) > 2:
						edge_attrs = edge[2]
						if 'Wkb' in edge_attrs:
							del edge_attrs['Wkb']
						'''if edge_attrs.has_key('Wkt'):
							del edge_attrs['Wkt']
						if edge_attrs.has_key('Json'):
							del edge_attrs['Json']'''

				#write the copy to the output path
				nx.write_pajek(graph_copy, full_path, encoding=encoding)
				return full_path

		else:
			raise Error('The specified path %s does not exist' % (path))

	'''worked'''
	def export_to_yaml(self, graph, path, output_filename, encoding='utf-8'):
		'''
		Export the given graph to the given path as Yaml format

		graph - networkx graph
		path - string - output path on disk to write YAML file to
		output_filename - string - name of output YAML file to write to disk
		encoding - string - encoding to use for strings

		'''
		#check that the output path exists
		if os.path.isdir(path):

			#set the full output path to save the YAML file to
			full_path = '%s/%s.yaml' % (path, output_filename)

			#create a networkx copy of the graph to export
			graph_copy = graph.copy()

			#remove wkb attribute from edge
			for edge in graph_copy.edges(data=True):
				if len(edge) > 1:
					edge_attrs = edge[2]
					if 'Wkb' in edge_attrs:
						del edge[2]['Wkb']

			#write out the graph to YAML format
			nx.write_yaml(graph_copy, full_path, encoding)

			return full_path

		else:
			raise Error('The specified path %s does not exist' % (path))

	'''working - has to change None types to "None" string to prevent graphml.py of networkx write function from failing on "None" types'''
	def export_to_graphml(self, graph, path, output_filename, encoding='utf-8', prettyprint=True):
		'''
		Export the given graph to the given path as GraphML format

		graph - networkx graph
		path - string - output path on disk to write GraphML file to
		output_filename - string - name of output GraphML file to write
		encoding - string - encoding of string outputs
		prettyprint - boolean - if true use line breaks and indentation in output GraphML

		'''

		#check that the output path exists
		if os.path.isdir(path):

			#set the full output path to save the GraphML file to
			full_path = '%s/%s.graphml' % (path, output_filename)

			#create a networkx copy of the graph to export
			graph_copy = graph.copy()

			#remove the Wkb element from the edge attributes
			for edge in graph_copy.edges(data=True):
				if len(edge) > 2:
					edge_attrs = edge[2]
					if 'Wkb' in edge_attrs:
						del edge[2]['Wkb']

			#remove the Wkb element from the node attributes
			for node in graph_copy.nodes(data=True):
				if len(node) > 0:
					node_attrs = node[1]
					if 'Wkb' in node_attrs:
						del node[1]['Wkb']

			#currently converting None type to "None"
			for edge in graph_copy.edges(data=True):
				edge_attrs = edge[2]
				for edge_key in list(edge_attrs.keys()):
					edge_value = edge_attrs[edge_key]
					if edge_value == None:
						edge_value = 'None'
						edge_attrs[edge_key] = edge_value

			#currently converting None type to "None"
			for node in graph_copy.nodes(data=True):
				node_attrs = node[1]
				for node_key in list(node_attrs.keys()):
					node_value = node_attrs[node_key]
					if node_value == None:
						node_value = 'None'
						node_attrs[node_key] = node_value

			#write out the graph to GraphML format
			nx.write_graphml(graph_copy, full_path, encoding=encoding, prettyprint=prettyprint)
			return full_path
		else:
			raise Error('The specified path %s does not exist' % (path))

	'''
	working
	'''
	def export_to_gml(self, graph, path, output_filename):
		'''
		Export the given graph to the given path as GML format

		--graph - networkx graph
		--path - folder to save gml file to
		--output_filename - gml output file name (no extension)

		'''

		#check that the output path exists
		if os.path.isdir(path):
			#create a deepcopy of the graph to export
			#graph_copy = copy.deepcopy(graph)

			#set the full output path to write the GML file to
			full_path = '%s/%s.gml' % (path, output_filename)

			#create a networkx copy of the graph to export
			graph_copy = graph.copy()

			#currently deleting the Wkb element from the edge attributes
			for edge in graph_copy.edges(data=True):
				if len(edge) > 1:
					edge_attrs = edge[2]
					#currently removes the wkb element to allow writing to pajek
					if 'Wkb' in edge_attrs:
						del edge[2]['Wkb']

			#need to ensure that the nodes have coordinates added to them on the way out e.g. as JSON and WKT
			for node in graph_copy.nodes(data=True):
				#grab the node coordinates
				node_coordinates = node[0]
				#grab the node attributes (testing these for wkt and json keys)
				node_attrs = node[1]

				if 'Wkt' not in node_attrs and 'Json' not in node_attrs:
					#create an empty point geometry
					geom = ogr.Geometry(ogr.wkbPoint)
					#set the coordinates of the geometry
					geom.SetPoint_2D(0, *node_coordinates)

					#assign a wkt attribute to the node
					if 'Wkt' not in node_attrs:
						node_wkt = ogr.Geometry.ExportToWkt(geom)
						node_attrs['Wkt'] = node_wkt

					#assign a json attribute to the node
					if 'Json' not in node_attrs:
						node_json = ogr.Geometry.ExportToJson(geom)
						node_attrs['Json'] = node_json

			#need to do something to convert the node data coordinates to a "label" (currently converting to integer)
			graph_copy = nx.relabel.convert_node_labels_to_integers(graph_copy, first_label=1, ordering='default', discard_old_labels=False)

			#write out the graph as GML to the given path
			nx.write_gml(graph_copy, full_path)

			return full_path
		else:
			raise Error('The specified path %s does not exist' % (path))

	def export_to_gephi_node_edge_lists(self, path, node_viewname, edge_viewname, spatial=True, node_geometry_column_name='geom', edge_geometry_column_name='geom', directed=False):
		'''

		--path - string - output folder location
		--node_viewname - string - name of node view in database e.g. <network_name>_View_Nodes
		--edge_viewname - string - name of edge view in database e.g. <network_name>_View_Edges_Edge_Geometry
		--spatial - boolean - denotes whether the network stored in the path is a 'spatial' or 'aspatial' network (true=spatial)

		A spatial network must have the node coordinates defined as the unique keys or each node e.g. (100,100)
		--node_geometry_column_name - string - name of geometry column of node view e.g. geom
		--edge_geometry_column_name - string - name of geometry column of edge view e.g. geom
		--directed - boolean - denotes if outpout

		export the edge/edge_geometry view along with the node view for direct import to Gephi
		the files will be created within the same name as the tables
		node table has all attributes of node table +
			#google map projection x coordinate (900913) = google_node_x
			#google map projection y coordinate (900913) = google_node_y
			#wgs84 map projection x coordinate (4326) = wgs84_node_x
			#wgs84 map projection y coordinate (4326) = wgs84_node_y

		edge table has all attributes of edge table ("Node_F_ID" = "Source", "Node_T_ID" = "Target") +
			#google map projection x coordinate startpoint (900913) = google_startpoint_x
			#google map projection y coordinate startpoint (900913) = google_startpoint_y
			#google map projection x coordinate endpoint (900913) = google_endpoint_x
			#google map projection y coordinate endpoint (900913) = google_endpoint_y

			#wgs84 map projection x coordinate startpoint (4326) = wgs84_startpoint_x
			#wgs84 map projection x coordinate startpoint (4326) = wgs84_startpoint_y
			#wgs84 map projection x coordinate endpoint (4326) = wgs84_endpoint_x
			#wgs84 map projection x coordinate endpoint (4326) = wgs84_endpoint_y
		'''

		#check if graph is directed/undirected (cannot have mixed graph types (Directed + Undirected edges) in the same graph)
		if directed == False:
			gephi_directed_value = 'Undirected'
		else:
			gephi_directed_value = 'Directed'

		#define the output file name and path for the Gephi-compatible csv dump of the node view
		node_file_name = '%s%s.csv' % (path, node_viewname)

		#define the output file name and path for the Gephi-compatible csv dump of the edge view
		edge_file_name = '%s%s.csv' % (path, edge_viewname)

		if spatial:
			#define the sql to execute for generating a Gephi-compatible csv dump of the node view
			node_sql = ("COPY (SELECT node_table.*, ST_AsText(node_table.%s) as geometry_text, ST_SRID(node_table.%s) as srid, ST_X(ST_AsText(ST_Transform(node_table.%s, 900913))) as google_node_x, ST_Y(ST_AsText(ST_Transform(node_table.%s, 900913))) as google_node_y, ST_X(ST_AsText(ST_Transform(node_table.%s, 4326))) as wgs84_node_x, ST_Y(ST_AsText(ST_Transform(node_table.%s, 4326))) as wgs84_node_y FROM \"%s\" AS node_table) TO '%s' DELIMITER AS ',' CSV HEADER;" % (node_geometry_column_name, node_geometry_column_name, node_geometry_column_name, node_geometry_column_name, node_geometry_column_name, node_geometry_column_name, node_viewname, node_file_name))

			#define the sql to execute for generating a Gephi-compatible csv dump of the edge view
			edge_sql = ("COPY (SELECT edge_table.*, ST_AsText(edge_table.%s) as geometry_text, ST_SRID(edge_table.%s) as srid, \"Node_F_ID\" as \"Source\", \"Node_T_ID\" as \"Target\", '%s' as \"Type\", ST_X(ST_Transform(ST_StartPoint(edge_table.%s), 900913)) as google_startpoint_x, ST_Y(ST_Transform(ST_StartPoint(edge_table.%s), 900913)) as google_startpoint_y, ST_X(ST_Transform(ST_EndPoint(edge_table.%s), 900913)) as google_endpoint_x, ST_Y(ST_Transform(ST_EndPoint(edge_table.%s), 900913)) as google_endpoint_y, ST_X(ST_Transform(ST_StartPoint(edge_table.%s), 4326)) as wgs84_startpoint_x, ST_Y(ST_Transform(ST_StartPoint(edge_table.%s), 4326)) as wgs84_startpoint_y, ST_X(ST_Transform(ST_EndPoint(edge_table.%s), 4326)) as wgs84_endpoint_x, ST_Y(ST_Transform(ST_EndPoint(edge_table.%s), 4326)) as wgs84_endpoint_y FROM \"%s\" AS edge_table) TO '%s' DELIMITER AS ',' CSV HEADER" % (edge_geometry_column_name, edge_geometry_column_name, gephi_directed_value, edge_geometry_column_name, edge_geometry_column_name, edge_geometry_column_name, edge_geometry_column_name, edge_geometry_column_name, edge_geometry_column_name, edge_geometry_column_name, edge_geometry_column_name, edge_viewname, edge_file_name))

			#execute the node view to csv query
			node_result = self.conn.ExecuteSQL(node_sql)

			#execute the edge view to csv query
			edge_result = self.conn.ExecuteSQL(edge_sql)

		else:
			#define the sql to execute for generating a Gephi-compatible csv dump of the node view
			node_sql = ("COPY (SELECT node_table.* FROM \"%s\" AS node_table) TO '%s' DELIMITER AS ',' CSV HEADER;" % (node_viewname, node_file_name))

			#define the sql to execute for generating a Gephi-compatible csv dump of the edge view
			edge_sql = ("COPY (SELECT edge_table.*, \"Node_F_ID\" as \"Source\", \"Node_T_ID\" as \"Target\", '%s' as \"Type\" FROM \"%s\" AS edge_table) TO '%s' DELIMITER AS ',' CSV HEADER;" % (gephi_directed_value, edge_viewname, edge_file_name))

			#execute the node view to csv query
			node_result = self.conn.ExecuteSQL(node_sql)

			#execute the edge view to csv query
			edge_result = self.conn.ExecuteSQL(edge_sql)

		#check if output files exist
		if os.path.isfile(node_file_name) and os.path.isfile(edge_file_name):
			return [node_file_name, edge_file_name]
		else:
			raise Error('Error exporting data from node view (%s, geom_column: %s) to file at (%s) and edge view (%s, geom_column: %s) to file at (%s)' % (node_viewname, node_geometry_column_name, node_file_name, edge_viewname, edge_geometry_column_name, edge_file_name))


class read:
	'''Class to read and build networks from PostGIS schema network tables.'''

	def __init__(self, db_conn):
		'''Setup connection to be inherited by methods.

		db_conn - ogr connection

		'''

		self.conn = db_conn

		if self.conn == None:
			raise Error('No connection to database.')

	def getfieldinfo(self, lyr, feature, flds):
		'''Get information about fields from a table (as OGR feature).

		lyr - OGR Layer
		feature - OGR feature to query
		flds - dict - dictionary of fields

		'''
		f = feature
		return [f.GetField(f.GetFieldIndex(x)) for x in flds]

	def pgnet_edges(self, graph):
		'''Reads edges from edge and edge_geometry tables and add to graph.

		graph - networkx graph/network

		'''

		#how do we go about setting the spatial filter to NULL for non-spatial tables

		# Join Edges and Edge_Geom
		edge_tbl_view = nisql(self.conn).create_edge_view(self.prefix)
		
		# Get lyr by name
		lyr = self.conn.GetLayerByName(edge_tbl_view)
		#reset to read from start of edge view
		lyr.ResetReading()

		# Get current feature
		feat = lyr.GetNextFeature()

		# Get fields
		flds = [x.GetName() for x in lyr.schema]

		while feat is not None:
			# Read edge attrs.
			flddata = self.getfieldinfo(lyr, feat, flds)
			attributes = dict(list(zip(flds, flddata)))

			#delete view_id from previous view
			if 'view_id' in attributes:
				del attributes['view_id']

			#delete edgeid from previous view
			if 'edgeid' in attributes:
				del attributes['edgeid']

			#delete geomid from previous view
			if 'geomid' in attributes:
				del attributes['geomid']

			#attributes['network'] = network_name
			geom = feat.GetGeometryRef()

			#can be a case where there is a feature but there is no geometry for that feature
			if geom is not None:

				if ((ogr.Geometry.GetGeometryName(geom) == 'MULTILINESTRING') or (ogr.Geometry.GetGeometryName(geom) == 'LINESTRING') or ((ogr.Geometry.GetGeometryName(geom) == 'GEOMETRYCOLLECTION') and (str(geom) == 'GEOMETRYCOLLECTION EMPTY'))):
					attributes["Wkb"] = ogr.Geometry.ExportToWkb(geom)
					attributes["Wkt"] = ogr.Geometry.ExportToWkt(geom)
					attributes["Json"] = ogr.Geometry.ExportToJson(geom)

					geomid = attributes['Edge_GeomID']
					sql = ('SELECT * FROM "%s" WHERE "GeomID" = %s' %(self.prefix+'_View_Edges_Edge_Geometry',geomid))
					atts = {}

					for row in self.conn.ExecuteSQL(sql):

						for key in row.keys():

							atts[key]=row[key]

					#res = self.conn.ExecuteSQL('SELECT * FROM #"iuk_ngnet_eg_View_Edges_Edge_Geometry" WHERE "GeomID" = %s' %i)
					#print('reults from view table')
					#for row in res:
					#	for key in row.keys():
					#		print key,':',row[key]
					#	exit()

					if (isinstance(graph, nx.classes.multigraph.MultiGraph) or isinstance(graph, nx.classes.multidigraph.MultiDiGraph)):
						#unique key expected or multigraphs (always labelled uuid)
						uuid = attributes['uuid']
						graph.add_edge(attributes['Node_F_ID'], attributes['Node_T_ID'], uuid, attributes)
					else:
						graph.add_edge(attributes['Node_F_ID'], attributes['Node_T_ID'], attributes)
						graph.add_edge(atts['Node_F_ID'],atts['Node_T_ID'],atts)

			feat = lyr.GetNextFeature()

	def pgnet_nodes(self, graph):
		'''Reads nodes from node table and add to graph.

		graph - networkx graph/network

		'''

		# Join Edges and Edge_Geom
		node_tbl_view = nisql(self.conn).create_node_view(self.prefix)

		# Get lyr by name
		lyr = self.conn.GetLayerByName(node_tbl_view)
		#reset to read from start of node view
		lyr.ResetReading()

		# Get fields
		flds = [x.GetName() for x in lyr.schema]
		# Get current feature
		feat = lyr.GetNextFeature()

		# Loop features
		while feat is not None:
			# Read node attrs.
			flddata = self.getfieldinfo(lyr, feat, flds)
			attributes = dict(list(zip(flds, flddata)))

			#delete view_id from previous view
			if 'view_id' in attributes:
				del attributes['view_id']

			if 'nodeid' in attributes:
				del attributes['nodeid']

			geom = feat.GetGeometryRef()
			attributes["Wkb"] = ogr.Geometry.ExportToWkb(geom)
			attributes["Wkt"] = ogr.Geometry.ExportToWkt(geom)
			attributes["Json"] = ogr.Geometry.ExportToJson(geom)


			graph.add_node((attributes['NodeID']), attributes)
			feat = lyr.GetNextFeature()

	def graph_table(self, prefix):
		'''Reads the attributes of a graph from the graph table.

		Returns attributes as a dict of variables.

		prefix - string - graph / network name, as stored in Graphs table

		'''

		graph = {}
		sql = ('SELECT * FROM	"Graphs" WHERE "GraphName" = \'%s\';' % prefix)
		for row in self.conn.ExecuteSQL(sql):
			res = row
			keys = row.keys()
		for key in keys:
			graph[key] = res[key]

		return graph

	def pgnet(self, prefix):
		'''Read a network from PostGIS network schema tables.

		Returns instance of networkx.Graph().

		prefix - string - graph / network name

		'''

		# Set up variables
		self.prefix = prefix
		# Get graph attributes
		graph_attrs = self.graph_table(self.prefix)

		if graph_attrs == None:
			error = "Can't find network '%s' in Graph table" % self.prefix
			raise Error(error)

		#NEW handles multi and directed graphs

		if ((graph_attrs['Directed'] == 0) and (graph_attrs['MultiGraph'] == 0)):
			G = nx.Graph(name=prefix)
		elif ((graph_attrs['Directed'] == 1) and (graph_attrs['MultiGraph'] == 0)):
			G = nx.DiGraph(name=prefix)
		elif ((graph_attrs['Directed'] == 0) and (graph_attrs['MultiGraph'] == 1)):
			G = nx.MultiGraph(name=prefix)
		elif ((graph_attrs['Directed'] == 1) and (graph_attrs['MultiGraph'] == 1)):
			G = nx.MultiDiGraph(name=prefix)

		# Assign graph attributes to graph
		for key, value in graph_attrs.items():
			G.graph[key] = value

		self.pgnet_edges(G)
		#print('Number of edges here1:',G.number_of_edges())
		self.pgnet_nodes(G)

		return G

	#do we need to supply a set of data types alongside each file e.g.
	#node_csv_file_data_types

	#create a network x graph instance by reading the csv input files
	#def pgnet_via_csv(self, network_name, node_csv_file_name, edge_csv_file_name, edge_geometry_csv_file_name, directed=False, multigraph=False):
	def pgnet_via_csv(self, network_name, node_csv_file_name, edge_csv_file_name, edge_geometry_csv_file_name, node_data_types={"GraphID":int, "NodeID":int, "geom":str, "geom_text":str}, edge_data_types={"Node_F_ID":int, "Node_T_ID":int, "GraphID":int, "Edge_GeomID":int, "EdgeID":int}, edge_geometry_data_types={"geom_text":str, "geom":str, "GeomID":int}, directed=False, multigraph=False):
		'''Read a network from a csv formatted file (as if output from the schema, but could be manually created

			- ensures the node file has columns:
				- GraphID
				- geom
			- ensures the edge file has columns:
				- Node_F_ID
				- Node_T_ID
				- GraphID
				- Edge_GeomID
			- ensures the edge geometry file has columns:
				- GeomID
				- geom

		network_name - string - name of network to create
		node_csv_file_name - string - csv file path to node file
		node_data_types - dict - dictionary of node table field names mapped to Python data types e.g. {'attribute_1':int, 'attribute_2':int, 'attribute_3':str, 'attribute_4':float}
		edge_csv_file_name - string - csv file path to edge file
		edge_data_types - dict - dictionary of edge table field names mapped to Python data types e.g. {'attribute_1':int, 'attribute_2':int, 'attribute_3':str, 'attribute_4':float}
		edge_geometry_csv_file_name - string - csv file path to edge_geometry file
		edge_geometry_data_types - dict - dictionary of edge geometry table field names mapped to Python data types e.g. {'attribute_1':int, 'attribute_2':int, 'attribute_3':str, 'attribute_4':float}
		directed - boolean - denotes whether network to be created is a directed, or undirected network (True=directed, False=undirected)
		multigraph - boolean - denotes whether network to be created is a multigraph, or regular graph (True=multigraph, False=regular graph)

		'''

		#check that the input node csv file exists before proceeding
		if not os.path.isfile(node_csv_file_name):
			raise Error('The input node file does not exist at: %s' % (node_csv_file_name))

		#check that the input edge csv file exists before proceeding
		if not os.path.isfile(edge_csv_file_name):
			raise Error('The input edge file does not exist at: %s' % (edge_csv_file_name))

		#check that the input edge geometry csv file exists before proceeding
		if not os.path.isfile(edge_geometry_csv_file_name):
			raise Error('The input edge geometry file does not exist at: %s' % (edge_geometry_csv_file_name))

		#not directed, not multigraph
		if ((directed == False) and (multigraph == False)):
			net = nx.Graph(name=network_name)
		#not directed, multigraph
		elif ((directed == False) and (multigraph == True)):
			net = nx.MultiGraph(name=network_name)
		#directed, not multigraph
		elif ((directed == True) and (multigraph == False)):
			net = nx.DiGraph(name=network_name)
		#directed, multigraph
		elif ((directed == True) and (multigraph == True)):
			net = nx.MultiDiGraph(name=network_name)

		#disallowed values
		disallowed_values = ['',"",'None',"None"]

		#set large field size limit to allow for massive linestring elements in edge geometry file
		csv.field_size_limit(sys.maxsize)

		#define node, edge, and edge geometry files
		node_csv_file = open(node_csv_file_name, 'r')
		edge_csv_file = open(edge_csv_file_name, 'r')
		temp_edge_csv_file = open(edge_csv_file_name, 'r')
		edge_geometry_csv_file = open(edge_geometry_csv_file_name, 'r')

		#define node, edge, edge_geometry csv file readers
		node_csv_reader = csv.DictReader(node_csv_file, delimiter=',', quoting=csv.QUOTE_MINIMAL)
		temp_edge_csv_reader = csv.DictReader(temp_edge_csv_file, delimiter=',', quoting=csv.QUOTE_MINIMAL)
		edge_csv_reader = csv.DictReader(edge_csv_file, delimiter=',', quoting=csv.QUOTE_MINIMAL)
		#edge_geometry_csv_reader = csv.DictReader(edge_geometry_csv_file, delimiter=',', quoting=csv.QUOTE_MINIMAL)
		edge_geometry_csv_reader = []

		#NEW - to account for VERY long linestring geometries
		first_edge_geometry_line = True

		for line in edge_geometry_csv_file:
			if first_edge_geometry_line == True:
				first_edge_geometry_line = False
				pos_first_comma = line.find(",")
				first_col = line[:pos_first_comma]
				second_col = line[(pos_first_comma+1):]
			else:
				if first_col == 'geom' or first_col == 'geom_text':
					pos_first_comma = line.rfind(",")
					geom_text = line[:pos_first_comma]
					GeomID = line[(pos_first_comma+1):]
				elif first_col == 'GeomID':
					pos_first_comma = line.find(",")
					geom_text = line[(pos_first_comma+1):]
					GeomID = line[:pos_first_comma]
				else:
					raise Error('The first column within the Edge Geometry csv file must be either geom or geom_text, containing a WKT representation of the edge LINESTRING or the first column must be GeomID')

				GeomID = int(GeomID)
				edge_geometry_csv_reader.append({'GeomID':GeomID,'geom_text':geom_text})

		#generic Node table attributes
		generic_node_fieldnames = []
		#generic_node_fieldnames.append("GraphID")
		generic_node_fieldnames.append("NodeID")
		#generic_node_fieldnames.append("geom")

		#generic Edge table attributes
		generic_edge_fieldnames = []
		generic_edge_fieldnames.append("Node_F_ID")
		generic_edge_fieldnames.append("Node_T_ID")
		#generic_edge_fieldnames.append("GraphID")
		generic_edge_fieldnames.append("Edge_GeomID")

		#generic Edge_Geometry table attributes
		generic_edge_geometry_fieldnames = []
		generic_edge_geometry_fieldnames.append("GeomID")
		#generic_edge_geometry_fieldnames.append("geom")

		#need to check that the node csv file header contains at least the minimum generic node fieldnames
		node_first_line = True
		missing_node_fieldname = False
		node_first_line_contents = []
		#loop rows in node table
		for node_row in node_csv_reader:
			##perform a check to see that the node specific fieldnames exist in the node csv file
			if node_first_line == True:
				node_first_line_contents = node_row

				node_first_line = False
				for generic_node_fieldname in generic_node_fieldnames:
					if generic_node_fieldname not in node_row:
						raise Error('The field name %s does not exist in the input node csv file (%s)' % (generic_node_fieldname, node_csv_file_name))
						missing_node_fieldname = True
						break;
				if missing_node_fieldname == True:
					node_csv_file.close()
					raise Error('A mandatory node field name (one of %s) is missing from input node csv file (%s)' % (generic_node_fieldnames, node_csv_file_name))
					break;
				else:
					node_attrs = node_first_line_contents
					node_coord_tuple = None
					if 'view_id' in node_attrs:
						del node_attrs['view_id']

					if 'nodeid' in node_attrs:
						del node_attrs['nodeid']

					#grab the node geometry
					if 'geom_text' in node_row:
						node_geom_wkt_raw = str(node_row['geom_text'])
					elif 'geom' in node_row:
						node_geom_wkt_raw = str(node_row['geom'])
					else:
						raise Error('When reading a network back from csv files, the geometry of the nodes must be contained as WKT string representation e.g. srid=27700;POINT(0 0), in a column named either "geom_text" or "geom"')

					node_geom_srid = node_geom_wkt_raw[:node_geom_wkt_raw.find(';')]
					node_geom_wkt = node_geom_wkt_raw[node_geom_wkt_raw.find(';')+1:len(node_geom_wkt_raw)]

					#create an OGR Point geometry from
					node_geom = ogr.CreateGeometryFromWkt(node_geom_wkt)

					#need to do some check if geometry is NULL / POINT EMPTY

					#create a wkb and json version to store as node attributes
					node_geom_wkb = ogr.Geometry.ExportToWkb(node_geom)
					node_geom_json = ogr.Geometry.ExportToJson(node_geom)

					#add the wkb and json versions to the node attributes
					node_attrs["Wkb"] = node_geom_wkb
					node_attrs["Wkt"] = node_geom_wkt
					node_attrs["Json"] = node_geom_json

					#if empty geom
					if node_geom_wkt.find('EMPTY') != -1:
						node_coord_tuple=(node_attrs['NodeID'])
						del node_attrs['NodeID']
					#if not empty geom
					else:
						node_coord = node_geom.GetPoint_2D(0)
						node_coord_tuple=(node_coord[0], node_coord[1])

					if 'geom' in node_attrs:
						del node_attrs['geom']

					#assign correct data types to node attributes
					for column in node_attrs:
						if column in node_data_types:
							if node_attrs[column] not in disallowed_values:
								if node_data_types[column] == str:
									node_attrs[column] = str(node_attrs[column])

								if node_data_types[column] == int:
									node_attrs[column] = int(node_attrs[column])

								if node_data_types[column] == float:
									node_attrs[column] = float(node_attrs[column])

					#add the node to the network, with attributes
					net.add_node(node_coord_tuple, node_attrs)
			##process the rest of the file
			else:
				#grab the attributes for that node
				node_attrs = node_row
				node_coord_tuple = None

				if 'view_id' in node_attrs:
					del node_attrs['view_id']

				if 'nodeid' in node_attrs:
					del node_attrs['nodeid']

				#grab the node geometry
				if 'geom_text' in node_row:
					node_geom_wkt_raw = str(node_row['geom_text'])
				elif 'geom' in node_row:
					node_geom_wkt_raw = str(node_row['geom'])
				else:
					raise Error('When reading a network back from csv files, the geometry of the nodes must be contained as WKT string representation e.g. srid=27700;POINT(0 0), in a column named either "geom_text" or "geom"')

				node_geom_srid = node_geom_wkt_raw[:node_geom_wkt_raw.find(';')]
				node_geom_wkt = node_geom_wkt_raw[node_geom_wkt_raw.find(';')+1:len(node_geom_wkt_raw)]

				#create an OGR Point geometry from
				node_geom = ogr.CreateGeometryFromWkt(node_geom_wkt)

				#if empty geom
				if node_geom_wkt.find('EMPTY') != -1:
					node_coord_tuple=(node_attrs['NodeID'])
					del node_attrs['NodeID']
				#if not empty geom
				else:
					node_coord = node_geom.GetPoint_2D(0)
					node_coord_tuple=(node_coord[0], node_coord[1])

					#create an OGR Point geometry from
					node_geom = ogr.CreateGeometryFromWkt(node_geom_wkt)

					#create a wkb and json version to store as node attributes
					node_geom_wkb = ogr.Geometry.ExportToWkb(node_geom)
					node_geom_json = ogr.Geometry.ExportToJson(node_geom)

					#add the wkb and json versions to the node attributes
					node_attrs["Wkb"] = node_geom_wkb
					node_attrs["Wkt"] = node_geom_wkt
					node_attrs["Json"] = node_geom_json

				if 'geom' in node_attrs:
					del node_attrs['geom']

				#assign correct data types to node attributes
				for column in node_attrs:
					if column in node_data_types:

						if node_attrs[column] not in disallowed_values:
							if node_data_types[column] == str:
								node_attrs[column] = str(node_attrs[column])

							if node_data_types[column] == int:
								node_attrs[column] = int(node_attrs[column])

							if node_data_types[column] == float:
								node_attrs[column] = float(node_attrs[column])

				#add the node to the network, with attributes
				net.add_node(node_coord_tuple, node_attrs)

		#close the node csv file
		node_csv_file.close()
		del node_csv_file

		if multigraph:
			temp_edgeid_uuid_lookup = {}

			for temp_edge_row in temp_edge_csv_reader:
				temp_edgeid_uuid_lookup[int(temp_edge_row['EdgeID'])] = temp_edge_row['uuid']
			#start again
			temp_edge_csv_file.close()
			del temp_edge_csv_reader
			del temp_edge_csv_file

		#need to check that the edge_geometry csv file header contains at least the minimum edge_geometry fieldnames
		edge_geometry_first_line = True
		missing_edge_geometry_fieldname = False
		edge_geometry_first_line_contents = []

		coords = {}
		#need some way of being able to attach the correct edge geometry wkt, wkb and json version of the geometry to the attributes of the correct edge
		#edge Edge_GeomID should match GeomID of edge_geometry
		#loop rows in edge geometry table

		edge_geometry_row_counter = 0

		for edge_geometry_row in edge_geometry_csv_reader:
			edge_geometry_row_counter = edge_geometry_row_counter + 1
			if edge_geometry_first_line == True:
				edge_geometry_first_line_contents = edge_geometry_row
				edge_geometry_first_line = False
				for generic_edge_geometry_fieldname in generic_edge_geometry_fieldnames:
					if generic_edge_geometry_fieldname not in edge_geometry_row:
						raise Error('The field name %s does not exist in the input edge geometry csv file (%s)' % (generic_edge_geometry_fieldname, edge_geometry_csv_file_name))
						missing_edge_geometry_fieldname = True
					break;
				if missing_edge_geometry_fieldname == True:
					edge_geometry_csv_file.close()
					raise Error('A mandatory edge geometry field name (one of %s) is missing from input edge geometry csv file (%s)' % (generic_edge_geometry_fieldnames, edge_geometry_csv_file_name))
					break;
				else:
					#grab the geomid
					edge_geometry_geom_id = int(edge_geometry_row['GeomID'])

					#grab the edge_geometry attributes
					edge_geometry_attrs = edge_geometry_row

					#grab the edge geometry
					if 'geom_text' in edge_geometry_attrs:
						edge_geometry_wkt_raw = edge_geometry_attrs['geom_text']
					elif 'geom' in edge_geometry_attrs:
						edge_geometry_wkt_raw = edge_geometry_attrs['geom']
					else:
						raise Error('When reading a network back from csv files, the geometry of the edges must be contained as WKT string representation e.g. srid=27700;LINESTRING(0 0), in a column named either "geom_text" or "geom"')

					edge_geometry_srid = edge_geometry_wkt_raw[1:edge_geometry_wkt_raw.find(';')]
					edge_geometry_wkt = edge_geometry_wkt_raw[edge_geometry_wkt_raw.find(';')+1:len(edge_geometry_wkt_raw)-2]

					#if not empty geom
					if edge_geometry_wkt.find('EMPTY') == -1:

						#create an OGR LineString geometry
						edge_geometry = ogr.CreateGeometryFromWkt(edge_geometry_wkt)
						edge_geometry_wkb = ogr.Geometry.ExportToWkb(edge_geometry)
						edge_geometry_json = ogr.Geometry.ExportToJson(edge_geometry)

						#get the first point of the edge
						node_from_geom = edge_geometry.GetPoint_2D(0)
						node_from_geom_coord_tuple = (node_from_geom[0], node_from_geom[1])

						#count the number of points in the edge
						n = edge_geometry.GetPointCount()

						#get the last point of the edge
						node_to_geom = edge_geometry.GetPoint_2D(n-1)
						node_to_geom_coord_tuple = (node_to_geom[0], node_to_geom[1])

						#assign edge attributes
						edge_geometry_attrs["Wkb"] = edge_geometry_wkb
						edge_geometry_attrs["Wkt"] = edge_geometry_wkt
						edge_geometry_attrs["Json"] = edge_geometry_json

						#NEW
						if 'geom' in edge_geometry_attrs:
							del edge_geometry_attrs['geom']

						if multigraph:
							uuid = temp_edgeid_uuid_lookup[edge_geometry_attrs['GeomID']]
							net.add_edge(node_from_geom_coord_tuple, node_to_geom_coord_tuple, uuid, edge_geometry_attrs)
						else:
							#add the edge with the attributes from edge_geometry csv file
							net.add_edge(node_from_geom_coord_tuple, node_to_geom_coord_tuple, edge_geometry_attrs)

						coords[edge_geometry_geom_id] = [node_from_geom_coord_tuple, node_to_geom_coord_tuple]
					else:
						raise Error('An empty geometry within the edge geometry csv input file has been found. Please ensure that no empty geometries are supplied to this function.')
			#process the rest of the file
			else:

				#grab the geomid
				edge_geometry_geom_id = int(edge_geometry_row['GeomID'])

				#grab the edge_geometry attributes
				edge_geometry_attrs = edge_geometry_row

				#grab the edge geometry
				if 'geom_text' in edge_geometry_attrs:
					edge_geometry_wkt_raw = edge_geometry_attrs['geom_text']
				elif 'geom' in edge_geometry_attrs:
					edge_geometry_wkt_raw = edge_geometry_attrs['geom']
				else:
					raise Error('When reading a network back from csv files, the geometry of the edges must be contained as WKT string representation e.g. srid=27700;LINESTRING(0 0), in a column named either "geom_text" or "geom"')

				edge_geometry_srid = edge_geometry_wkt_raw[1:edge_geometry_wkt_raw.find(';')]
				edge_geometry_wkt = edge_geometry_wkt_raw[edge_geometry_wkt_raw.find(';')+1:len(edge_geometry_wkt_raw)-2]

				#if not empty geom
				if edge_geometry_wkt.find('EMPTY') == -1:

					#create an OGR LineString geometry
					edge_geometry = ogr.CreateGeometryFromWkt(edge_geometry_wkt)
					edge_geometry_wkb = ogr.Geometry.ExportToWkb(edge_geometry)
					edge_geometry_json = ogr.Geometry.ExportToJson(edge_geometry)

					#get the first point of the edge
					node_from_geom = edge_geometry.GetPoint_2D(0)
					node_from_geom_coord_tuple = (node_from_geom[0], node_from_geom[1])

					#count the number of points in the edge
					n = edge_geometry.GetPointCount()

					#get the last point of the edge
					node_to_geom = edge_geometry.GetPoint_2D(n-1)
					node_to_geom_coord_tuple = (node_to_geom[0], node_to_geom[1])

					#assign edge attributes
					edge_geometry_attrs["Wkb"] = edge_geometry_wkb
					edge_geometry_attrs["Wkt"] = edge_geometry_wkt
					edge_geometry_attrs["Json"] = edge_geometry_json

					#NEW
					if 'geom' in edge_geometry_attrs:
						del edge_geometry_attrs['geom']

					if multigraph:
						uuid = temp_edgeid_uuid_lookup[edge_geometry_attrs['GeomID']]
						net.add_edge(node_from_geom_coord_tuple, node_to_geom_coord_tuple, uuid, edge_geometry_attrs)
					else:
						#add the edge with the attributes from edge_geometry csv file
						net.add_edge(node_from_geom_coord_tuple, node_to_geom_coord_tuple, edge_geometry_attrs)

					coords[edge_geometry_geom_id] = [node_from_geom_coord_tuple, node_to_geom_coord_tuple]
				else:
					raise Error('An empty geometry within the edge geometry csv input file has been found. Please ensure that no empty geometries are supplied to this function.')

		#close the edge geometry csv file
		edge_geometry_csv_file.close()
		del edge_geometry_csv_file

		#need to check that the edge csv file header contains at least the minimum generic edge fieldnames
		edge_first_line = True
		missing_edge_fieldname = False
		edge_first_line_contents = []

		#if edges have been added using the coordinates as the identifier
		if ((len(coords) > 0) or (len(net.edges()) > 0)):
			#loop rows in the edge table
			for edge_row in edge_csv_reader:
				if edge_first_line == True:
					edge_first_line_contents = edge_row
					edge_first_line = False
					for generic_edge_fieldname in generic_edge_fieldnames:
						if generic_edge_fieldname not in edge_row:
							raise Error('The field name %s does not exist in the input edge csv file (%s)' % (generic_edge_fieldname, edge_csv_file_name))
							missing_edge_fieldname = True
						break;
					if missing_edge_fieldname == True:
						edge_csv_file.close()
						raise Error('A mandatory edge field name (one of %s) is missing from input edge csv file (%s)' % (generic_edge_fieldnames, edge_csv_file_name))
						break;
					else:
						#grab the edge_geomid
						edge_geom_id = int(edge_row['Edge_GeomID'])
						#grab the attributes for that edge
						edge_attrs = edge_row

						if 'edgeid' in edge_attrs:
							del edge_attrs['edgeid']

						if 'geomid' in edge_attrs:
							del edge_attrs['geomid']

						matched_edge_tuples = coords[edge_geom_id]

						if not multigraph:
							current_matched_edge_attributes = net[matched_edge_tuples[0]][matched_edge_tuples[1]]
						else:
							uuid = temp_edgeid_uuid_lookup[edge_geom_id]
							current_matched_edge_attributes = net[matched_edge_tuples[0]][matched_edge_tuples[1]][uuid]

						new_edge_attributes = dict(current_matched_edge_attributes, **edge_attrs)

						#assign correct data types to edge attributes
						for column in new_edge_attributes:
							if column in edge_data_types:
								if new_edge_attributes[column] not in disallowed_values:

									if edge_data_types[column] == str:
										new_edge_attributes[column] = str(new_edge_attributes[column])

									if edge_data_types[column] == int:
										new_edge_attributes[column] = int(new_edge_attributes[column])

									if edge_data_types[column] == float:
										new_edge_attributes[column] = float(new_edge_attributes[column])

						if multigraph:
							uuid = temp_edgeid_uuid_lookup[edge_geom_id]

							###NEW
							net.remove_edge(matched_edge_tuples[0], matched_edge_tuples[1], uuid)
							net.add_edge(matched_edge_tuples[0], matched_edge_tuples[1], uuid, new_edge_attributes)

						else:

							###NEW
							net.remove_edge(matched_edge_tuples[0], matched_edge_tuples[1])
							net.add_edge(matched_edge_tuples[0], matched_edge_tuples[1], new_edge_attributes)

				#process the rest of the file
				else:
					#grab the edge_geomid
					edge_geom_id = int(edge_row['Edge_GeomID'])
					#grab the attributes for that edge
					edge_attrs = edge_row

					if 'edgeid' in edge_attrs:
						del edge_attrs['edgeid']

					if 'geomid' in edge_attrs:
						del edge_attrs['geomid']

					matched_edge_tuples = coords[edge_geom_id]

					if not multigraph:
						current_matched_edge_attributes = net[matched_edge_tuples[0]][matched_edge_tuples[1]]
					else:
						uuid = temp_edgeid_uuid_lookup[edge_geom_id]
						current_matched_edge_attributes = net[matched_edge_tuples[0]][matched_edge_tuples[1]][uuid]

					new_edge_attributes = dict(current_matched_edge_attributes, **edge_attrs)

					#assign correct data types to edge attributes
					for column in new_edge_attributes:
						if column in edge_data_types:
							if new_edge_attributes[column] not in disallowed_values:
								if edge_data_types[column] == str:
									new_edge_attributes[column] = str(new_edge_attributes[column])

								if edge_data_types[column] == int:
									new_edge_attributes[column] = int(new_edge_attributes[column])

								if edge_data_types[column] == float:
									new_edge_attributes[column] = float(new_edge_attributes[column])

					if multigraph:
						uuid = temp_edgeid_uuid_lookup[edge_geom_id]

						###NEW
						net.remove_edge(matched_edge_tuples[0], matched_edge_tuples[1], uuid)
						net.add_edge(matched_edge_tuples[0], matched_edge_tuples[1], uuid, new_edge_attributes)

					else:

						###NEW
						net.remove_edge(matched_edge_tuples[0], matched_edge_tuples[1])
						net.add_edge(matched_edge_tuples[0], matched_edge_tuples[1], new_edge_attributes)

		#no edges have been added because the edge geometries supplied are all blank edges
		else:
			for edge_row in edge_csv_reader:
				if edge_first_line == True:
					edge_first_line_contents = edge_row
					edge_first_line = False
					for generic_edge_fieldname in generic_edge_fieldnames:
						if generic_edge_fieldname not in edge_row:
							raise Error('The field name %s does not exist in the input edge csv file (%s)' % (generic_edge_fieldname, edge_csv_file_name))
							missing_edge_fieldname = True
						break;
					if missing_edge_fieldname == True:
						edge_csv_file.close()
						raise Error('A mandatory edge field name (one of %s) is missing from input edge csv file (%s)' % (generic_edge_fieldnames, edge_csv_file_name))
						break;
					else:
						edge_geom_id = edge_row['Edge_GeomID']
						edge_attrs = edge_row

						if 'edgeid' in edge_attrs:
							del edge_attrs['edgeid']

						if 'geomid' in edge_attrs:
							del edge_attrs['geomid']

						node_f_id = edge_attrs['Node_F_ID']
						node_t_id = edge_attrs['Node_T_ID']

						#assign correct data types for edge attributes
						for column in edge_attrs:
							if column in edge_data_types:
								if edge_attrs[column] not in disallowed_values:
									if edge_data_types[column] == str:
										edge_attrs[column] = str(edge_attrs[column])

									if edge_data_types[column] == int:
										edge_attrs[column] = int(edge_attrs[column])

									if edge_data_types[column] == float:
										edge_attrs[column] = float(edge_attrs[column])

						if multigraph:
							uuid = edge_attrs['uuid']
							net.add_edge(node_f_id, node_t_id, uuid, edge_attrs)
						else:
							net.add_edge(node_f_id, node_t_id, edge_attrs)
				else:
					edge_geom_id = edge_row['Edge_GeomID']
					edge_attrs = edge_row

					if 'edgeid' in edge_attrs:
						del edge_attrs['edgeid']

					if 'geomid' in edge_attrs:
						del edge_attrs['geomid']

					node_f_id = edge_attrs['Node_F_ID']
					node_t_id = edge_attrs['Node_T_ID']

					#assign correct data types for edge attributes
					for column in edge_attrs:
						if column in edge_data_types:
							if edge_attrs[column] not in disallowed_values:
								if edge_data_types[column] == str:
									edge_attrs[column] = str(edge_attrs[column])

								if edge_data_types[column] == int:
									edge_attrs[column] = int(edge_attrs[column])

								if edge_data_types[column] == float:
									edge_attrs[column] = float(edge_attrs[column])

					if multigraph:
						uuid = edge_attrs['uuid']
						net.add_edge(node_f_id, node_t_id, uuid, edge_attrs)
					else:
						net.add_edge(node_f_id, node_t_id, edge_attrs)

		#close the edge csv file
		edge_csv_file.close()
		del edge_csv_file

		return net


class write:
	'''Class to write NetworkX instance to PostGIS network schema tables.'''

	def __init__(self, db_conn):
		'''Setup connection to be inherited by methods.

		db_conn - OGR connection

		'''
		self.conn = db_conn
		if self.conn == None:
			raise Error('No connection to database.')

	def getlayer(self, tablename):
		'''Get a PostGIS table by name and return as OGR layer.

		   Else, return None.

		   tablename - string - name of table to return as OGR Layer

		   '''

		sql = "SELECT * from pg_tables WHERE tablename = '%s'" % tablename

		for row in self.conn.ExecuteSQL(sql):
			if row.tablename is None:
				return None
			else:
				return self.conn.GetLayerByName(tablename)

	def netgeometry(self, key, data):
		'''Create OGR geometry from a NetworkX Graph using Wkb/Wkt attributes.

		key - could be str or tuple
		data - attribute dictionary

		'''

		# Borrowed from nx_shp.py.
		if 'Wkt' in data:
			geom = ogr.CreateGeometryFromWkt(data['Wkt'])
		elif 'Wkb' in data:
			geom = ogr.CreateGeometryFromWkb(str(data['Wkb']))
		#elif type(key[0]) == 'tuple': # edge keys are packed tuples
		#CHANGED FOR FIXING PAJEK IMPORT (29/11/2012)
		elif ((type(key[0]) == 'tuple') or (type(key[0]) == tuple)): # edge keys are packed tuples
			geom = ogr.Geometry(ogr.wkbLineString)
			#geom = ogr.Geometry(ogr.wkbMultiLineString)
			_from, _to = key[0], key[1]
			geom.SetPoint_2D(0, *_from)
			geom.SetPoint_2D(1, *_to)
		#CHANGED FOR FIXING GEXF IMPORT (04/12/2012)
		elif ((type(key) == 'str') or (type(key) == str)):
			coordinate_tuple = eval(key)
			geom = ogr.Geometry(ogr.wkbPoint)
			geom.SetPoint_2D(0, *coordinate_tuple)
		#CHANGED FOR FIXING GEPHI IMPORT (05/12/2012)
		elif ((type(key[0]) == 'str') or (type(key[0]) == str)):
			geom = ogr.Geometry(ogr.wkbLineString)
			_from, _to = eval(key[0]), eval(key[1])
			geom.SetPoint_2D(0, *_from)
			geom.SetPoint_2D(1, *_to)
		else:
			geom = ogr.Geometry(ogr.wkbPoint)
			geom.SetPoint_2D(0, *key)

		return geom

	def create_feature(self, lyr, attributes = None, geometry = None):
		'''Wrapper for OGR CreateFeature function.

		Creates a feature in the specified table with geometry and attributes.

		lyr - OGR layer to add fields to
		attributes - dict - dictionary of attributes to add to feature
		geometry - OGR Geometry - sets geometry for a feature

		'''

		feature = ogr.Feature(lyr.GetLayerDefn())
		if attributes is not None:
			for field, data in attributes.items():
				feature.SetField(field, data)
		if geometry is not None:
			feature.SetGeometry(geometry)
		lyr.CreateFeature(feature)
		feature.Destroy()

	def create_attribute_map(self, lyr, g_obj, fields):
		'''Build a dict of attribute field names, data and OGR data types.

		Accepts graph object (either node or edge), fields and
		returns attribute dictionary.

		lyr - OGR layer to add fields to
		g_obj - dict - contains data-specific fields to add to lyr
		fields - dict - contains generic node, edge or edge_geometry fields

		'''

		attrs = {}
		OGRTypes = {int:ogr.OFTInteger, str:ogr.OFTString, float:ogr.OFTReal}
		for key, data in g_obj.items():
			if (key != 'Json' and key != 'Wkt' and key != 'Wkb' and key != 'ShpName' and key != 'NodeID' and key != 'nodeid' and key != 'EdgeID' and key != 'edgeid' and key != 'viewid' and key != 'view_id' and key != 'ViewID' and key != 'View_ID' and key != 'GeomID' and key != 'geomid' and key != 'geom' and key != 'geom_text'):

				# Add new attributes for each feature
				if key not in fields:
					if type(data) in OGRTypes:
						fields[key] = OGRTypes[type(data)]
					else:
						fields[key] = ogr.OFTString

					newfield = ogr.FieldDefn(key, fields[key])
					lyr.CreateField(newfield)
					attrs[key] = data
				# Create dict of single feature's attributes
				else:
					attrs[key] = data
		return attrs

	def update_graph_table(self):
		'''Update the Graph table and return newly assigned Graph ID.

		graph - networkx graph

		'''
		#add a graph record based on the prefix (graph / network name)
		result = nisql(self.conn).add_graph_record(self.prefix)
		sql = ('SELECT "GraphID" FROM "Graphs" ORDER BY "GraphID" DESC LIMIT 1;')
		GraphID = None
		for row in self.conn.ExecuteSQL(sql):
			GraphID = row.GraphID
		return GraphID

	def pgnet_edge_empty_geometry(self, edge_attribute_equality_key, edge_attributes, edge_geom):
		'''Write a Edge to a Edge table, where no Edge geometry exists

		Return the newly assigned EdgeID

		edge_attribute_quality_key - string - key to an element in edge_attributes to use to check equality against database (must exist in edge_attributes)
		edge_attributes - dict - dictionary of edge attributes to add to a edge feature
		'''

		#Get table definitions
		featedge = ogr.Feature(self.lyredges.GetLayerDefn())
		featedge_geom = ogr.Feature(self.lyredge_geom.GetLayerDefn())
		featedge_geom.SetGeometry(edge_geom)

		self.lyredge_geom.CreateFeature(featedge_geom)
		sql = ('SELECT "GeomID" FROM "%s" ORDER BY "GeomID" DESC LIMIT 1;' % self.tbledge_geom)

		for row in self.conn.ExecuteSQL(sql):
			GeomID = row.GeomID

		# Append the GeomID to the edges attributes
		edge_attributes['Edge_GeomID'] = GeomID

		#Attributes to edges table
		##for field, data in edge_attributes.iteritems():
		for field, data in list(edge_attributes.items()):
			if type(data) == str:
				data = data.encode('utf-8')

			featedge.SetField(field, data)

		self.lyredges.CreateFeature(featedge)

	def pgnet_edge(self, edge_attributes, edge_geom):
		'''Write an edge to Edge and Edge_Geometry tables.

		edge_attributes - dictionary of edge attributes to add to edge feature
		edge_geom - OGR geometry - geometry of node to write to database

		'''
		#may need to check the type of geom field in the layer is the same as the data
		#convert linestrings to multiline strings
		'''if edge_geom.ExportToWkt()[:10] == 'LINESTRING':
			edge_geom = ogr.ForceToMultiLineString(edge_geom)'''
		#get the edge wkt
		edge_wkt = edge_geom.ExportToWkt()
		
		# Get table definitions
		featedge = ogr.Feature(self.lyredges.GetLayerDefn())
		featedge_geom = ogr.Feature(self.lyredge_geom.GetLayerDefn())

		# Test for geometry existance
		GeomID = nisql(self.conn).edge_geometry_equality_check(self.prefix, edge_wkt, self.srs)

		if GeomID == None:
			# Need to create new geometry
			featedge_geom.SetGeometry(edge_geom)
			
			self.lyredge_geom.CreateFeature(featedge_geom)
			
			#Get created edge_geom primary key (GeomID)
			sql = ('SELECT "GeomID" FROM "%s" ORDER BY "GeomID" DESC LIMIT 1;' % self.tbledge_geom)
			
			for row in self.conn.ExecuteSQL(sql):
				GeomID = row.GeomID
		
		# Append the GeomID to the edges attributes
		edge_attributes['Edge_GeomID'] = GeomID

		'''
		this is the original way but I think something is going wrong when doing this
		#Attributes to edges table
		##for field, data in edge_attributes.iteritems():
		for field, data in edge_attributes.items():
			if type(data) == unicode:
				data = data.encode('utf-8')

			featedge.SetField(field, data)
		self.lyredges.CreateFeature(featedge)
		'''
		
		#second method
	
		field_list = ''
		data_list = ''
		for field, data in list(edge_attributes.items()):

			field_list += '"%s",' %field
			if type(data) == int or type(data) == float:
				data_list += '%s,' %data
			else:
				data_list += "'%s'," %data

		sql = 'INSERT INTO "%s" (%s) VALUES (%s)' %(self.tbledges,field_list[:-1],data_list[:-1])

		self.conn.ExecuteSQL(sql)

	def pgnet_node_empty_geometry(self, node_attribute_equality_key, node_attributes, node_geom):
		'''Write a node to a Node table, where no Node geometry exists

		Return the newly assigned NodeID

		node_attribute_quality_key - string - key to an element in node_attributes to use to check equality against database (must exist in node_attributes)
		node_attributes - dict - dictionary of node attributes to add to a node feature
		'''
		NodeID = None
		if node_attribute_equality_key in node_attributes:
			NodeID = nisql(self.conn).node_attribute_equality_check(self.prefix, node_attribute_equality_key, node_attributes[node_attribute_equality_key])

			if NodeID == None: #Need to create the new feature+geometry
				featnode = ogr.Feature(self.lyrnodes_def)
				featnode.SetGeometry(node_geom)
				for field, data in node_attributes.items():
					if type(data) == str:
						data = data.encode('utf-8')

					featnode.SetField(field, data)

				self.lyrnodes.CreateFeature(featnode)

				sql = ('SELECT "NodeID" FROM "%s" ORDER BY "NodeID" DESC LIMIT 1;' % self.tblnodes)

				for row in self.conn.ExecuteSQL(sql):
					NodeID = row.NodeID

			return NodeID

		else:
			raise Error('The specified attribute (%s) does not exist in the current set of Node attributes (%s)'% (node_attribute_equality_key, node_attributes))


	def pgnet_node(self, node_attributes, node_geom):
		'''Write a node to a Node table.

		Return the newly assigned NodeID.

		node_attributes - dict - dictionary of node attributes to add to a node feature
		node_geom - OGR geometry - geometry of node to write to database

		'''
		NodeID = nisql(self.conn).node_geometry_equality_check(self.prefix,node_geom,self.srs)

		if NodeID == None: # Need to create new geometry:
			featnode = ogr.Feature(self.lyrnodes_def)
			featnode.SetGeometry(node_geom)

			for field, data in node_attributes.items():
				#added to handle when reading back in from graphml or similar
				if type(data) == str:
					data = data.encode('utf-8')

				featnode.SetField(field, data)

			self.lyrnodes.CreateFeature(featnode)

			# getting node id
			sql = ('SELECT "NodeID" FROM "%s" ORDER BY "NodeID" DESC LIMIT 1;' % self.tblnodes)
			for row in self.conn.ExecuteSQL(sql):
				NodeID = row.NodeID

		return NodeID

	def pgnet(self, network, tablename_prefix, srs=27700, overwrite=False, directed = False, multigraph = False, node_equality_key='geom', edge_equality_key='geom'):

		'''Write NetworkX instance to PostGIS network schema tables.

		Updates Graph table with new network.

		Note that schema constrains must be applied in database.
		There are no checks for database errors here.

		network - networkx network
		tablename_prefix - string - name to give to graph / network when stored in the database
		srs - integer - epsg code of input graph / network (if srs = -1, then aspatial network being written)
		overwrite - boolean - true to overwrite graph / network of same name in database, false otherwise
		directed - boolean - true to write a directed graph / network, false otherwise
		multigraph - boolean - true to write a multigraph, false otherwise

		'''

		# Disable pg use copy or NodeID not-null error will be raised
		if gdal.GetConfigOption("PG_USE_COPY") == "YES":
			raise Error('Attempting to write database schema with GDAL option '
						'"PG_USE_COPY=YES". Please do: '
						'gdal.SetConfigOption("PG_USE_COPY", "NO") and reset '
						'database connection.')

		# First create network tables in database
		self.prefix = tablename_prefix
		self.tbledges = tablename_prefix+'_Edges'
		self.tblnodes = tablename_prefix+'_Nodes'
		self.tbledge_geom = tablename_prefix+'_Edge_Geometry'
		self.srs = srs

		result = nisql(self.conn).create_network_tables(self.prefix, self.srs, directed, multigraph)

		#check if network tables were created
		if result == 0 or result == None:
			if overwrite is True:
				nisql(self.conn).delete_network(self.prefix)
				result = nisql(self.conn).create_network_tables(self.prefix, self.srs, directed, multigraph)
				if result == None:
					raise Error('Could not create network tables in database.')
			else:
				raise Error('Network already exists.')

		G = network # Use G as network, networkx convention.

		#grab graph / network id from database
		graph_id = self.update_graph_table()
		self.graph_id = graph_id
		if graph_id == None:
	     		raise Error('Could not load network from Graphs table.')

		self.lyredges = self.getlayer(self.tbledges)
		self.lyrnodes = self.getlayer(self.tblnodes)
		self.lyredge_geom = self.getlayer(self.tbledge_geom)
		self.lyrnodes_def =  self.lyrnodes.GetLayerDefn()

		#define default field types for Node and Edge fields
		node_fields = {'GraphID':ogr.OFTInteger}
		edge_fields = {'Node_F_ID':ogr.OFTInteger, 'Node_T_ID':ogr.OFTInteger, 'GraphID':ogr.OFTInteger, 'Edge_GeomID':ogr.OFTInteger}
		
		for e in G.edges(data=True):
			if not multigraph:
				data = G.get_edge_data(*e)
			else:
				data = G.get_edge_data(e[0], e[1], e[2]['uuid'])

			# Insert the start node
			node_attrs = self.create_attribute_map(self.lyrnodes, G.node[e[0]], node_fields)
			node_attrs['GraphID'] = graph_id

			#delete view_id and nodeid if exist as attributes of node
			if 'view_id' in node_attrs:
				del node_attrs['view_id']
			if 'nodeid' in node_attrs:
				del node_attrs['nodeid']
			
			if srs != -1:
				#grab the node geometry
				node_geom = self.netgeometry(e[0], G.node[e[0]])
				#write the geometry to the database, and return the id
				node_f_id = self.pgnet_node(node_attrs, node_geom)
				if node_f_id == None:
					print('Leaving code here as from id is none')
					exit()

			else:
				node_geom = self.netgeometry(e[0], {'Wkt':'POINT EMPTY'})

				#write the geometry to the database, and return the id
				node_f_id = self.pgnet_node_empty_geometry(node_equality_key, node_attrs, node_geom)

			#in case something goes wrong
			if node_f_id == None:
				print('Exiting code here as from id is none.')
				exit()
			#set edge from id
			G[e[0]][e[1]]['Node_F_ID'] = node_f_id

			#reset NodeID (NEW)
			G[e[0]]['NodeID'] = node_f_id

			#if node_attrs.has_key('NodeID'): # NEW
			node_attrs['NodeID'] = node_f_id

			# Insert the end node
			node_attrs = self.create_attribute_map(self.lyrnodes, G.node[e[1]], node_fields)
			#node_attrs = node_fields
			node_attrs['GraphID'] = graph_id


			#delete view_id and nodeid if exist as attributes of node
			if 'view_id' in node_attrs:
				del node_attrs['view_id']
			if 'nodeid' in node_attrs:
				del node_attrs['nodeid']
			
			if srs != -1:
				#grab the node geometry
				node_geom = self.netgeometry(e[1], G.node[e[1]])

				#write the geometry to the database, and return the id
				node_t_id = self.pgnet_node(node_attrs, node_geom)

			else:
				node_geom = self.netgeometry(e[1], {'Wkt':'POINT EMPTY'})

				#write the geometry to the database, and return the id
				node_t_id = self.pgnet_node_empty_geometry(node_equality_key, node_attrs, node_geom)

			#set edge to id
			G[e[0]][e[1]]['Node_T_ID'] = node_t_id

			G[e[1]]['Node_T_ID'] = node_t_id

			#reset NodeID (NEW)
			node_attrs['NodeID'] = node_t_id

			# Set graph id.
			G[e[0]][e[1]]['GraphID'] = graph_id

			#set the edge attributes
			edge_attrs = self.create_attribute_map(self.lyredges, e[2], edge_fields)


			if 'edgeid' in edge_attrs:
				del edge_attrs['edgeid']
			if 'geomid' in edge_attrs:
				del edge_attrs['geomid']

			#NEW
			if 'Node_F_ID' in edge_attrs:
				edge_attrs['Node_F_ID'] = node_f_id
			if 'Node_T_ID' in edge_attrs:
				edge_attrs['Node_T_ID'] = node_t_id
			if 'GraphID' in edge_attrs:
				edge_attrs['GraphID'] = self.graph_id
			
			if srs != -1:

				#define the edge geometry
				edge_geom = self.netgeometry(e, data)

				#add the edge and attributes to the database
				self.pgnet_edge(edge_attrs, edge_geom)
			else:
				edge_geom = self.netgeometry(e, {'Wkt':'LINESTRING EMPTY'})

				#add the edge and attributes to the database
				self.pgnet_edge_empty_geometry(edge_equality_key, edge_attrs, edge_geom)

		#execute create node view
		nisql(self.conn).create_node_view(self.prefix)

		#execute create edge view
		nisql(self.conn).create_edge_view(self.prefix)

	def add_attribute_fields(self, lyr, g_obj, fields):
		'''
		function to add fields to a layer

		lyr - OGR layer to add fields to
		g_obj - dict - contains data-specific fields to add to lyr
		fields - dict - contains generic node, edge or edge_geometry fields

		'''
		attrs = {}
		OGRTypes = {int:ogr.OFTInteger, str:ogr.OFTString, float:ogr.OFTReal}
		for key, data in g_obj.items():
			if (key != 'Json' and key != 'Wkt' and key != 'Wkb' and key != 'ShpName' and key != 'nodeid' and key != 'edgeid' and key != 'viewid' and key != 'view_id' and key != 'geomid' and key != 'GeomID' and key != 'EdgeID' and key != 'NodeID' and key != 'geom_text'):
				if key not in fields:
					if type(data) in OGRTypes:
						fields[key] = OGRTypes[type(data)]
					else:
						fields[key] = ogr.OFTString
					newfield = ogr.FieldDefn(key, fields[key])
					lyr.CreateField(newfield)
					attrs[key] = data
				else:
					attrs[key] = data

		return attrs

	def pgnet_via_csv(self, network, tablename_prefix, srs=27700, overwrite=False, directed = False, multigraph = False, output_csv_folder='D://Spyder//NetworkInterdependency//network_scripts//pgnet_via_csv//'):

		'''
		function to write networkx network instance (network) to the database schema, via COPY from CSV

		NOTE: Nodes and Edges must have none EMPTY geometries i.e. this can only be used with a spatial network

		- node table written out as csv (to output_csv_folder + tablename_prefix + '_Nodes' e.g. OSMeridian2_Rail_CSV_w_nt_Nodes.csv)
		- edge table written out as csv (to output_csv_folder + tablename_prefix + '_Edges' e.g. OSMeridian2_Rail_CSV_w_nt_Edges.csv)
		- edge_geometry table written out as csv (to output_csv_folder + tablename_prefix + '_Edge_Geometry' e.g. OSMeridian2_Rail_CSV_w_nt_Edge_Geometry.csv)
		- use PostgreSQL COPY command to copy csv file to PostGIS / PostgreSQL tables

		network - networkx graph/network
		tablename_prefix - string - name to give as prefix to network tables created in database
		srs - integer - epsg code for coordinate system of graph/network
		overwrite - boolean - true to overwrite network of same name, false otherwise
		directed - boolean - true to denote a directed graph/network, false otherwise
		multigraph - boolean - true to denote a multigraph, false otherwise
		output_csv_folder - string - path to folder on disk, where intermediate csv files can be written to
		'''

		# Disable pg use copy or NodeID not-null error will be raised
		if gdal.GetConfigOption("PG_USE_COPY") == "YES":
			raise Error('Attempting to write database schema with GDAL option '
						'"PG_USE_COPY=YES". Please do: '
						'gdal.SetConfigOption("PG_USE_COPY", "NO") and reset '
						'database connection.')

		#check that the output csv folder exists before proceeding
		if not os.path.isdir(output_csv_folder):
			raise Error('The output path does not exist at: %s' % (output_csv_folder))

		# First create network tables in database
		self.prefix = tablename_prefix
		self.tbledges = tablename_prefix+'_Edges'
		self.tblnodes = tablename_prefix+'_Nodes'
		self.tbledge_geom = tablename_prefix+'_Edge_Geometry'
		self.srs = srs

		#create the network tables in the database
		#this OK to leave in the CSV writing version of the function because we need the correct GraphID inside each CSV file
		result = nisql(self.conn).create_network_tables(self.prefix, self.srs, directed, multigraph)

		#create network tables
		if result == 0 or result == None:
			if overwrite is True:
				nisql(self.conn).delete_network(self.prefix)
				nisql(self.conn).create_network_tables(self.prefix, self.srs, directed, multigraph)
			else:
				raise Error('Network already exists.')

		#set the node, edge and edge_geometry tables
		self.lyredges = self.getlayer(self.tbledges)
		self.lyrnodes = self.getlayer(self.tblnodes)
		self.lyredge_geom = self.getlayer(self.tbledge_geom)

		#set the network
		G = network

		#grab the node and edge data
		node_data = G.nodes(data=True)
		edge_data = G.edges(data=True)[0]

		#stores all field names to be written to csv, which are then written to PostGIS
		node_table_fieldnames = []
		edge_table_fieldnames = []
		edge_geometry_table_fieldnames = []

		#to store fieldnames specific to the data being loaded i.e. for nodes not "GraphID", "geom", "NodeID"
		node_table_specific_fieldnames = []
		#to store fieldnames specific to the data being loaded i.e. for edges not "Node_F_ID", "Node_T_ID", "GraphID", "Edge_GeomID", "EdgeID"
		edge_table_specific_fieldnames = []

		#add the base schema fields to the node table fieldnames dict
		node_table_fieldnames.insert(0, 'GraphID')
		node_table_fieldnames.append('geom')
		node_table_fieldnames.append('NodeID')

		#define the node fields
		for key, data in node_data:
			if len(data) > 0:
				for datakey, data_ in data.items():
					if ((datakey != 'NodeID') and (datakey != 'geom') and (datakey != 'GraphID') and (datakey != 'Wkt') and (datakey != 'Wkb') and (datakey != 'Json') and (datakey != 'geom_text')):
						#NEW
						node_table_fieldnames.append(datakey)
						node_table_specific_fieldnames.append(datakey)

				break;

		#add the base schema fields to the edge table fieldnames dict
		edge_table_fieldnames.insert(0, 'Node_F_ID')
		edge_table_fieldnames.insert(1, 'Node_T_ID')
		edge_table_fieldnames.insert(2, 'GraphID')
		edge_table_fieldnames.append('Edge_GeomID')
		edge_table_fieldnames.append('EdgeID')

		#define the edge table fields
		for key in list(edge_data[2].keys()):
			if (key != 'Json' and key != 'Wkt' and key != 'Wkb' and key != 'ShpName' and key != 'Node_F_ID' and key != 'Node_T_ID' and key != 'GraphID' and key != 'Edge_GeomID' and key != 'GeomID' and key != 'EdgeID' and key != 'geom' and key != 'geom_text'):
				edge_table_fieldnames.append(key)
				edge_table_specific_fieldnames.append(key)

		#define the edge geometry table fields
		edge_geometry_table_fieldnames.append('geom')
		edge_geometry_table_fieldnames.append('GeomID')

		#define the file names and paths for csv files for nodes, edges, edge_geometry
		node_csv_filename = '%s%s.csv' % (output_csv_folder, self.tblnodes)
		edge_csv_filename = '%s%s.csv' % (output_csv_folder, self.tbledges)
		edge_geom_csv_filename = '%s%s.csv' % (output_csv_folder, self.tbledge_geom)

		#define node, edge, edge_geometry csv file
		node_csv_file = open(node_csv_filename, 'wb')
		edge_csv_file = open(edge_csv_filename, 'wb')
		edge_geom_csv_file = open(edge_geom_csv_filename, 'wb')

		#define node, edge, edge_geometry csv file writers
		node_csv_writer = csv.writer(node_csv_file, delimiter=',', quoting=csv.QUOTE_MINIMAL)
		edge_csv_writer = csv.writer(edge_csv_file, delimiter=',', quoting=csv.QUOTE_MINIMAL)
		edge_geometry_csv_writer = csv.writer(edge_geom_csv_file, delimiter=',', quoting=csv.QUOTE_MINIMAL)

		#write the headers to the node, edge and edge_geometry csv files
		node_csv_writer.writerow(node_table_fieldnames)
		edge_csv_writer.writerow(edge_table_fieldnames)
		edge_geometry_csv_writer.writerow(edge_geometry_table_fieldnames)

		#this OK to leave in the CSV writing version of the function because we need the correct GraphID inside each CSV file
		graph_id = self.update_graph_table()

		if graph_id == None:
			raise Error('Could not load network from Graphs table.')

		#defines the 'base' fields for each table type (as is seen in the schema)
		node_fields = {'GraphID':ogr.OFTInteger}
		edge_fields = {'Node_F_ID':ogr.OFTInteger, 'Node_T_ID':ogr.OFTInteger, 'GraphID':ogr.OFTInteger, 'Edge_GeomID':ogr.OFTInteger}

		#to detect first edge
		first_edge = False

		#assign 1 as default starting id for nodes and edges
		current_node_id = 1
		current_edge_id = 1

		#reset the dictionaries storing the relevant data
		#GraphID .. .. .. geom
		node_from_attrs = []
		#GraphID .. .. .. geom
		node_to_attrs = []
		#Node_F_ID, Node_T_ID, GraphID, .. .. .., Edge_GeomID, EdgeID
		edge_attrs = []
		#GeomID, geom
		edge_geometry_attrs = []

		#to store records of all
		node_ids = []
		node_coords = []

		from_check = False

		#loop all edges in the network
		for e in G.edges(data=True):
			#do we need to do this slightly differently for a directed multigraph?

			#get the data for the current edge in the network

			if not multigraph:
				data = G.get_edge_data(*e)
			else:
				data = G.get_edge_data(e[0], e[1], e[2]['uuid'])

			#get from node geometry as wkt
			node_from_geom = self.netgeometry(e[0], G.node[e[0]])
			node_from_geom_wkt = ogr.Geometry.ExportToWkt(node_from_geom)

			#get to node geometry as wkt
			node_to_geom = self.netgeometry(e[1], G.node[e[1]])
			node_to_geom_wkt = ogr.Geometry.ExportToWkt(node_to_geom)

			#from node geometry for csv file
			node_from_geom_wkt_final = 'srid=%s;%s' % (srs, node_from_geom_wkt)

			#to node geometry for csv file
			node_to_geom_wkt_final = 'srid=%s;%s' % (srs, node_to_geom_wkt)

			#increment current node id if not first edge
			if first_edge == True:
			   current_node_id = current_node_id + 1

			#test if first edge
			if first_edge == False:

				#add the edge table attributes to the edge table that are not in edge_fields
				edge_attrs_test = self.add_attribute_fields(self.lyredges, e[2], edge_fields)

				#loop until you find a node with a populated list of attributes
				for e_ in G.edges(data=True):
					if len(G.node[e_[1]]) > 0:

						#add the node table attributes to the node table that are not in node_fields
						node_attrs_test = self.add_attribute_fields(self.lyrnodes, G.node[e_[1]], node_fields)
						break;

				first_edge = True

			##dealing with from nodes
			node_from_attrs = []

			#perform check to see if node already exists
			if node_from_geom_wkt in node_coords:
				#from node already exists
				node_from_id = (node_ids[node_coords.index(node_from_geom_wkt)])
				from_check = False
			else:
				#GraphID
				node_from_attrs.append(graph_id)
				node_from_id = current_node_id
				node_ids.append(node_from_id)
				node_coords.append(node_from_geom_wkt)
				current_node_id = node_from_id
				from_check = True
				######BIG CHANGE
				node_from_attrs.append(node_from_geom_wkt_final)
				node_from_attrs.append(node_from_id)

				######BIG CHANGE
				if len(G.node[e[0]]) > 0:

					for node_table_specific_key in node_table_specific_fieldnames:
						if (node_table_specific_key in G.node[e[0]]):
							if ((node_table_specific_key != 'Json') and (node_table_specific_key != 'Wkt') and (node_table_specific_key != 'Wkb') and (node_table_specific_key != 'ShpName') and (node_table_specific_key != 'nodeid') and (node_table_specific_key != 'viewid') and (node_table_specific_key != 'GraphID') and (node_table_specific_key != 'NodeID') and (node_table_specific_key != 'geom_text')):
								node_from_attrs.append(G.node[e[0]][node_table_specific_key])

					#assign attributes related from the node from
					#for key, node_from_data in G.node[e[0]].iteritems():
						#if ((key != 'Json') and (key != 'Wkt') and (key != 'Wkb') and (key != 'ShpName') and (key != 'nodeid') and (key != 'viewid') and (key != 'GraphID') and (key != 'NodeID')):
							#node_from_attrs.append(node_from_data)
				#if there are no attributes, just fill up the array with empty values
				else:
					for item in node_table_specific_fieldnames:
						node_from_attrs.append(None)


			##dealing with to nodes
			node_to_attrs = []

			#perform check to see if node already exists
			if node_to_geom_wkt in node_coords:
				#to node already exists
				node_to_id = (node_ids[node_coords.index(node_to_geom_wkt)])
			else:
				 #GraphID
				node_to_attrs.append(graph_id)
				if from_check == True:
					node_to_id = current_node_id + 1
				else:
					node_to_id = current_node_id
				from_check = False
				node_ids.append(node_to_id)
				node_coords.append(node_to_geom_wkt)
				current_node_id = node_to_id
				######BIG CHANGE
				node_to_attrs.append(node_to_geom_wkt_final)
				node_to_attrs.append(node_to_id)

				######BIG CHANGE
				if len(G.node[e[1]]) > 0:

					#NEW
					for node_table_specific_key in node_table_specific_fieldnames:
						if (node_table_specific_key in G.node[e[1]]):
							if ((node_table_specific_key != 'Json') and (node_table_specific_key != 'Wkt') and (node_table_specific_key != 'Wkb') and (node_table_specific_key != 'ShpName') and (node_table_specific_key != 'nodeid') and (node_table_specific_key != 'viewid') and (node_table_specific_key != 'GraphID') and (node_table_specific_key != 'NodeID') and (node_table_specific_key != 'geom_text')):
								node_to_attrs.append(G.node[e[1]][node_table_specific_key])

				#if there are no attributes, just fill up the array with empty values
				else:
					for item in node_table_specific_fieldnames:
						node_to_attrs.append(None)


			edge_attrs = []
			#Node_F_ID
			edge_attrs.append(node_from_id)
			#Node_T_ID
			edge_attrs.append(node_to_id)
			#GraphID
			edge_attrs.append(graph_id)
			#Edge_GeomID
			edge_attrs.append(current_edge_id)
			#EdgeID
			edge_attrs.append(current_edge_id)

			#dealing with edge attributes ##NEW
			for edge_table_specific_key in edge_table_specific_fieldnames:
				if edge_table_specific_key in data:
					edge_attrs.append(data[edge_table_specific_key])
				else:
					edge_attrs.append(None)

			edge_geom = self.netgeometry(e, data)
			edge_geom_wkt = ogr.Geometry.ExportToWkt(edge_geom)

			#define empty edge geometry attribute dictionary
			edge_geometry_attrs = []

			#edge geometry as wkt
			edge_geom_wkt_final = 'srid=%s;%s' % (srs, str(edge_geom_wkt))

			#add wkt version of edge_geometry
			edge_geometry_attrs.append(edge_geom_wkt_final)

			#add GeomID
			edge_geometry_attrs.append(current_edge_id)

			#increment the edge id
			current_edge_id = current_edge_id + 1

			#check if node from, or node to attributes have been defined
			if ((len(node_from_attrs) == 0) and (len(node_to_attrs) == 0)):
				current_node_id = current_node_id - 1

			if len(node_from_attrs) > 0:
				#need to write the contents of the node_from_attrs to the node table
				node_csv_writer.writerow(node_from_attrs)

			if len(node_to_attrs) > 0:
				#need to write the contents of the node_to_attrs to the node table
				node_csv_writer.writerow(node_to_attrs)

			#need to write the contents of the edge_geometry_attrs to the edge_geometry table
			edge_geometry_csv_writer.writerow(edge_geometry_attrs)

			#need to write the contents of the edge_attrs to the edge table
			edge_csv_writer.writerow(edge_attrs)

		#delete dictionaries of node ids and coordinates
		del node_ids
		del node_coords

		#close csv files
		node_csv_file.close()
		edge_geom_csv_file.close()
		edge_csv_file.close()

		#checking capitals for table names
		matches = re.findall('[A-Z]', self.prefix)

		#determine if to add double-quotes to table names
		if len(matches) > 0:
			tblnodes = '"%s"' % self.tblnodes
			tbledge_geom = '"%s"' % self.tbledge_geom
			tbledges = '"%s"' % self.tbledges
		else:
			tblnodes = self.tblnodes
			tbledge_geom = self.tbledge_geom
			tbledges = self.tbledge

		#load the nodes
		node_load_sql_from_csv = "COPY %s FROM '%s' DELIMITERS ',' CSV HEADER; " % (tblnodes, node_csv_filename)
		self.conn.ExecuteSQL(node_load_sql_from_csv)

		#load the edge geometry
		edge_geometry_load_sql_from_csv = "COPY %s FROM '%s' DELIMITERS ',' CSV HEADER; " % (tbledge_geom, edge_geom_csv_filename)
		self.conn.ExecuteSQL(edge_geometry_load_sql_from_csv)

		#load the edges
		edge_sql_from_csv = "COPY %s FROM '%s' DELIMITERS ',' CSV HEADER; " % (tbledges, edge_csv_filename)
		self.conn.ExecuteSQL(edge_sql_from_csv)

		#execute create node view sql
		nisql(self.conn).create_node_view(self.prefix)

		#execute create edge view sql
		nisql(self.conn).create_edge_view(self.prefix)

	def pgnet_via_csv_empty_geometry(self, network, tablename_prefix, overwrite=False, directed = False, multigraph = False, output_csv_folder='D://Spyder//NetworkInterdependency//network_scripts//pgnet_via_csv//'):
		'''

		function to write an aspatial network to the database schema, via csv, using SQL COPY
		cannot use the standard function write -> pgnet_via_csv as this utilises the geometry of nodes and edges for equality
		NOTE: srid/srs/epsg auto-set to -1 for aspatial, so no parameter provided to call

		network - networkx network instance
		tablename_prefix - string - network name
		overwrite - boolean - true to overwrite network stored in db with same name, false otherwise.
		directed - boolean - true to state directed network being built, false otherwise
		multigraph - boolean - true to state multigraph network being built, false otherwise
		output_csv_folder - string - folder on disk to write temporary CSV files to before COPY

		'''
		# Disable pg use copy or NodeID not-null error will be raised
		if gdal.GetConfigOption("PG_USE_COPY") == "YES":
			raise Error('Attempting to write database schema with GDAL option '
						'"PG_USE_COPY=YES". Please do: '
						'gdal.SetConfigOption("PG_USE_COPY", "NO") and reset '
						'database connection.')

		#check that the output csv folder exists before proceeding
		if not os.path.isdir(output_csv_folder):
			raise Error('The output path does not exist at: %s' % (output_csv_folder))

		# First create network tables in database
		self.prefix = tablename_prefix
		self.tbledges = tablename_prefix+'_Edges'
		self.tblnodes = tablename_prefix+'_Nodes'
		self.tbledge_geom = tablename_prefix+'_Edge_Geometry'
		self.srs = -1

		#create the network tables in the database
		#this OK to leave in the CSV writing version of the function because we need the correct GraphID inside each CSV file
		result = nisql(self.conn).create_network_tables(self.prefix, self.srs, directed, multigraph)

		#create network tables
		if result == 0 or result == None:
			if overwrite is True:
				nisql(self.conn).delete_network(self.prefix)
				nisql(self.conn).create_network_tables(self.prefix, self.srs, directed, multigraph)
			else:
				raise Error('Network already exists.')

		self.lyredges = self.getlayer(self.tbledges)
		self.lyrnodes = self.getlayer(self.tblnodes)
		self.lyredge_geom = self.getlayer(self.tbledge_geom)

		#this OK to leave in the CSV writing version of the function because we need the correct GraphID inside each CSV file
		graph_id = self.update_graph_table()

		#defines the 'base' fields for each table type (as is seen in the schema)
		node_fields = {'GraphID':ogr.OFTInteger}
		edge_fields = {'Node_F_ID':ogr.OFTInteger, 'Node_T_ID':ogr.OFTInteger, 'GraphID':ogr.OFTInteger, 'Edge_GeomID':ogr.OFTInteger}

		#set the network
		G = network

		#grab the node and edge data
		node_data = G.nodes(data=True)
		edge_data = G.edges(data=True)[2]

		#stores all field names to be written to csv, which are then written to PostGIS
		node_table_fieldnames = []
		edge_table_fieldnames = []
		edge_geometry_table_fieldnames = []

		#to store fieldnames specific to the data being loaded i.e. for nodes not "GraphID", "geom", "NodeID"
		node_table_specific_fieldnames = []
		#to store fieldnames specific to the data being loaded i.e. for edges not "Node_F_ID", "Node_T_ID", "GraphID", "Edge_GeomID", "EdgeID"
		edge_table_specific_fieldnames = []

		#add the base schema fields to the node table fieldnames dict
		node_table_fieldnames.insert(0, 'GraphID')
		node_table_fieldnames.append('geom')
		node_table_fieldnames.append('NodeID')

		first_edge = False

		for edge in G.edges(data=True):
			#test if first edge
			if first_edge == False:
				#add the edge table attributes to the edge table that are not in edge_fields
				edge_attrs_test = self.add_attribute_fields(self.lyredges, edge[2], edge_fields)
				#loop until you find a node with a populated list of attributes
				for edge_ in G.edges(data=True):
					if len(G.node[edge_[1]]) > 0:
						#add the node table attributes to the node table that are not in node_fields
						node_attrs_test = self.add_attribute_fields(self.lyrnodes, G.node[edge_[1]], node_fields)
						break;
				first_edge = True
			else:
				break;

		#define the node fields
		for key, data in node_data:
			if len(data) > 0:
				for datakey, data_ in data.items():
					if datakey != 'ShpName' and datakey != 'Wkt' and datakey != 'Wkb' and datakey != 'Json':
						if datakey not in node_table_fieldnames:
							node_table_fieldnames.append(datakey)
						if datakey not in node_table_specific_fieldnames:
							node_table_specific_fieldnames.append(datakey)
				break;

		#add the base schema fields to the edge table fieldnames dict
		edge_table_fieldnames.insert(0, 'Node_F_ID')
		edge_table_fieldnames.insert(1, 'Node_T_ID')
		edge_table_fieldnames.insert(2, 'GraphID')
		edge_table_fieldnames.append('Edge_GeomID')
		edge_table_fieldnames.append('EdgeID')

		#define the edge table fields
		for key in list(edge_data[2].keys()):
			if (key != 'Json' and key != 'Wkt' and key != 'Wkb' and key != 'ShpName' and key != 'geomid' and key != 'GeomID'):
				if key not in edge_table_fieldnames:
					edge_table_fieldnames.append(key)
				if key not in edge_table_specific_fieldnames:
					edge_table_specific_fieldnames.append(key)

		#define the edge geometry table fields
		edge_geometry_table_fieldnames.append('geom')
		edge_geometry_table_fieldnames.append('GeomID')

		#define the file names and paths for csv files for nodes, edges, edge_geometry
		node_csv_filename = '%s%s.csv' % (output_csv_folder, self.tblnodes)
		edge_csv_filename = '%s%s.csv' % (output_csv_folder, self.tbledges)
		edge_geom_csv_filename = '%s%s.csv' % (output_csv_folder, self.tbledge_geom)

		#define node, edge, edge_geometry csv file
		node_csv_file = open(node_csv_filename, 'wb')
		edge_csv_file = open(edge_csv_filename, 'wb')
		edge_geom_csv_file = open(edge_geom_csv_filename, 'wb')

		#define node, edge, edge_geometry csv file writers
		node_csv_writer = csv.writer(node_csv_file, delimiter=',', quoting=csv.QUOTE_MINIMAL)
		edge_csv_writer = csv.writer(edge_csv_file, delimiter=',', quoting=csv.QUOTE_MINIMAL)
		edge_geometry_csv_writer = csv.writer(edge_geom_csv_file, delimiter=',', quoting=csv.QUOTE_MINIMAL)

		#write the headers to the node, edge and edge_geometry csv files
		node_csv_writer.writerow(node_table_fieldnames)
		edge_csv_writer.writerow(edge_table_fieldnames)
		edge_geometry_csv_writer.writerow(edge_geometry_table_fieldnames)

		if graph_id == None:
			raise Error('Could not load network from Graphs table.')

		#defines the 'base' fields for each table type (as is seen in the schema)
		node_fields = {'GraphID':ogr.OFTInteger}
		edge_fields = {'Node_F_ID':ogr.OFTInteger, 'Node_T_ID':ogr.OFTInteger, 'GraphID':ogr.OFTInteger, 'Edge_GeomID':ogr.OFTInteger}

		#to detect first edge
		first_edge = False

		#assign 1 as default starting id for nodes and edges
		current_node_id = 1
		current_edge_id = 1

		#reset the dictionaries storing the relevant data
		node_attrs = []

		#Node_F_ID, Node_T_ID, GraphID, .. .. .., Edge_GeomID, EdgeID
		edge_attrs = []
		#GeomID, geom
		edge_geometry_attrs = []

		#to store records of all
		node_ids = []
		node_coords = []

		from_check = False

		#loop all nodes in the network to create nodes csv file to copy
		#GraphID, geom, NodeID, other attributes
		for n in G.nodes(data=True):
			node_attrs = []
			for node_attribute in node_table_fieldnames:
				if node_attribute != 'Wkt' and node_attribute != 'Wkb' and node_attribute != 'Json' and node_attribute != 'view_id' and node_attribute != 'nodeid' and node_attribute != 'ShpName':
					if node_attribute == 'GraphID' and node_attribute in n[1]:
						node_attrs.append(graph_id)
					elif node_attribute == 'geom':
						node_attrs.append('srid=-1;POINT EMPTY')
					elif node_attribute == 'NodeID' and node_attribute in n[1]:
						node_attrs.append(n[1][node_attribute])
					else:
						if node_attribute in n[1]:
							node_attrs.append(n[1][node_attribute])

			if len(node_attrs) > 0:
				#need to write the contents of the node_to_attrs to the node table
				node_csv_writer.writerow(node_attrs)

		#loop all edges in the network to create edges and edge geometry csv file to copy
		for e in G.edges(data=True):
			edge_attrs = []
			edge_geometry_attrs = []
			if not multigraph:
				data = G.get_edge_data(*e)
			else:
				data = G.get_edge_data(e[0], e[1], e[2]['uuid'])

			for edge_attribute in edge_table_fieldnames:
				if edge_attribute != 'Wkt' and edge_attribute != 'Wkb' and edge_attribute != 'Json' and edge_attribute != 'view_id' and edge_attribute != 'geomid' and edge_attribute != 'ShpName':
					if edge_attribute == 'GraphID' and edge_attribute in data:
						edge_attrs.insert(2, graph_id)
					elif edge_attribute == 'Node_F_ID' and edge_attribute in data:
						edge_attrs.insert(0, data[edge_attribute])
					elif edge_attribute == 'Node_T_ID' and edge_attribute in data:
						edge_attrs.insert(1, data[edge_attribute])
					elif edge_attribute == 'Edge_GeomID' and edge_attribute in data:
						edge_attrs.insert(3, data[edge_attribute])
						edge_geometry_attrs.insert(1, data[edge_attribute])
					elif edge_attribute == 'EdgeID' and edge_attribute in data:
						edge_attrs.insert(4, data[edge_attribute])
					else:
						if edge_attribute in data:
							edge_attrs.append(data[edge_attribute])
			edge_geometry_attrs.insert(0, 'srid=-1;LINESTRING EMPTY')

			if len(edge_attrs) > 0:
				edge_csv_writer.writerow(edge_attrs)
			if len(edge_geometry_attrs) > 0:
				edge_geometry_csv_writer.writerow(edge_geometry_attrs)

		#close csv files
		node_csv_file.close()
		edge_geom_csv_file.close()
		edge_csv_file.close()

		#checking capitals for table names
		matches = re.findall('[A-Z]', self.prefix)

		#determine if to add double-quotes to table names
		if len(matches) > 0:
			tblnodes = '"%s"' % self.tblnodes
			tbledge_geom = '"%s"' % self.tbledge_geom
			tbledges = '"%s"' % self.tbledges
		else:
			tblnodes = self.tblnodes
			tbledge_geom = self.tbledge_geom
			tbledges = self.tbledge

		#load the nodes
		node_load_sql_from_csv = "COPY %s FROM '%s' DELIMITERS ',' CSV HEADER; " % (tblnodes, node_csv_filename)
		self.conn.ExecuteSQL(node_load_sql_from_csv)

		#load the edge geometry
		edge_geometry_load_sql_from_csv = "COPY %s FROM '%s' DELIMITERS ',' CSV HEADER; " % (tbledge_geom, edge_geom_csv_filename)
		self.conn.ExecuteSQL(edge_geometry_load_sql_from_csv)

		#load the edges
		edge_sql_from_csv = "COPY %s FROM '%s' DELIMITERS ',' CSV HEADER; " % (tbledges, edge_csv_filename)
		self.conn.ExecuteSQL(edge_sql_from_csv)

		#execute create node view sql
		nisql(self.conn).create_node_view(self.prefix)

		#execute create edge view sql
		nisql(self.conn).create_edge_view(self.prefix)

		#remove the node file
		if os.path.isfile(node_csv_filename):
			os.remove(node_csv_filename)

		#remove the edge geometry file
		if os.path.isfile(edge_geom_csv_filename):
			os.remove(edge_geom_csv_filename)

		#remove the edge file
		if os.path.isfile(edge_csv_filename):
			os.remove(edge_csv_filename)

	def pgnet_read_empty_geometry_from_csv_file_write_to_db(self, network, tablename_prefix, flnodes, fledges, fledge_geometry, srs=-1, overwrite=False, directed=False, multigraph=False, output_csv_folder='D://Spyder//NetworkInterdependency//network_scripts//pgnet_via_csv//'):

		'''

		it actually effectively reads the node, edge and edge_geometry files, adds the correct values for
			- GraphID in Node table file
			- GraphID in Edge table file
		then it writes it out to the database using COPY

		this is combining a read (of files) and a write (to database), but should probably remain here as it results in a network being written to

		function to upload a network containing blank geometries e.g. aspatial network, to the database schema

		network - networkx network instance
		tablename_prefix - string - network name
		flnodes - csv file of nodes
		fledges - csv file of edges
		fledge_geometry - csv file of edge geometry (simply contains ID, with empty geometry)
		srs - integer - default is -1 for blank geometry
		overwrite - boolean - false
		directed - boolean - false
		multigraph - boolean - false

		tblnodes must contain at least: NodeID, geom
		tbledges must contain at least: EdgeID, Node_F_ID, Node_T_ID, Edge_GeomID
		tbledge_geometry must contain at least: GeomID, geom

		'''
		# Disable pg use copy or NodeID not-null error will be raised
		if gdal.GetConfigOption("PG_USE_COPY") == "YES":
			raise Error('Attempting to write database schema with GDAL option '
						'"PG_USE_COPY=YES". Please do: '
						'gdal.SetConfigOption("PG_USE_COPY", "NO") and reset '
						'database connection.')

		#check that the output csv folder exists before proceeding
		if not os.path.isdir(output_csv_folder):
			raise Error('The output path does not exist at: %s' % (output_csv_folder))

		# First create network tables in database
		self.prefix = tablename_prefix
		self.tbledges = tablename_prefix+'_Edges'
		self.tblnodes = tablename_prefix+'_Nodes'
		self.tbledge_geom = tablename_prefix+'_Edge_Geometry'
		self.srs = srs

		#create the network tables in the database
		#this OK to leave in the CSV writing version of the function because we need the correct GraphID inside each CSV file
		result = nisql(self.conn).create_network_tables(self.prefix, self.srs, directed, multigraph)
		#create network tables
		if result == 0 or result == None:
			if overwrite is True:
				nisql(self.conn).delete_network(self.prefix)

				result = nisql(self.conn).create_network_tables(self.prefix, self.srs, directed, multigraph)
			else:
				raise Error('Network already exists.')

		#graph_id = nisql(self.conn).get_graph_id_by_prefix(self.prefix)
		graph_id = nisql(self.conn).get_graph_id_by_prefix(self.prefix)

		new_node_header = []
		new_edge_header = []

		#set the node, edge and edge_geometry tables
		self.lyredges = self.getlayer(self.tbledges)
		self.lyrnodes = self.getlayer(self.tblnodes)
		self.lyredge_geom = self.getlayer(self.tbledge_geom)

		#checking capitals for table names
		matches = re.findall('[A-Z]', self.prefix)

		#determine if to add double-quotes to table names
		if len(matches) > 0:
			tblnodes = '"%s"' % self.tblnodes
			tbledge_geom = '"%s"' % self.tbledge_geom
			tbledges = '"%s"' % self.tbledges
		else:
			tblnodes = self.tblnodes
			tbledge_geom = self.tbledge_geom
			tbledges = self.tbledge

		node_sql = 'COPY %s ' % tblnodes
		edge_sql = 'COPY %s ' % tbledges
		edge_geometry_sql = 'COPY %s ' % tbledge_geom

		#define default field types for Node and Edge fields
		node_fields = {'NodeID':ogr.OFTInteger}
		edge_fields = {'Node_F_ID':ogr.OFTInteger, 'Node_T_ID':ogr.OFTInteger, 'GraphID':ogr.OFTInteger, 'Edge_GeomID':ogr.OFTInteger}
		edge_geometry_fields = {'GeomID':ogr.OFTInteger}

		node_mandatory_fields = ['NodeID', 'geom']
		edge_mandatory_fields = ['EdgeID', 'Node_F_ID', 'Node_T_ID', 'Edge_GeomID']
		edge_geometry_mandatory_fields = ['GeomID', 'geom']

		OGRTypes = {int:ogr.OFTInteger, str:ogr.OFTString, float:ogr.OFTReal}

		if not os.path.isfile(flnodes):
			raise Error('The node csv file does not exist at: %s' % (flnodes))
		else:

			#open the input node file
			node_f = open(flnodes, 'r')
			node_csv_reader = csv.DictReader(node_f, delimiter=',', quoting=csv.QUOTE_MINIMAL)

			#grab the header of the file
			node_header = node_csv_reader.fieldnames

			#detect if all mandatory node fields exist
			for node_mandatory_header_item in node_mandatory_fields:
				if node_mandatory_header_item not in node_header:
					node_f.close()
					raise Error('A mandatory node field name (one of %s) is missing from input node csv file (%s)' % (node_mandatory_fields, flnodes))

			#define a new dictionary to contain the "new" header
			new_node_header = []

			#insert the GraphID attribute as the first column
			new_node_header.insert(0, 'GraphID')

			#add the other items to the header for the new node file
			for node_header_item in node_header:
				new_node_header.append(node_header_item)

			#grab the original node data from the csv reader
			node_data = list(node_csv_reader)

			#grab the first row of data from the original node file
			node_first_row_data = node_data[1]

			node_file_name_ext = os.path.splitext(os.path.basename(flnodes))

			new_node_name = '%s%s_alt%s' % (output_csv_folder, node_file_name_ext[0], node_file_name_ext[1])

			#open the new node file for writing
			new_node_f = open(new_node_name, 'wb')

			#create a new standard csv writer to copy the node data to, now with the correct value for GraphID
			new_node_file_with_graph_id = csv.writer(new_node_f, new_node_header)

			#write out the new header for the new node file
			new_node_file_with_graph_id.writerow(new_node_header)

			#copy the data from the original input node file to the new node file
			for node_data_item in node_data:
				new_node_row_to_write = []
				for new_node_header_item in new_node_header:
					if new_node_header_item in node_data_item:
						new_node_row_to_write.append(node_data_item[new_node_header_item])
					else:
						new_node_row_to_write.insert(0, graph_id)
				new_node_file_with_graph_id.writerow(new_node_row_to_write)

			#close the new node file
			new_node_f.close()

			'''node_item_counter = 0
			for node_item in node_header:
				node_match = re.findall('[A-Z]', node_item)
				#if len(node_match) > 0:
					#node_item = '"%s"' % node_item
				if node_item_counter == 0:
					node_sql = '%s%s' % (node_sql, node_item)
				elif (node_item_counter > 0 and node_item_counter < (len(node_header)-1)):
					node_sql = '%s, %s' % (node_sql, node_item)
				else:
					node_sql = '%s, %s)' % (node_sql, node_item)
				node_item_counter = node_item_counter + 1

			node_sql = "%s FROM '%s' DELIMITERS ',' CSV HEADER; " % (node_sql, flnodes)'''
			node_sql = "%s FROM '%s' DELIMITERS ',' CSV HEADER; " % (node_sql, new_node_name)

			#loop node header
			for node_header_item in node_header:
				#check if this a non-mandatory field
				if node_header_item not in node_mandatory_fields:
					value = node_first_row_data[node_header_item]

					#check the data type
					if type(value) in OGRTypes:
					   field_type = OGRTypes[type(value)]
					else:
					   field_type = ogr.OFTString

					#create a new node field type
					new_node_field = ogr.FieldDefn(node_header_item, field_type)
					#create a new node field to add to the database table
					self.lyrnodes.CreateField(new_node_field)

		if not os.path.isfile(fledges):
			raise Error('The node csv file does not exist at: %s' % (fledges))
		else:

			#open edge geometry file
			#grab header
			#check mandatory fields exist

			edge_f = open(fledges, 'r')
			edge_csv_reader = csv.DictReader(edge_f, delimiter=',', quoting=csv.QUOTE_MINIMAL)
			edge_header = edge_csv_reader.fieldnames

			#detect if all mandatory edge fields exist
			for edge_mandatory_header_item in edge_mandatory_fields:
				if edge_mandatory_header_item not in edge_header:
					edge_f.close()
					raise Error('A mandatory edge field name (one of %s) is missing from input edge csv file (%s)' % (edge_mandatory_fields, fledges))

			#define a new dictionary to contain the "new" header
			new_edge_header = []

			#add the other items to the header for the new edge file
			for edge_header_item in edge_header:
				new_edge_header.append(edge_header_item)

			#insert the GraphID attribute as the first column
			new_edge_header.insert(2, 'GraphID')

			#grab the original edge data from the csv reader
			edge_data = list(edge_csv_reader)

			#grab the first row of data from the original edge file
			edge_first_row_data = edge_data[1]

			edge_file_name_ext = os.path.splitext(os.path.basename(fledges))

			new_edge_name = '%s%s_alt%s' % (output_csv_folder, edge_file_name_ext[0], edge_file_name_ext[1])

			#open the new edge file for writing
			new_edge_f = open(new_edge_name, 'wb')

			#create a standard csv writer to copy the edge data to, now with the corret value for GraphID
			new_edge_file_with_graph_id = csv.writer(new_edge_f, new_edge_header)

			#write out the new header for the new edge file
			new_edge_file_with_graph_id.writerow(new_edge_header)

			#copy the data from the original input edge file to the new edge file
			for edge_data_item in edge_data:
				new_edge_row_to_write = []
				for new_edge_header_item in new_edge_header:
					if new_edge_header_item in edge_data_item:
						new_edge_row_to_write.append(edge_data_item[new_edge_header_item])
					else:
						new_edge_row_to_write.insert(2, graph_id)
				new_edge_file_with_graph_id.writerow(new_edge_row_to_write)

			#close the new edge file
			new_edge_f.close()

			'''edge_item_counter = 0
			for edge_item in edge_header:
				edge_match = re.findall('[A-Z]', edge_item)
				#if len(edge_match) > 0:
					#edge_item = '"%s"' % edge_item
				if edge_item_counter == 0:
					edge_sql = '%s%s' % (edge_sql, edge_item)
				elif (edge_item_counter > 0 and edge_item_counter < (len(edge_header)-1)):
					edge_sql = '%s, %s' % (edge_sql, edge_item)
				else:
					edge_sql = '%s, %s)' % (edge_sql, edge_item)
				edge_item_counter = edge_item_counter + 1

			edge_sql = "%s FROM '%s' DELIMITERS ',' CSV HEADER; " % (edge_sql, fledges)'''
			edge_sql = "%s FROM '%s' DELIMITERS ',' CSV HEADER; " % (edge_sql, new_edge_name)

			col_index = 0
			#loop edge header
			for edge_header_item in edge_header:
				col_index += 1
				#check if this a non-mandatory field
				if edge_header_item not in edge_mandatory_fields:
					value = edge_first_row_data[col_index]

					#check the data type
					if type(value) in OGRTypes:
					   field_type = OGRTypes[type(value)]
					else:
					   field_type = ogr.OFTString

					#create a new node field type
					new_edge_field = ogr.FieldDefn(edge_header_item, field_type)
					self.lyredges.CreateField(new_edge_field)

		if not os.path.isfile(fledge_geometry):
			raise Error('The node csv file does not exist at: %s' % (fledge_geometry))
		else:

			#open edge file
			#grab header
			#check mandatory fields exist

			edge_geometry_f = open(fledge_geometry)
			edge_geometry_csv_reader = csv.DictReader(edge_geometry_f, delimiter=',', quoting=csv.QUOTE_MINIMAL)
			edge_geometry_header = edge_geometry_csv_reader.fieldnames
			edge_geometry_data = list(edge_geometry_csv_reader)
			edge_geometry_first_row_data = edge_geometry_data[1]

			#detect if all mandatory edge_geometry fields exist
			for edge_geometry_header_item in edge_geometry_mandatory_fields:
				if edge_geometry_header_item not in edge_geometry_header:
					edge_geometry_f.close()
					raise Error('A mandatory edge geometry field name (one of %s) is missing from input edge geometry csv file (%s)' % (edge_geometry_mandatory_fields, fledge_geometry))

			'''edge_geometry_item_counter = 0
			for edge_geometry_item in edge_geometry_header:
				edge_geometry_match = re.findall('[A-Z]', edge_geometry_item)
				#if len(edge_geometry_match) > 0:
					#edge_geometry_item = '"%s"' % edge_geometry_item
				if edge_geometry_item_counter == 0:
					edge_geometry_sql = '%s%s' % (edge_geometry_sql, edge_geometry_item)
				elif (edge_geometry_item_counter > 0 and edge_geometry_item_counter < (len(edge_geometry_header)-1)):
					edge_geometry_sql = '%s, %s' % (edge_geometry_sql, edge_geometry_item)
				else:
					edge_geometry_sql = '%s, %s)' % (edge_geometry_sql, edge_geometry_item)
				edge_geometry_item_counter = edge_geometry_item_counter + 1'''

			edge_geometry_sql = "%s FROM '%s' DELIMITERS ',' CSV HEADER; " % (edge_geometry_sql, fledge_geometry)

			col_index = 0
			#loop edge_geometry header
			for edge_geometry_header_item in edge_geometry_header:
				col_index += 1
				#check if this a non-mandatory field
				if edge_geometry_header_item not in edge_geometry_mandatory_fields:
					value = edge_geometry_first_row_data[col_index]

					#check the data type
					if type(value) in OGRTypes:
					   field_type = OGRTypes[type(value)]
					else:
					   field_type = ogr.OFTString

					#create a new node field type
					new_edge_geometry_field = ogr.FieldDefn(edge_geometry_header_item, field_type)
					self.lyredge_geom.CreateField(new_edge_geometry_field)

		#close csv files
		node_f.close()
		edge_geometry_f.close()
		edge_f.close()

		#load the nodes
		self.conn.ExecuteSQL(node_sql)

		#remove the new node file
		if os.path.isfile(new_node_name):
			os.remove(new_node_name)

		#load the edge geometry
		self.conn.ExecuteSQL(edge_geometry_sql)

		#load the edges
		self.conn.ExecuteSQL(edge_sql)

		#remove the new node file
		if os.path.isfile(new_edge_name):
			os.remove(new_edge_name)

		#execute create node view sql
		nisql(self.conn).create_node_view(self.prefix)

		#execute create edge view sql
		nisql(self.conn).create_edge_view(self.prefix)