# MCNnet_2.0
Advanced node networking for Open Computers, still under active development.

## About
MCNnet 2.0 stands for Minecraft Computer Node network, which is used to connect computers over distance using nodes. Not only you can connect two computers - you can create servers, on which users will be able to join. The only limitation - nodes must be within 400 block range, as it's default connect range of wireless network card. However, usage of linked cards is possible, using Tunnel Nodes (Tnodes), allowing connections between distant places and across dimentions.
## IP address system
MCNnet uses it's own simple address system, which consists of first 4 digits of node's UUID and first 4 digits of client UUID, so they look like this: 12ab:34cd. Nodes have 0000 in their client ID, like this: 12ab:0000.
## DNS
Servers will be able to have domain names, like "example.com". 
## Servers
Servers are special clients, which can handle connections from different clients. There are different protocols of connecting to server:  
**[Term]** - simple terminal connection, allows basic I/O facilities.  
**[FTP]** - simple File Transfer Protocol connection, however does not support TUI.  
**[FTerm]** - simple terminal with FTP attached to it, can download and upload files.  
**[GSTP]** - [Planned] Graphical Site Transfer Protocol - graphical sites, as we know it.  
