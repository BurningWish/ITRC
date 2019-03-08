#!/usr/bin/env  python
# -*- coding: utf-8 -*-
"""
test_script.py - Script to test nx_pg and nx_pgnet read/write to PostGIS 
database and network schema.

This script builds a NetworkX instance of the lightrail network from lines 
and points files which can be found in ./data/ folder as backup files. These
tables were created using FME to convert snapped lines and points from ArcGIS
spatial database to PostGIS. Restore these to a database using the PgAdmin 
restore before running this script.

Also, the target database should have the schema loaded in order to create 
a schema instance.

Note: The settings in the database connection need to be updated.

"""
__author__ = "Tom Holderness"
__created__ = "Wed Oct 17 11:10:50 2012"
__year__ = "2011"
__version__ = "1.0"

# Import sys and append path to python modules
import sys
sys.path.append('../')

# Import modules
import nx_pg
import nx_pgnet

# Import osgeo ogr for database connection
import osgeo.ogr as ogr
# Import GDAL to tweak OGR database connection
import osgeo.gdal as gdal
import networkx as nx
def main():
    '''Build the lightrail network in NetworkX and write to a PostGIS network
    schema instance.'''
    
    # Establish connection to the database using OGR
    # Make sure pg_use_copy is off (creates error when writing schema)
    gdal.SetConfigOption("PG_USE_COPY", "NO")
    # Make sure ogr can see non-spatial tables
    gdal.SetConfigOption("PG_LIST_ALL_TABLES", "YES")
    # Establish a connection (you need to configure these settings).    
    conn = ogr.Open("PG: host='localhost' dbname = 'lr'" 
    " user='postgres' password='aaSD2011' port='5433'")
    
    # Create a networkx instance using line and points table from the 
    # lightrail lines in GLA
    # nx_pg.read_pg takes connection, lines table name, nodes table name, 
    # directed network flag, geometry coordinate precision value.
    net = nx.read_shp('H:/A-PHD/LightRailBoston.shp')  
    net.add_edges_from(nx.read_shp('H:/A-PHD/SubwayRail_linesplit.shp'))
    print nx.number_of_nodes(net)
    print nx.number_of_edges(net)
    '''
    net = nx_pg.read_pg(conn, 'LightRail_Baseline_import', 
                        nodetable='LightRail_Baseline_Stations_import', 
                        directed=False, geometry_precision=2)    
    '''
    '''    
    net = nx_pg.read_pg(conn, 'Tube_Net_Edges', 
                        nodetable='Tube_Net_Nodes', 
                        directed=False, geometry_precision = 2)                    
    '''
    print 'built in networkx'
    #print 'assortativty coefficient:'
    #print nx.degree_assortativity_coefficient(net)
    #print 'max betweenness cenrality:'

    def max_val(alist):
        'Find the maximim value in a list'
        ma = -99999
        node = -99999    
        i=1
        print alist
        for i in max(alist):
            print i
            try:        
                if alist[i] > ma:
                    ma = alist[i]
                    node = i
                i += 1
            except:
                i += 1
        return ma, node    
    #print nx.betweenness_centrality(net)
    #print 'average path length:'
    #print nx.number_connected_components(net)
    # Once the network is read, create a PostGIS network schema instance
    # nx_pgnet.write().pgnet takes connection into the write class and the 
    # pgnet function takes NetworkX instance, database network table prefix, 
    # EPSG CRS code, overwrite existing network flag, directed network flag,
    # multigraph network flag.
    conn = ogr.Open("PG: host='localhost' dbname = 'BostonRail_geo'" 
    " user='postgres' password='aaSD2011' port='5433'")
    nx_pgnet.write(conn).pgnet(net, 'BostonRail_network', 27700, 
                                overwrite=False, directed=False, 
                                multigraph=False)
                            
    exit(0)
    
if __name__ == "__main__":
    main()