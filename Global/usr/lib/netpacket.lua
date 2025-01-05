local ip=require("ipv2")
local computer=require("computer")
local version="2.0 BETA"
local netpacket={}
local dolog=true
function log(text)
  local res="["..computer.uptime().."]"
  if dolog then print(res.."[NP/INFO]"..text) end
end
function netpacket.ver() return version end
function netpacket.checkRoute(route)
	if type(route)~="table" then return false end
	local length=0
	for _ in pairs(route) do length=length+1 end
	for i=0,length-1 do
		if not ip.isIPv2(route[i]) then return false end
	end
	return true
end
function netpacket.checkPacket(netpacketInfo) --log for debug
	if not netpacketInfo then log("nothing was given") return false end
	if not ip.isUUID(netpacketInfo["uuid"]) then log("no netpacket uuid") return false end
	if not netpacketInfo["route"] then log("no route table") return false end
	if not netpacket.checkRoute(netpacketInfo["route"]) then log("incorrect route") return false end
	if not tonumber(netpacketInfo["ttl"]) then log("no ttl") return false end
	if not ip.isIPv2(netpacketInfo["t"]) and netpacketInfo["t"]~="broadcast" and netpacketInfo["t"]~="dns_lookup" then 
		if netpacketInfo["t"] then log("invalid destination: "..netpacketInfo["t"]) else log("no destination") end
		return false 
	end
	if not netpacketInfo["c"] then return false end
	return true
end
function netpacket.newPacket(to_ip,route,ttl)
	from_ip=""
	if ip.isIPv2(os.getenv("this_ip")) then --try to use default
		from_ip=os.getenv("this_ip")
	else return nil end
	if to_ip=="dns_lookup" then --pass
	elseif not ip.isIPv2(to_ip) or not to_ip then to_ip="broadcast" end
	if not tonumber(ttl) then ttl=16 end
	local newnetpacket={}
	newnetpacket["uuid"]=require("uuid").next()
	newnetpacket["t"]=to_ip
	if netpacket.checkRoute(route) then
		newnetpacket["route"]=route
	else
		newnetpacket["route"]={}
		newnetpacket["route"][0]=from_ip
	end
	newnetpacket["c"]=1
	newnetpacket["ttl"]=tonumber(ttl)
	return newnetpacket
end
function netpacket.addIp(netpacketInfo,ip_a)
	if not netpacket.checkPacket(netpacketInfo) then error("[NP ADD]: Invalid netpacket") end
	if not ip.isIPv2(ip_a) then error("[NP ADD]: Not an IP") end
	netpacketInfo["route"][#netpacketInfo["route"]+1]=ip_a
	return netpacketInfo
end
function netpacket.reverseRoute(route) --r0 - who to add to 0
	if not netpacket.checkRoute(route) then return nil end
	local reversed_route={}
	reversed_route[0]=os.getenv("this_ip")
	for i = #route, 1, -1 do
		table.insert(reversed_route, route[i])
	end
	table.insert(reversed_route,route[0])
	return reversed_route
end
return netpacket
--netpacket WILL BE RENAMED TO NETPACKET(NetworkPacket, np)