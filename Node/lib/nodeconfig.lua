local config={}
--Network name
config.netName="Internet"
--Time to search for other nodes
config.searchTime=10
--Do MNP logging?
config.log=true
--Log packets TTL dropping log?
config.logTTL=true
--How many threads for connections?
config.threads=4
--CHANGE THIS IF YOU KNOW WHAT YOU'RE DOING
config.clearNIPS=true
return config