--Mcn-net Networking Protocol v2.1 EXPERIMENTAL
--Modem is required.
local dolog = true --log?
local ttllog = true --log ttl discardment?
local mncplog = true --log MNCP checks?
local component = require("component")
local computer = require("computer")
local ser = require("serialization")
local netpacket = require("netpacket")
local thread = require("thread")
local modem = component.modem
local event = require("event")
local ip = require("ipv2")
local dns = require("dns")
local gpu = component.gpu
local mnp_ver = "2.4.4 BETA"
local mncp_ver = "2.3.2 REWORK INDEV"
local forbidden_vers = {}
forbidden_vers["mnp"] = { "2.21 EXPERIMENTAL" }
forbidden_vers["mncp"] = { "2.1 EXPERIMENTAL" }
local ports = {}
ports["mnp_reg"] = 1000
ports["mnp_srch"] = 1001
ports["mnp_data"] = 1002
ports["mncp_srvc"] = 1003
ports["mncp_err"] = 1004
ports["mncp_ping"] = 1005
ports["mftp_conn"] = 1006
ports["mftp_data"] = 1007
ports["mftp_srvc"] = 1008
ports["dns_lookup"] = 1009
local mnp = {}
mnp.mncp={}
mnp.networkName = "default" --default network name
function mnp.log(mod,text, crit)
	if not mod then mod="MNP" end
	if not text then text="Unknown" end
	local res = "[" .. computer.uptime() .. "]"
	if dolog and (crit == 0 or not crit) then
		print(res .. "["..mod.."/INFO]" .. text)
	elseif dolog and crit == 1 then
		gpu.setForeground(0xFFFF33)
		print(res .. "["..mod.."/WARN]" .. text)
		gpu.setForeground(0xFFFFFF)
	elseif crit == 2 then
		gpu.setForeground(0xFF3333)
		print(res .. "["..mod.."/ERROR]" .. text)
		gpu.setForeground(0xFFFFFF)
	elseif crit == 3 then
		gpu.setForeground(0xFF3333)
		print(res .. "["..mod.."/FATAL]" .. text)
		gpu.setForeground(0xFFFFFF)
		local file = io.open("mnp_err.log", "w")
		file:write(res .. text)
		file:close()
		error("Fatal error occured in runtime,see mnp_err.log file")
	else
	end
end
--init-----------------------------------
function mnp.logVersions() 
	mnp.log("MNP","Starting...")
	mnp.log("MNP","MNP version " .. mnp_ver)
	mnp.log("MNP","MNCP version " .. mncp_ver)
	mnp.log("MNP","NP version " .. netpacket.ver())
	mnp.log("MNP","IP version " .. ip.ver())
	mnp.log("MNP","DNS version " .. dns.ver())
	mnp.log("MNP","Done")
end
--MNCP-----------------------------------
function mnp.mncp.checkService() --rewrite with timer
	--rewrite
end
function mnp.mncp.nodePing(from)
	modem.send(from, ports["mncp_ping"], "mncp_ping", ser.serialize(netpacket.newPacket()))
end
function mnp.mncp.c2cPing(to_ip)
	--write
end
--MNP------------------------------------
--Util-
function timer(time, name)
	os.sleep(time)
	computer.pushSignal("timeout", name)
end
function mnp.setNetworkName(newname)
	if tostring(newname) then
		mnp.networkName = tostring(newname)
	end
end
function mnp.toggleLogs(tLog,tTTL)
	if type(tLog)=="boolean" then dolog =tLog end
	if type(tTTL)=="boolean" then ttllog=tTTL end
end
function mnp.openPorts(plog)
	for name, port in pairs(ports) do
		if plog then
			mnp.log("MNP","Opening " .. name)
		end
		if not modem.open(port) and not modem.isOpen(port) then
			return false
		end
	end
	return true
end
function mnp.getPort(keyword)
	return ports[keyword]
end
--Main-
function mnp.closeNode()
	mnp.log("MNP","Closing node, disconnecting everyone...")
	local nips = ip.getAll()
	for n_ip, n_uuid in pairs(nips) do
		local np = ser.serialize(netpacket.newPacket(n_ip))
		modem.send(n_uuid, ports["mnp_reg"], "netdisconnect", np, ser.serialize({ mnp.networkName }))
	end
