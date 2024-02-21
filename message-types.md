# MCNnet message types (aka mtypes) are first field in every packet. they indicate what to do with packet, and indicate what protocol it is.
## Node-controlled mtypes(MNP protocol):
netsearch - client search for network\
netconnect - connection to nodes\
netdisconnect - disconnect from node\
search - MNP search for server\
dns_lookup - MNP search with DNS\
data - sends data to address
## Others use protocol name as mtype (ex. ssap)