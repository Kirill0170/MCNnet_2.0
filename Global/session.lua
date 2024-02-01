local ip=require("ipv2")
local version="1.4 EXPERIMENTAL"
local session={}
function session.ver() return version end
function session.checkSession(sessionInfo)
    if not sessionInfo then return false end
    if not ip.isUUID(sessionInfo["uuid"]) then return false end
    if not ip.isIPv2(sessionInfo[0]) then return false end
    if not tonumber(sessionInfo["ttl"]) then return false end
    if not tonumber(sessionInfo["c"]) then return false end
    if not ip.isIPv2(sessionInfo["t"]) and sessionInfo["t"]~="broadcast" then return false end
    return true
end
function session.newSession(from_ip,to_ip,ttl)
    if not ip.isIPv2(from_ip) then return nil end
    if not ip.isIPv2(to_ip) or not to_ip or to_ip~="dns_lookup" then to_ip="broadcast" end
    if not tonumber(ttl) then ttl=16 end
    local newSession={}
    newSession["uuid"]=require("uuid").next()
    newSession["c"]=1
    newSession["t"]=to_ip
    newSession[0]=from_ip
    newSession["ttl"]=tonumber(ttl)
    return newSession
end
function session.addIpToSession(sessionInfo,ip_a)
    if not session.checkSession(sessionInfo) then error("[SESSION ADD]: Invalid Session") end
    if not ip.isIPv2(ip_a) then error("[SESSION ADD]: Not an IP") end
    sessionInfo[sessionInfo["c"]]=ip_a
    sessionInfo["c"]=sessionInfo["c"]+1
    return sessionInfo
end
return session