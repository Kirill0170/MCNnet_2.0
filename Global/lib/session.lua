local ip=require("ipv2")
local computer=require("computer")
local version="1.4 EXPERIMENTAL"
local session={}
local dolog=true
local function log(text)
    local res="["..computer.uptime().."]"
    if dolog then print(res.."[SS/INFO]"..text) end
end
function session.ver() return version end
function session.checkSession(sessionInfo) --log for debug
    if not sessionInfo then log("nothing was given") return false end
    if not ip.isUUID(sessionInfo["uuid"]) then log("no session uuid") return false end
    if not sessionInfo["route"] then log("no route table") return false end
    if not ip.isIPv2(sessionInfo["route"][0]) then log("no original ip") return false end
    if not tonumber(sessionInfo["ttl"]) then log("no ttl") return false end
    if not ip.isIPv2(sessionInfo["t"]) and sessionInfo["t"]~="broadcast" and sessionInfo["t"]~="dns_lookup" then 
        if sessionInfo["t"] then log("invalid destination: "..sessionInfo["t"]) else log("no destination") end
        return false 
    end
    return true
end
function session.newSession(from_ip,to_ip,ttl)
    if not ip.isIPv2(from_ip) then
        if ip.isIPv2(os.getenv("this_ip")) then --try to use default
            from_ip=os.getenv("this_ip")
        else return nil end
    end
    if to_ip=="dns_lookup" then --pass
    elseif not ip.isIPv2(to_ip) or not to_ip then to_ip="broadcast" end
    if not tonumber(ttl) then ttl=16 end
    local newSession={}
    newSession["uuid"]=require("uuid").next()
    newSession["t"]=to_ip
    newSession["route"]={}
    newSession["route"][0]=from_ip
    newSession["ttl"]=tonumber(ttl)
    return newSession
end
function session.addIpToSession(sessionInfo,ip_a)
    if not session.checkSession(sessionInfo) then error("[SESSION ADD]: Invalid Session") end
    if not ip.isIPv2(ip_a) then error("[SESSION ADD]: Not an IP") end
    sessionInfo["route"][#sessionInfo["route"]+1]=ip_a
    return sessionInfo
end
function session.adjustPattern(sessionInfo,ttl,reverse)
    if not session.checkSession(sessionInfo) then return false end
    if not reverse then reverse=false end
    if not ttl then ttl=16 end
    sessionInfo["ttl"]=ttl
    --indev
end
return session