end
function mnp.networkDisconnect(from)
	local deleted_ip=ip.deleteUUID(from)
	mnp.log("MNP","Disconnected: "..tostring(deleted_ip))
end
function mnp.networkSearch(from, np, data) --allows finding
	if not ip.isUUID(from) or not netpacket.checkPacket(np) then
		mnp.log("MNP","Invalid packet or no from address",2)
	end
	--check
	local respond = true
	for name in pairs(data) do
		if mnp.networkName == name then
			respond = false
		end
	end
	if respond then
		local rnp = netpacket.newPacket()
		modem.send(from, ports["mnp_reg"], "netsearch", ser.serialize(rnp), ser.serialize({ mnp.networkName }))
	end
end
function mnp.networkConnect(from, np, data)
	if not ip.isUUID(from) or not netpacket.checkPacket(np) then
		mnp.log("MNP","Invalid np or no from address",2)
		return false
	end
	if data then
		if data[1] ~= mnp.networkName then
			return false
		end
	end
	if np["route"][0] == "0000:0000" then --client
		local rnp = ser.serialize(netpacket.newPacket())
		local ipstr = string.sub(os.getenv("this_ip"), 1, 4) .. ":" .. string.sub(from, 1, 4)
		modem.send(from, ports["mnp_reg"], "netconnect", rnp, ser.serialize({ mnp.networkName, ipstr }))
		ip.addUUID(from)
		mnp.log("MNP","New client connected: "..ipstr)
		return true
	elseif ip.isIPv2(np["route"][0], true) then --node
		if ip.findIP(from) then
			return true
		end --check if already connected
		--check found table
		for f_ip in pairs(data[2]) do
			if f_ip == ip.gnip() then
				return true
			end
		end
		local rnp = ser.serialize(netpacket.newPacket())
		modem.send(from, ports["mnp_reg"], "netconnect", rnp, ser.serialize({ "ok" }))
		ip.addUUID(from, true)
		mnp.log("MNP","New node connected: "..np["route"][0])
		return true
	else
		mnp.log("MNP","unknown ip, possibly un-disconnected client",1)
		return false
	end
end

function mnp.nodeConnect(connectTime) --on node start, call this
	if not tonumber(connectTime) then
		connectTime = 10
	end
	if not ip.isIPv2(os.getenv("this_ip"), true) then
		mnp.log("MNP","Setup the ip first! Setting up for you..",1)
		if not ip.set(ip.gnip(),true) then
			mnp.log("MNP","Couldn't setup IPv2",3)
		end
	end
	local rnp = netpacket.newPacket()
	local timerName = "nc" .. computer.uptime()
	thread.create(timer, connectTime, timerName):detach()
	local exit = false
	local found = {} --for found ips
	while not exit do
		modem.broadcast(ports["mnp_reg"], "netconnect", ser.serialize(rnp), ser.serialize({ mnp.networkName, found }))
		local id, name, from, port, dist, mtype, np = event.pullMultiple("interrupted", "timeout", "modem")
		if id == "timeout" or id == "interrupted" then
			exit = true
			mnp.log("MNP","timeout")
		else
			np = ser.unserialize(np)
			if ip.isIPv2(np["route"][0], true) then
				table.insert(found, np["route"][0])
				ip.addUUID(from, true)
				mnp.log("MNP","registered new node")
			end
		end
	end
	return true
