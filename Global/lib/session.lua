local ip=require("ipv2")
local computer=require("computer")
local version="1.9.2 BETA"
local session={}
local dolog=true
function log(text)
  local res="["..computer.uptime().."]"
  if dolog then print(res.."[NC/INFO]"..text) end
end
function session.ver() return version end
function session.checkRoute(route)
	if type(route)~="table" then return false end
	local length=0
	for _ in pairs(route) do length=length+1 end
	for i=0,length-1 do
		if not ip.isIPv2(route[i]) then return false end
	end
	return true
end
function session.checkSession(sessionInfo) --log for debug
	if not sessionInfo then log("nothing was given") return false end
	if not ip.isUUID(sessionInfo["uuid"]) then log("no session uuid") return false end
	if not sessionInfo["route"] then log("no route table") return false end
	if not session.checkRoute(sessionInfo["route"]) then log("incorrect route") return false end
	if not tonumber(sessionInfo["ttl"]) then log("no ttl") return false end
	if not ip.isIPv2(sessionInfo["t"]) and sessionInfo["t"]~="broadcast" and sessionInfo["t"]~="dns_lookup" then 
		if sessionInfo["t"] then log("invalid destination: "..sessionInfo["t"]) else log("no destination") end
		return false 
	end
	if not sessionInfo["c"] then return false end
	return true
end
function session.newSession(to_ip,route,ttl)
	from_ip=""
	if ip.isIPv2(os.getenv("this_ip")) then --try to use default
		from_ip=os.getenv("this_ip")
	else return nil end
	if to_ip=="dns_lookup" then --pass
	elseif not ip.isIPv2(to_ip) or not to_ip then to_ip="broadcast" end
	if not tonumber(ttl) then ttl=16 end
	local newSession={}
	newSession["uuid"]=require("uuid").next()
	newSession["t"]=to_ip
	if session.checkRoute(route) then
		newSession["route"]=route
	else
		newSession["route"]={}
		newSession["route"][0]=from_ip
	end
	newSession["c"]=1
	newSession["ttl"]=tonumber(ttl)
	return newSession
end
function session.addIpToSession(sessionInfo,ip_a)
	if not session.checkSession(sessionInfo) then error("[SESSION ADD]: Invalid Session") end
	if not ip.isIPv2(ip_a) then error("[SESSION ADD]: Not an IP") end
	sessionInfo["route"][#sessionInfo["route"]+1]=ip_a
	return sessionInfo
end
function session.reverseRoute(route) --r0 - who to add to 0
	if not session.checkRoute(route) then return nil end
	local reversed_route={}
	reversed_route[0]=os.getenv("this_ip")
	for i = #route, 1, -1 do
		table.insert(reversed_route, route[i])
	end
	table.insert(reversed_route,route[0])
	return reversed_route
end
return session
--SESSION WILL BE RENAMED TO NETPACKET(NetworkPacket, np)