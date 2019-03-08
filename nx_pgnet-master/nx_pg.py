#!/usr/bin/env  python
# -*- coding: utf-8 -*-
"""
nx_pg.py - Read/write support for PostGIS tables in NetworkX

B{Introduction}

NetworkX is a python library for graph analysis. Using edge and node
attribution it can be used for spatial network analysis (with geography stored
as node/edge attributes). This module supports the use of NetworkX for the
development of network analysis of spatial networks stored in a PostGIS
spatial database by acting as an interface to node and edge tables which
contain graph nodes and edges.

B{Notes}

I{Node support}

Note that nodes are defined by the edges at network creation and the reading
of node tables independently is not currently supported (because without
defining a primary key/foreign key relationship this can easily break the
network). This issue is solved in nx_pgnet which should be used for proper
storage of networks in PostGIS tables. To read/write PostGIS networks
(as defined by a network schema use) the nx_pgnet module.

I{Output tables}

For each network written two tables are created: edges and nodes.
This representation is similar to that of the nx_shp module
(for reading/writing network shapefiles).

I{Coordinate system support}

nx_pg has no support for defining a coordinate system of the output tables.
Geometry is written without an SRS value, when viewing using a GIS you must
specify the correct coordinate system for the network, nx_pgnet has coordinate
systems support for network tables.

I{Graph/Network terms}

Note that the terms 'graph' and 'network' are used interchangeably within the
software and documentation. To some extent a 'graph' refers to a topological
object (often in memory) with none or limited attribution, whilst a 'network'
refers to a graph object with attribution of edges and nodes and with
geography defined, although this is not always the case.

B{Module structure}

The module has two key functions:
    - read_pg:
        Function to create NetworkX graph instance from PostGIS table(s)
        representing edge and node objects.
    - write_pg:
        Function to create PostGIS tables (edge and node) from NetworkX graph
        instance.

    - Other functions support the read and write operations.

B{Database connections}

Connections to PostGIS are created using the OGR simple feature library and are
passed to the read() and write() classes. See U{http://www.gdal.org/ogr}

Connections are mutually exclusive between read_pg and write_pg, although you
can of course read and write to the same database.
You must pass a valid connection to the read or write classes for the module
to work.

To create a connection using the OGR python bindings to a database
on localhost:

    >>> import osgeo.ogr as ogr
    >>> conn = ogr.Open("PG: host='127.0.0.1' dbname='database' user='postgres'
    >>>                    password='password'")

B{Examples}

The following are examples of high level read and write network operations. For
more detailed information see method documentation below.

Reading a network from PostGIS table of LINESTRINGS representing edges:

    >>> import nx_pg
    >>> import osgeo.ogr as ogr

    >>> # Create a connection
    >>> conn = ogr.Open("PG: host='127.0.0.1' dbname='database' user='postgres'
    >>>                    password='password'")

    >>> # Read a network
    >>> network = nx_pg.read_pg(conn, 'edges_tablename')

I{Adding node attributes}

Nodes are created automatically at the start/end of a line, or where there is a
break in a line. A user can add node attributes from a table of point
geometries which represent these locations. To add attributes to nodes use the
nodes_tablename option in the read function:

>>> network = nx_pg.read_pg(conn, 'edge_tablename', 'node_tablename')

This will add attributes from the node table to nodes in the network
where a network node geometry is equal to a point geometry in the specified
node table.

Note that this will not add all points in the nodes table if not all points
match the geometry of created nodes.

Also note that if two points share the same geometry as a node, only
one of the point attributes will be added (whichever occurs later
in the data).


I{Writing a NetworkX graph instance to a PostGIS schema}:

Write the network to the same database but under a different name.
Note if 'overwrite=True' then an existing network in the database of the
same name will be overwritten.

    >>> nx_pg.write_pg(conn, network, 'new_network, overwrite=False')

B{Dependencies}

    - Python 2.6 or later
    - NetworkX 1.6 or later
    - OGR 1.8.0 or later

B{Copyright}

Tomas Holderness & David Alderson, Newcastle University

Developed by Tomas Holderness & David Alderson at Newcastle University School of Civil Engineering
and Geosciences, geoinfomatics group:

Alistair Ford, Stuart Barr, Craig Robson.

B{Acknowledgement}

Acknowledgement must be made to the nx_shp developers as much of the
functionality of this module is the same.

B{License}

This software is released under a BSD style license which must be compatible
with the NetworkX license because of similarities with NetworkX source code.:

See LICENSE.TXT or type
nx_pg.license() for full details.

B{Credits}

Tomas Holderness, David Alderson, Alistair Ford, Stuart Barr and Craig Robson.


B{Contact}

tom.holderness@ncl.ac.uk\n
www.staff.ncl.ac.uk/tom.holderness

david.alderson@ncl.ac.uk\n
http://www.ncl.ac.uk/ceg/staff/profile/david.alderson

"""
__author__ = "Tom Holderness, David Alderson"
__created__ = "Thu Jan 19 15:55:13 2012"
__year__ = "2011"
__version__ = "0.9.1"

