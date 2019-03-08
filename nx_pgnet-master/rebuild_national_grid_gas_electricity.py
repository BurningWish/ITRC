

import sys
#sys.path.append('C:\a8243587_DATA\GitRepo\nx_pgnet\...')
import os
import networkx as nx
import nx_pgnet
import ogr


host = 'localhost'
dbname = 'infrastructure'
user = 'postgres'
password = 'aaSD2011'
port = '5433'

conn = None
conn = ogr.Open("PG: host='%s' dbname='%s' user='%s' password='%s' port='%s'" % (host, dbname, user, password, port))

#rebuild gas network

#read from csv
gas_network = nx_pgnet.read(conn).pgnet_via_csv('NationalGrid_Gas_Trans_Jan2012_3_wnt', 
    'C:/a8243587_DATA/networks/gas/NationalGrid_Gas_Trans_Jan2012_3_wnt_node_record.csv', 
    'C:/a8243587_DATA/networks/gas/NationalGrid_Gas_Trans_Jan2012_3_wnt_edge_record.csv', 
    'C:/a8243587_DATA/networks/gas/NationalGrid_Gas_Trans_Jan2012_3_wnt_edge_geometry_record.csv',
    True, True)

#return some gas network information
print nx.info(gas_network)

#write to db
nx_pgnet.write(conn).pgnet_via_csv(gas_network, 'NationalGrid_Gas_Trans_Jan2012_3_wnt', srs=27700, overwrite=True, directed=True, multigraph=True, output_csv_folder='<output_path>')

#rebuild electricity network (with towers)

#read from csv
electricity_network = nx_pgnet.read(conn).pgnet_via_csv('NationalGrid_Elec_Trans_Jan2012_3_w_nt', 
    'C:/a8243587_DATA/networks/electricity/NationalGrid_Elec_Trans_Jan2012_3_w_nt_node_record.csv', 
    'C:/a8243587_DATA/networks/electricity/NationalGrid_Elec_Trans_Jan2012_3_w_nt_edge_record.csv', 
    'C:/a8243587_DATA/networks/electricity/NationalGrid_Elec_Trans_Jan2012_3_w_nt_edge_geometry_record.csv', 
    True, True)

#return some electricity network information
print nx.info(electricity_network)

#write to db
nx_pgnet.write(conn).pgnet_via_csv(electricity_network, 'NationalGrid_Elec_Trans_Jan2012_3_wnt', srs=27700, overwrite=True, directed=True, multigraph=True, output_csv_folder='<output_path>')

#rebuild electricity network (without towers)

#read from csv
electricity_network = nx_pgnet.read(conn).pgnet_via_csv('NationalGrid_Elec_Trans_NT_Jan2012', 
    '<path_to>//NationalGrid_Elec_Trans_NT_Jan2012_wnt_node_record.csv', 
    '<path_to>//NationalGrid_Elec_Trans_NT_Jan2012_wnt_edge_record.csv', 
    '<path_to>//NationalGrid_Elec_Trans_NT_Jan2012_wnt_edge_geometry_record.csv', 
    True, True)

#return some electricity network information
print nx.info(electricity_network)

#write to db
nx_pgnet.write(conn).pgnet_via_csv(electricity_network, 'NationalGrid_Elec_Trans_NT_Jan2012', srs=27700, overwrite=True, directed=True, multigraph=True, output_csv_folder='<output_path>')