end
function mnp.search(from, np)
	if not ip.isUUID(from) or not netpacket.checkPacket(np) then
		mnp.log("MNP","Unvalid arguments for search", 2)
		return false
	end
	if np["ttl"] <= 1 then
		if ttllog then mnp.log("MNP","Packet"..np["uuid"].." dropped: TTL = 0",1) end
		return false
	end
	if np["f"] == true then --return
		local to_i = 0
		for i = 0, #np["route"] do
			if np["route"][i] == ip.gnip() then
				to_i = i - 1
				break
			end
		end
		local to_uuid = ip.findUUID(np["route"][to_i])
		if not to_uuid then
			mnp.log("MNP","Couldn't find address to return to while returning search", 2)
			return false
		end
		--SAVE[TODO]

		modem.send(to_uuid, ports["mnp_srch"], "search", ser.serialize(np))
	else
		--check if no current
		if np["route"][#np["route"]] ~= ip.gnip() then
			np = netpacket.addIp(np, ip.gnip())
		end
		--check local
		for n_ip, n_uuid in pairs(ip.getAll()) do
			if n_ip == np["t"] then --found
				np["f"] = true
				np["r"] = true
				np = netpacket.addIp(np, n_ip)
				--dns?
				modem.send(from, ports["mnp_srch"], "search", ser.serialize(np))
				return true
			end
		end
		--CHECK SAVED[TODO]

		--check if looped
		local chk=0
		for i=0,#np["route"] do
		  if np["route"][i]==ip.gnip() then chk=chk+1 end
		end
		if chk>1 then return false end
		--continue search
		for n_ip, n_uuid in pairs(ip.getNodes(from)) do
			local snp = np
			snp = netpacket.addIp(snp, n_ip)
			snp["ttl"] = np["ttl"] - 1
			modem.send(n_uuid, ports["mnp_srch"], "search", ser.serialize(snp))
		end
	end
end
function mnp.pass(port, mtype, np, data)
	if not port or not mtype or not np then
		return false
	end
	--check TTL
	np["ttl"]=np["ttl"]-1
	if np["ttl"]==0 then
		if ttllog then
			mnp.log("MNP","Packet"..np["uuid"].." dropped: TTL = 0",1)
		end
		return false
	end
	if np["r"] == true then np["c"]=np["c"]-1
	else np["c"]=np["c"]+1 end
	local to = ip.findUUID(np["route"][np["c"]])
	if not to then
		mnp.log("MNP","Unsuccessful pass: Unknown IP", 2)
		mnp.log("MNP","Route crude:" .. ser.serialize(np["route"]), 1)
		mnp.log("MNP","Route stack:", 1)
		for i in pairs(np["route"]) do
			mnp.log("MNP","<route:" .. tostring(i) .. ">:" .. np["route"][i], 1)
		end
		mnp.log("MNP","Tried: "..tostring(np["c"]))
		return false
	end
	modem.send(to, ports["mnp_data"], mtype, ser.serialize(np), ser.serialize(data))
	return true
end
-------

return mnp
--[[ netpacket
[uuid]:<session uuid>
[t]:<target_ip>
[ttl]:<time-to-live>
[route][0]:<ip(from)>
[route][1]:<ip(node)>
...
route[np[#route]\]:<ip(target)>
[f]:<found? bool>
[r]:<reverse? bool> si
]]
--[[
ip: 12ab:34cd
  NodeIP:ClientIP
node ip: 12ab:0000
dns ip: 12ab:000D [sys only]

node ip table:
nips["12ab:34cd"]="<ClientIP>"
nips["56ef:0000"]="<NodeIP>"
]]
--[[ PORTS (16)
1000 - MNP registartion
1001 - MNP search
1002 - MNP data(casual)
1003 - MNCP service (chk_con)
1004 - MNCP errors
1005 - MNCP ping
1006 - MFTP connect
1007 - MFTP DATA
1008 - MFTP service (chk_con)
1009 - DNS lookup
1010 - MNP security (dev)
1020 - MRCCP requests
1021 - MRCCP send
1022 - MRCCP receive
]]
--[[ CLIENT REG SI
[0]: "0000:0000"
[ttl]: 2
[c]: 1
[t]: "broadcast"
]]
--[[ GET DNS REQUEST
mtype="dnslookup"
data={"<domain>"}
response data={"<domain>","<statuscode>","<ipv2>"}
status codes:
D1 - OK
D2 - RESOURCE DOWN
session:
[[
[0]: <clientIP>
[t]: "dnsserver"
[f]: true/false
]]
--[[ SSAP PROTOCOL (refer to .ssap_protocol)
"ssap"
session: [f]:true (need to find first)
data:
[[
"<mtype>",{<options>},{<data>}
m-types:
(s<-c)"init",{"version"="<SSAP version>"},{}
(s->c)"init",{"uap"=true/false},{"OK/CR"}
(s->c)"text",{x:0,y:0,fgcol:0xFFFFFF,bgcol:"default"},{"<sample text>"}
(s->c)"input_request",{},{}
(s<-c)"input_response",{},{"<input>"}
]]
--connect 12ab:34cd
--TODO: REDIRECTS
--IDEA: NODE SOURCE CODE HASH CHECKING
--CODENAME URBAN ORBIT