import sys
import os
import uuid
import networkx as nx
import osgeo.ogr as ogr

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

def check_encoding(value, encoding):
    '''check encoding type of string value

    value - any python value, usually a string
    encoding - string encoding representation e.g. utf-8

    '''
    if type(value) == str:
        try:
            output = value.encode(encoding)
        except UnicodeEncodeError:
            raise Error('Error whilst trying to encode %s to utf-8' % (value))
        except UnicodeDecodeError:
            raise Error('Error whilst trying to decode %s to utf-8' % (value))
        else:
            output = value
    else:
        output = value
    return output

def getfieldinfo(lyr, feature, flds):
    '''Get information about fields from a table (as OGR feature).

    lyr - layer created via OGR database connection CreateLayer method
    feature - OGR features from lyr
    flds - field name list from lyr layer

    '''

    f = feature
    values = []
    for x in flds:
        field_value = f.GetField(f.GetFieldIndex(x))

        #if type(field_value) == str:
        if isinstance(field_value, str):
            output = check_encoding(field_value, 'utf-8')
            values.append(output)
        else:
            values.append(field_value)
    #return [f.GetField(f.GetFieldIndex(x)) for x in flds]
    return values


def round_coordinate(geom, point_index, precision):
    '''
    Provide an OGR Geometry (geom=LINESTRING, geom=MULTILINESTRING), an index to the point to extract (point_index), and precision to round to (precision)

    geom - OGR geometry
    point_index - integer, point to extract from geometry (0=Node, greater than 0=Edge)
    precision - integer, coordinate precision to round geometry coordinates to

    '''
    node_coord = geom.GetPoint_2D(point_index)

    # Get the coordinate of the node and apply a precision
    node_coord_tuple=(round(node_coord[0],precision),
                  round(node_coord[1],precision))

    # return the node coordinate tuple e.g. (0, 0)
    return node_coord_tuple

