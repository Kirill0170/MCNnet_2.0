--Mcn-net Networking Protocol v2.1 EXPERIMENTAL
--With Session Protocol v1.21 EXPERIMENTAL
--Modem is required.
local dolog=true --log?
local ttllog=true --log ttl discardment?
local mncplog=true --log MNCP checks?
local component=require("component")
local computer=require("computer")
local ser=require("serialization")
local session=require("session")
local modem=component.modem
local event=require("event")
local ip=require("ipv2")
local dns=require("dns")
local gpu=component.gpu
local mnp_ver="2.2 EXPERIMENTAL"
local mncp_ver="2.0 EXPERIMENTAL"
local forbidden_vers={}
local ports={}
ports["mnp_reg"]=1000
ports["mnp_srch"]=1001
ports["mnp_data"]=1002
ports["mncp_srvc"]=1003
ports["mncp_err"]=1004
ports["mncp_ping"]=1005
ports["mftp_conn"]=1006
ports["mftp_data"]=1007
ports["mftp_srvc"]=1008
ports["dns_lookup"]=1009
local mnp={}
--init-----------------------------------
print("[MNP INIT]: Starting...")
print("[MNP INIT]: MNP version "..mnp_ver)
print("[MNP INIT]: MNCP version "..mncp_ver)
print("[MNP INIT]: SP version "..session.ver())
print("[MNP INIT]: IP version "..ip.ver())
print("[MNP INIT]: DNS version "..dns.ver())
print("[MNP INIT]: Done")
--MNCP-----------------------------------
function mnp.mncpService()
  local a=2 --attempts
  local t=2 --timeout
  if not modem.isOpen(ports["mncp_srvc"]) then modem.open(ports["mncp_srvc"]) end
  log("Started MNCP service")
  local err=false
  repeat
    os.sleep(10)
    log("Running MNCP check...")
    for n_ip,n_uuid in pairs(ip.getAll()) do
      if mncplog then log("[MNCP]Checking "..n_ip) end
      local chk=false
      for i=0,a do
        local times=computer.uptime()
        modem.send(n_uuid,ports["mncp_srvc"],"mncp_check",ser.serialize(session.newSession(os.getenv("this_ip"),n_ip,1)))
        local _,_,from,port,_,mtype,si=event.pull(t,"modem")
        if from~=n_ip or port~=ports["mncp_srvc"] then
          --ok
        elseif mtype=="mncp_srvc" then
          log("[MNCP]verified, ping: "..computer.uptime()-times)
          chk=true
          break
        end
        if not chk then --disconnect
          log("[MNCP]not verified connection! Disconnecting...")
          ip.deleteUUID(n_uuid)
        end
      end
    end
  until err
end
--MNP------------------------------------
--Util-
function log(text,crit)
  local res="["..computer.uptime().."]"
  if dolog and crit==0 or not crit then
    print(res.."[MNP/INFO]"..text)
  elseif dolog and crit==1 then
    gpu.setForeground(0xFFFF33)
    print(res.."[MNP/WARN]"..text)
    gpu.setForeground(0xFFFFFF)
  elseif crit==2 then
    gpu.setForeground(0xFF3333)
    print(res.."[MNP/ERROR]"..text)
    gpu.setForeground(0xFFFFFF)
  elseif crit==3 then
    gpu.setForeground(0xFF3333)
    print(res.."[MNP/FATAL]"..text)
    gpu.setForeground(0xFFFFFF)
    local file=io.open("mnp_err.log","w")
    file:write(res..text)
    file:close()
    error("Fatal error occured in runtime,see log file")
  else end
end
function mnp.crash(reason) --do not use
  modem.open(ports["mncp_err"])
  modem.broadcast(ports["mncp_err"],"crash","node",reason)
end
function mnp.openPorts(plog)
  for name,port in pairs(ports) do
    if plog then log("Opening "..name) end
    if not modem.open(port) and not modem.isOpen(port) then return false end
  end
  return true
end
function mnp.getPort(keyword)
  return ports[keyword]
end
--Main-
--reg--
function mnp.node_chkreg(from,sessionInfo)
  if not ip.isUUID(from) or not sessionInfo then return false end
  if not session.checkSession(sessionInfo) then return false end
  if ip.isIPv2(sessionInfo["route"][0],true) then
    if string.sub(from,1,4)==sessionInfo["route"][0] then
      ip.addUUID(from,true)
      log("New node: "..string.sub(from,1,4))
      modem.send(from,ports["mnp_reg"],"register",ser.serialize(session.newSession(os.getenv("this_ip"))),"ok")
      return true
    else
      log("Unvalid session: IP doesn't correspond to uuid",1)
      return false
    end
  end
end

