local config={}
--Network name
config.netName="Internet"
--Time to search for other nodes
config.searchTime=10
--Do MNP logging?
config.log=true
--Log packets TTL dropping log?
config.logTTL=true

--CHANGE THIS IF YOU KNOW WHAT YOU'RE DOING
config.clearNIPS=true
return config