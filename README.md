# MCNnet_2.0
Advanced node networking for Open Computers, still under active development.

## About
MCNnet 2.0 stands for Minecraft Computer Node network, which is used to connect computers over distance using nodes. Not only you can connect two computers - you can create servers, on which users will be able to join. The only limitation - nodes must be within 400 block range, as it's default connect range of wireless network card.
## IP address system
MCNnet uses IP address system, which looks similar to real one, yet is very different: it uses 3 numbers instead of 4, and numbers can me very high - up to 999 or even more. First number is GroupID - a group of nodes, Second number is NodeID - the number of a node in the group, Third one - is ClientID, indicates which client is connected to the node(nodes use ClientID=0). So, a typical IP will look like this: 12.35.19
## Servers
Servers are special clients, which can handle connections from different clients. There are 5 main types of servers:\
**Terminal Server** - a server with just a lua script running on it, which can be anything you want!\
**FS Server** - FileSystem server - is used to store files, for example - a cloud service, providing more place for everyone!\
**Website Server** - a type of server which is still under development and will be released later, will host websites using HTML-like markup language!\
**Email Server** - a server with mail system attached to it, combine it with FS server - and you have pretty much a BBS!\
**MNC Server** - Multi-Node Chat server, will allow users to chat in-real time: it's like IRC!\
The important part is, while i will provide you with template servers for each of above(eventually), you can write servers yourself - like the rest of OpenComputers. Just by using API, you will be able to create everything you want.