def read_pg(conn, edgetable, nodetable=None, directed=False, multigraph=False, geometry_precision=2):
    '''Read a network from PostGIS table of line geometry.

       Optionally takes a table of points and where point geometry is equal
       to that of nodes created, point attributes will be added to nodes.

       directed flag indicates whether network is directed or undirected.

       geometry_precision applies the round() function to geometry of nodes (to
       fix precision errors between edge vertices and nodes). Precision is
       in the units of the geometry CRS. For example in BNG (EPSG:27700) a
       precision of 2 (default) will round to two units (i.e. the decimeter
       level).

       Returns instance of networkx.Graph().

       conn - database connection as OGR database connection
       edgetable - table name of edge table in PostGIS database to read
       nodetable - optional table name of node table in PostGIS database to read
       directed - boolean denoting whether network to create is directed (True = directed, False = undirected)
       multigraph - boolean denoting whether network to create is multigraph (True = multigraph, False = graph)
       geometry_precision - integer denoting precision to round geometry coordinates to
       '''

    if conn == None:
        raise Error('No connection to database.')

    edge_lyr = None
    for tbl in conn:
        if tbl.GetName() == edgetable:
            edge_lyr = tbl
    if edge_lyr == None:
        raise Error('Table not found in database: %s.' % (edgetable))

    #not directed, not multigraph
    if ((directed == False) and (multigraph == False)):
        net = nx.Graph()
    #not directed, multigraph
    elif ((directed == False) and (multigraph == True)):
        net = nx.MultiGraph()
    #directed, not multigraph
    elif ((directed == True) and (multigraph == False)):
        net = nx.DiGraph()
    #directed, multigraph
    elif ((directed == True) and (multigraph == True)):
        net = nx.MultiDiGraph()

    if nodetable is not None:
        nodes = {}
        for node_lyr in conn:
            if node_lyr.GetName() == nodetable:
                f = node_lyr.GetNextFeature()
                flds = [x.GetName() for x in node_lyr.schema]
                while f is not None:
                    flddata = getfieldinfo(node_lyr, f, flds )
                    attributes = dict(list(zip(flds, flddata)))

                    # Get the geometry for that feature
                    geom = f.GetGeometryRef()

                    # Check that we're dealing with point data'
                    if ogr.Geometry.GetGeometryName(geom) != 'POINT':
                        raise Error('Error:'\
                            'Node table does not contain point geometry')
                    else:
                        # Get the coordinate of the node and apply a precision
                        node_coord=round_coordinate(geom, 0, geometry_precision)
                        nodes[node_coord] = attributes

                        f = node_lyr.GetNextFeature()

    #looping the edge layer
    f = edge_lyr.GetNextFeature()
    flds = [x.GetName() for x in edge_lyr.schema]

    edge_counter = 0

    while f is not None:
        edge_counter += 1
        flddata = getfieldinfo(edge_lyr, f, flds )

        # Get the attributes for that feature
        attributes = dict(list(zip(flds, flddata)))

        # Get the geometry for that feature
        geom = f.GetGeometryRef()

        #We've got Multiline geometry so split into line segments
        #assume that the multilinestring is fully connected i.e. no gaps
        if geom is not None:
            if ((ogr.Geometry.GetGeometryName(geom) == 'MULTILINESTRING')):
                for line in geom:

                    # count the points in line
                    n = line.GetPointCount()

                    #round the coordinates of the first and last points of the line string geometry, based on the geometry precision value
                    node_coord_f = round_coordinate(line, 0, geometry_precision)
                    node_coord_t = round_coordinate(line, (n-1), geometry_precision)

                    #reset the start and the end points of the line string to correspond with the newly rounded coordinates
                    line.SetPoint_2D(0, node_coord_f[0], node_coord_f[1])
                    line.SetPoint_2D((n-1), node_coord_t[0], node_coord_t[1])

                    # set the attributes (akin to nx_shp)
                    attributes["Wkb"] = ogr.Geometry.ExportToWkb(line)
                    attributes["Wkt"] = ogr.Geometry.ExportToWkt(line)
                    attributes["Json"] = ogr.Geometry.ExportToJson(line)

                    #set the to and from node value
                    nodef = node_coord_f
                    nodet = node_coord_t

                    #check if multigraph
                    if not multigraph:
                        net.add_edge(nodef, nodet, attributes)
                    else:
                        #define a unique key (helps networkx determine the difference between two edges that start and end at the same place, but may have different attributes)
                        uuid_ = uuid.uuid4().int
                        #add the key to the attribute table of the edge, as we will need this later
                        attributes['uuid'] = uuid_
                        net.add_edge(nodef, nodet, key=uuid_, attr_dict=attributes)

            elif ogr.Geometry.GetGeometryName(geom) == 'LINESTRING':

                # count the points in line
                n = geom.GetPointCount()

                #round the coordinates of the first and last points of the line string geometry, based on the geometry precision value
                node_coord_t = round_coordinate(geom, (n-1), geometry_precision)
                node_coord_f = round_coordinate(geom, 0, geometry_precision)

                #reset the start and the end points of the line string to correspond with the newly rounded coordinates
                geom.SetPoint_2D(0, node_coord_f[0], node_coord_f[1])
                geom.SetPoint_2D((n-1), node_coord_t[0], node_coord_t[1])

                # set the attributes (akin to nx_shp)
                attributes["Wkb"] = ogr.Geometry.ExportToWkb(geom)
                attributes["Wkt"] = ogr.Geometry.ExportToWkt(geom)
                attributes["Json"] = ogr.Geometry.ExportToJson(geom)

                #set the to and from node value
                nodef = node_coord_f
                nodet = node_coord_t

                #check if multigraph
                if not multigraph:
                    net.add_edge(nodef, nodet, attributes)
                else:
                    #define a unique key (helps networkx determine the difference between two edges that start and end at the same place, but may have different attributes)
                    uuid_ = uuid.uuid4().int
                    #add the key to the attribute table of the edge, as we will need this later
                    attributes['uuid'] = uuid_
                    net.add_edge(nodef, nodet, key=uuid_, attr_dict=attributes)

            elif ogr.Geometry.GetGeometryName(geom) == 'POINT':
                net.add_node((geom.GetPoint_2D(0)), attributes)
            else:
                raise ValueError("PostGIS geometry type not"\
                                    " supported.")#

        f = edge_lyr.GetNextFeature()
        # Raise warning if nx_is_connected(G) is false.



    # Attribution of nodes from points table (must exist in network)
    if nodetable is not None:
        for point in nodes:
            if point in net.nodes():
                net.node[point] = nodes[point]

    # End of function, return the network
    return net

