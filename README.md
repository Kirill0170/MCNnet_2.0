# IT IS STILL UNDER DEVELOPMENT. (Alpha release!)
# MCNnet_2.0
Advanced node networking for Open Computers, still under active development.

## Currently written:
* Low-level commpunication between nodes & clients(searching & sending packets)
* Domain names are NOT written
* Protocols: MNP, MNCP(pinging), SSAP
* SSAP servers are working for use
## Planned:
* Domain names for servers
* Tunnel Nodes for cross-dimentional communication
* FTP for files
* UAP for logins
* (very planned) better website protocol

## About
MCNnet 2.0 stands for Minecraft Computer Node network, which is used to connect computers over distance using nodes. Not only you can connect two computers - you can create servers, which users will be able to join. The only limitation - nodes must be within 400 block range, as it's default connect range of wireless network card. However, usage of linked cards is possible, using Tunnel Nodes (Tnodes), allowing connections between distant places and across dimentions.
## IP address system
MCNnet uses it's own simple address system, which consists of first 4 digits of node's UUID and first 4 digits of client UUID, so they look like this: 12ab:34cd. Nodes have 0000 in their client ID, like this: 12ab:0000.
## Searching & route system
When trying to connect to specific ip address, mnp search will be run recursively on all nodes(without loops of course). These search packets will have TTL, so its not infinite(TTL is configurable). These packets will store each node ip address they went through, and ip address from which it originated. In case host is found, a packet is sent back to client. After that, the route is stored on client, and future connections will be using that route. 
## DNS
Servers will be able to have domain names, like "example.com". 
## Servers
Servers are special clients, which can handle connections from different clients. There are different protocols of connecting to server, each designed to accomplish specific tasks.
## Protocols
**[SSAP]** - Simple Server Application Protocol, allows simple terminal connection with basic I/O facilities.  
**[FTP]** - simple File Transfer Protocol connection, however does not support TUI.  
**[SSAPF]** - SSAP with FTP attached to it, can download and upload files.  
**[SSTP]** - [Planned] Simple Site Transfer Protocol - graphical sites, as we know it.  
**[UAP]** - Universal Auth Protocol, for managing logins.