function mnp.node_register(a,t) --todo: rewrite this using timer
  if not a then a=5 end
  if not t then t=2 end
  local ct=false
  if not ip.isIPv2(os.getenv("this_ip"),true) then
    log("Node IP not set!",2)
    return false
  end
  if not modem.isOpen(ports["mnp_reg"]) then
    log("Modem registration ports is not open, opening...",1)
    ct=true modem.open(ports["mnp_reg"]) 
  end
  for i=0,a do --packets
    local rsi=ser.serialize(session.newSession(os.getenv("this_ip"),"",1))
    modem.broadcast(ports["mnp_reg"],"register",rsi)
    local _,_,from,port,_,mtype,si=event.pull(t,"modem")
    if not from then log("[nreg seq:"..i.."]: Timeout",1)
    elseif port~=ports["mnp_reg"] then
    elseif mtype=="register" then
      if not mnp.node_chkreg(from,si) then
        log("[nreg seq:"..i.."]: Not node",1)
      end
    else end
  end
  if ct then modem.close(ports["mnp_reg"]) end
  return true
end

function mnp.register(from,si,data) --buggy
  if not from or not session.checkSession(si) then
    log("Unvalid arguments for register",2)
    return false
  end
  data=ser.unserialize(data)
  if #si["route"]>0 then
    log("Non-local registration is not supported: #route="..#si["route"],2)
    return false
  end
  if ip.isIPv2(si["route"][0],true) then --node
    for n_ip,_ in pairs(ip.getNodes()) do
      if si["route"][0]==n_ip then
        return nil
      end
    end
    ip.addUUID(from,true)
    --send succeessful registration
    local rsi=ser.serialize(session.newSession(os.getenv("this_ip"),"",1))
    modem.send(from,ports["mnp_reg"],"register",rsi)
    log("Registered new node: "..si[0])
    return true
  elseif ip.isIPv2(si["route"][0]) then --client/server
    if data then -- DNS server [OPTIMIZATION REQUIRED]
      if dns.checkHostname(data[1]) and data[2]~=nil then --TODO: check protocol
        local s_ip=string.sub(os.getenv("this_ip"),1,5)..string.sub(from,1,4)
        dns.add(s_ip,data[1],data[2])
        local rsi=ser.serialize(session.newSession(os.getenv),"",1)
        modem.send(from,ports["mnp_reg"],"register",rsi)
      else --incorrect
        log("Registration failed: incorrect hostname",1)
        return false
      end
    else --regular
      ip.addUUID(from)
      local rsi=ser.serialize(session.newSession(os.getenv("this_ip"),"",1))
      modem.send(from,ports["mnp_reg"],"register",rsi)
      log("Registered new server/client: "..si["route"][0])
    end
  else
    log("Registartion failed: unknown IPv2 error",1)
    return false
  end
  return true
end

function mnp.search(from,sessionInfo) --TODO: error codes
  if not ip.isUUID(from) or not session.checkSession(sessionInfo) then
    log("Unvalid arguments for search",2)
    return false
  end
  local si=sessionInfo --FIX: session is already unserialized
  if not si["f"] then --search
      for k,v in pairs(si["route"]) do --check if looped
        if v==os.getenv("this_ip") then
          log("Search discarded: looped",1)
          return false 
        end
      end
      if si["ttl"]<=1 then
        log("Search discarded: ttl is 1",1)
        if ttllog then
          log("Saving session info to latest_ttl.log",1)
          local file=io.open("latest_ttl.log","w")
          file:write("["..computer.uptime().."]Latest TTL discardment")
          file:write(ser.serialize(sessionInfo,true))
          file:close()
        end
        return false
    end
    --check local
    local l_uuid=ip.findUUID(si["t"])
    if l_uuid then --its here!
      --server ping?
      si[#si["route"]+1]=ip.findIP(l_uuid)
      si["f"]=true
      local to=ip.findUUID(si[#si["route"]-1])
      if not to then log("Unsuccessful search: Unknown IP: ",2)
      else modem.send(to,ports["mnp_srch"],"search",ser.serialize(si)) end --CORRECT
    else
      --write search :/
      local nodes=ip.getNodes(os.getenv("this_ip"))
      for uuid in pairs(nodes) do
        local rsi=session.addIpToSession(si,ip.findIP(uuid))
        modem.send(uuid,ports["mnp_srch"],"search",ser.serialize(rsi))
      end
    end
  else --returning to requester
    local num=0
    for n,v in pairs(si["route"]) do
      if v==os.getenv("this_ip") then num=n break end
    end
    if num>1 then --OPTIMIZATION REQUIRED
      local to=ip.findUUID(si["route"][tonumber(num-1)])
      if not to then log("Unsuccessful search: Unknown IP: ",2) 
      else modem.send(to,ports["mnp_srch"],"search",ser.serialize(si)) end
    else --local
      local to=ip.findUUID(si["route"][0])
      if not to then log("Unsuccessful search: Unknown IP: ",2)
      else modem.send(to,ports["mnp_srch"],"search",ser.serialize(si)) end
    end
  end
end
function mnp.data(from,sessionInfo,data) --deprecated;do not use
  if not from then return false end
  if not session.checkSession(sessionInfo) then return false end
  if not sessionInfo["f"] then return false end
  local current=0
  for key,val in pairs(sessionInfo) do
    if val==os.getenv("this_ip") then current=key break end
  end
  local t_uuid=ip.findUUID(sessionInfo[current+1])
  if not t_uuid then return false
  else modem.send(t_uuid,ports["mnp_data"],"data",ser.serialize(sessionInfo),data) end
end
function mnp.data(from,sessionInfo,data)
  if not from then return false end
  if not session.checkSession(sessionInfo) then return false end
  if not sessionInfo["f"] then return false end
  local current=0
  for key,val in pairs(sessionInfo["route"]) do
    if val==os.getenv("this_ip") then current=key break end
  end
  local t_uuid=ip.findUUID(sessionInfo["route"][current+1])
  if not t_uuid then return false
  else modem.send(t_uuid,ports["mnp_data"],"data",ser.serialize(sessionInfo),data) end
end

function mnp.dnsLookup(from,sessionInfo,data) --TODO: return error codes
  if not ip.isUUID(from) or not session.checkSession(sessionInfo) or not data then
    log("Unvalid arguments for dns lookup",2)
    return false
  end
  local si=sessionInfo --FIX: already unserialized, dum-dum
  data=ser.unserialize(data)
  if not si["f"] then --lookup
    for k,v in pairs(si["route"]) do --check if looped
      if v==os.getenv("this_ip") then
        log("Search discarded: looped",1)
        return false 
      end
    end
    if si["ttl"]<=1 then
      log("Search discarded: ttl is 1",1)
      if ttllog then
        log("Saving session info to latest_ttl.log",1)
        local file=io.open("latest_ttl.log","w")
        file:write("["..computer.uptime().."]Latest TTL discardment (DNS lookup)")
        file:write(ser.unserialize(sessionInfo,true))
        file:close()
      end
      return false
    end
    --check local
    local d_ip = dns.lookup(data[1])
    if d_ip then --found
      data[2]="D1"
      data[3]=d_ip
      si["f"]=true
      si["r"]=true
      si=session.addIpToSession(si,os.getenv("this_ip"))
      si=session.addIpToSession(si,d_ip)
      --send(im tired)
      local to=ip.findUUID(si[#si["route"]-2])
      if not to then log("Unsuccessful dns lookup: Unknown IP: ",2)
      else modem.send(to,ports["dns_lookup"],"dns_lookup",ser.serialize(si),ser.serialize(data)) end --send
    else --not found
      --send to other nodes
      local nodes=ip.getNodes(os.getenv("this_ip"))
      for uuid in pairs(nodes) do
        local rsi=session.addIpToSession(si,ip.findIP(uuid))
        modem.send(uuid,ports["mnp_srch"],"dns_lookup",ser.serialize(rsi),ser.serialize(data))
      end
    end
  else --returning to requester
    local num=0
    for n,v in pairs(si["route"]) do
      if v==os.getenv("this_ip") then num=n break end
    end
    if num>1 then --OPTIMIZATION REQUIRED
      local to=ip.findUUID(si["route"][tonumber(num-1)])
      if not to then log("Unsuccessful dns lookup: Unknown IP: ",2) 
      else modem.send(to,ports["dns_lookup"],"dns_lookup",ser.serialize(si),ser.serialize(data)) end
    else --local
      local to=ip.findUUID(si["route"][0])
      if not to then log("Unsuccessful dns lookup: Unknown IP: ",2)
      else modem.send(to,ports["dns_lookup"],"dns_lookup",ser.serialize(si),ser.serialize(data)) end
    end
  end
end
function mnp.pass(port,mtype,si,data) --node
  if not port or not mtype or not si then return false end
  local num=0
  for n,v in pairs(si["route"]) do
    if v==os.getenv("this_ip") then num=n break end
  end
  if num>1 then --OPTIMIZATION REQUIRED
    local to
    if si["r"]==true then to=ip.findUUID(si["route"][tonumber(num-1)])
    else to=ip.findUUID(si["route"][tonumber(num+1)]) end
    if not to then log("Unsuccessful dns lookup: Unknown IP: ",2) 
    else modem.send(to,ports["mnp_data"],"data",ser.serialize(si),data) end
  else --local
    local to
    if si["r"]==true then to=ip.findUUID(si[tonumber(num-1)])
    else to=ip.findUUID(si["route"][tonumber(num+1)]) end
    if not to then log("Unsuccessful dns lookup: Unknown IP: ",2)
    else modem.send(to,ports["mnp_data"],"data",ser.serialize(si),data) end
  end
  return true
end
-------

return mnp
--[[ session
[uuid]:<session uuid>
[t]:<target_ip>
[ttl]:<time-to-live>
[c]:<int(num of ips)>
[0]:<ip(from)>
[1]:<ip(node)>
...
[c-1]:<ip(target)>
[f]:<found? bool>
[r]:<reverse? bool>
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
--[[ PORTS
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
2000+ - Protocols
3000+ - For Server Use
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