def netgeometry(key, data):
    '''Create OGR geometry from a NetworkX Graph using Wkb/Wkt attributes.

    key - tuple of coordinates
    data - dictionary of attributes, potentially containing Wkb/Wkt representation of geometry to create

    '''

    if 'Wkb' in data:
        geom = ogr.CreateGeometryFromWkb(data['Wkb'])
    elif 'Wkt' in data:
        geom = ogr.CreateGeometryFromWkt(data['Wkt'])
    elif type(key[0]) == 'tuple': # edge keys are packed tuples
        geom = ogr.Geometry(ogr.wkbLineString)
        _from, _to = key[0], key[1]
        geom.SetPoint_2D(0, *_from)
        geom.SetPoint_2D(1, *_to)
    else:
        geom = ogr.Geometry(ogr.wkbPoint)
        geom.SetPoint_2D(0, *key)
    return geom

def create_feature(geometry, lyr, attributes=None):
    '''Wrapper for OGR CreateFeature function.
    Creates a feature in the specified table with geometry and attributes.

    geometry - OGR geometry
    lyr - layer created in database
    attributes - attribute dictionary
    '''
    feature = ogr.Feature(lyr.GetLayerDefn())
    feature.SetGeometry(geometry)

    if attributes != None:
        for field, data in attributes.items():
            feature.SetField(field, data)

    lyr.CreateFeature(feature)

    feature.Destroy()


def write_pg(conn, network, tablename_prefix, overwrite=False):
    '''Write NetworkX instance to PostGIS edge and node tables.

    network - networkx network type
    tablename_prefix - prefix for tables written to PostGIS i.e. a name for the network
    overwrite - boolean, if true tables of same name as <tablename_prefix>_Nodes and <tablename_prefix>_Edges will be overwritten

    '''

    # Check connection
    if conn == None:
        raise Error('No connection to database.')
    # Initialise network and prefixes
    G = network

    tbledges = tablename_prefix+'_Edges'
    tblnodes = tablename_prefix+'_Nodes'

    # Overwrite details
    if overwrite is True:
        try:
            conn.DeleteLayer(tbledges)
        except:
            pass
        try:
            conn.DeleteLayer(tblnodes)
        except:
            pass

    # Create the tables for edges and nodes
    edges = conn.CreateLayer(tbledges, None, ogr.wkbLineString)
    nodes = conn.CreateLayer(tblnodes, None, ogr.wkbPoint)
    # Get node geometry
    #nodes
    for n in G:
        data = list(G.node[n].values()) or [{}]

        #why are we passing data[0] to the netgeometry function?
        #if the nodes ever have any data this will likely fail - as is the case with the gas network.

        g = netgeometry(n, data[0])
        create_feature(g, nodes)


    # Get edges and their attributes
    fields = {}
    attributes = {}
    OGRTypes = {int:ogr.OFTInteger, str:ogr.OFTString, float:ogr.OFTReal}

    #edges
    for e in G.edges(data=True):

        data = G.get_edge_data(*e)
        g = netgeometry(e, data)

        # Loop through data in edges
        #attribute key
        for key, data in e[2].items():
            # Reject data not for attribute table
            if (key != 'Json' and key != 'Wkt' and key != 'Wkb'
                and key != 'ShpName'):
                  # Add new attributes for each feature
                if key not in fields:
                    if type(data) in OGRTypes:
                        fields[key] = OGRTypes[type(data)]
                    else:
                        fields[key] = ogr.OFTString
                    newfield = ogr.FieldDefn(key, fields[key])
                    edges.CreateField(newfield)
                    attributes[key] = data
                  # Create dict of single feature's attributes
                else:
                    attributes[key] = data
         # Create the re(g, edges, attributes)
        create_feature(g, edges, attributes)
    # Destroy nodes and edges features as per OGR recommendations.
    nodes, edges = None, None
