--Mcn-net Networking Protocol v2.1 EXPERIMENTAL
--With Session Protocol v1.21 EXPERIMENTAL
--Modem is required.
local dolog=true --log?
local ttllog=true --log ttl discardment?
local mncplog=true --log MNCP checks?
local component=require("component")
local computer=require("computer")
local ser=require("serialization")
local modem=component.modem
local event=require("event")
local ip=require("ipv2")
local dns=require("dns")
local gpu=component.gpu
local mnp_ver="2.1 EXPERIMENTAL"
local ses_ver="1.21 EXPERIMENTAL"
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
print("[MNP INIT]: SP version "..ses_ver)
print("[MNP INIT]: IP version "..ip.ver())
print("[MNP INIT]: DNS version "..dns.ver())
print("[MNP INIT]: Done")
--Session--------------------------------
function mnp.checkSession(sessionInfo)
  if not sessionInfo then return false end
  if not ip.isUUID(sessionInfo["uuid"]) then return false end
  if not ip.isIPv2(sessionInfo[0]) then return false end
  if not tonumber(sessionInfo["ttl"]) then return false end
  if not tonumber(sessionInfo["c"]) then return false end
  if not ip.isIPv2(sessionInfo["t"]) and sessionInfo["t"]~="broadcast" then return false end
  return true
end
function mnp.newSession(from_ip,to_ip,ttl)
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
function mnp.addIpToSession(sessionInfo,ip_a)
  if not mnp.checkSession(sessionInfo) then error("[MNP SESSION ADD]: Invalid Session") end
  if not ip.isIPv2(ip_a) then error("[MNP SESSION ADD]: Not an IP") end
  sessionInfo[sessionInfo["c"]]=ip_a
  sessionInfo["c"]=sessionInfo["c"]+1
  return sessionInfo
end
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
        modem.send(n_uuid,ports["mncp_srvc"],"mncp_check",ser.serialize(mnp.newSession(os.getenv("this_ip"),n_ip,1)))
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
function mnp.crash(reason)
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
--Main-
--reg--
function mnp.node_chkreg(from,sessionInfo)
  if not ip.isUUID(from) or not sessionInfo then return false end
  sessionInfo=ser.unserialize(sessionInfo)
  if not mnp.checkSession(sessionInfo) then return false end
  if ip.isIPv2(sessionInfo[0],true) then
    if string.sub(from,1,4)==sessionInfo[0] then
      ip.addUUID(from,true)
      log("New node: "..string.sub(from,1,4))
      modem.send(from,ports["mnp_reg"],ser.serialize(mnp.newSession(os.getenv("this_ip"))),"ok")
      return true
    else
      log("Unvalid sessionInfo: IP doesn't correspond to uuid",1)
      return false
    end
  end
end

function mnp.node_register(a,t)
  if not a then a=5 end
  if not t then t=2 end
  local ct=false
  if not ip.isIPv2(os.getenv("this_ip"),true) then
    log("Node IP not set!",2)
    return false
  end
  if not modem.isOpen(ports["mnp_reg"]) then ct=true modem.open(ports["mnp_reg"]) end
  for i=0,a do --packetas
    local rsi=ser.serialize(mnp.newSession(os.getenv("this_ip"),"",1))
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
function mnp.register(from,si)
  if not from or not mnp.checkSession(si) then
    log("Unvalid arguments for register",2)
    return false
  end
  if si["c"]>1 then
    log("Non-local registration is not supported: c="..si["c"],2)
    return false
  end
  if ip.isIPv2(si[0],true) then --node
    for n_ip,_ in pairs(ip.getNodes()) do
      if si[0]==n_ip then
        return nil
      end
    end
    ip.addUUID(from,true)
    --send succeessful registration
    local rsi=ser.serialize(mnp.newSession(os.getenv("this_ip"),"",1))
    modem.send(from,ports["mnp_reg"],rsi)
    log("Registered new node: "..si[0])
    return true
  elseif ip.isIPv2(si[0]) then --client/server
      ip.addUUID(from)
      local rsi=ser.serialize(mnp.newSession(os.getenv("this_ip"),"",1))
      modem.send(from,ports["mnp_reg"],rsi)
      log("Registered new server/client: "..si[0])
  else
    log("Registartion failed: unknown IPv2 error",1)
    return false
  end
end

function mnp.search(from,sessionInfo)
  if not ip.isUUID(from) or not mnp.checkSession(sessionInfo) then
    log("Unvalid arguments for search",2)
    return false
  end
  local si=ser.unserialize(sessionInfo)
  if not si["f"] then --search
    if si["ttl"]<=1 then
      log("Search discarded: ttl is 1",1)
      if ttllog then
        log("Saving session info to latest_ttl.log",1)
        local file=io.open("latest_ttl.log","w")
        file:write("["..computer.uptime().."]Latest TTL discardment")
        file:write(ser.unserialize(sessionInfo,true))
        file:close()
      end
      return false
    end
    --check local
    local l_uuid=ip.findUUID(si["t"])
    if l_uuid then --its here!
      --server ping?
      si[si["c"]]=ip.findIP(l_uuid)
      si["c"]=si["c"]+1
      si["f"]=true
      local to=ip.findUUID(si[tonumber(si["c"])-1])
      if not to then log("Unsuccessful search: Unknown IP: ",2)
      else modem.send(to,ports["mnp_srch"],ser.serialize(si)) end --CORRECT
    end
  else --returning to requester
    local num=0
    for n,v in pairs(si) do
      if v==os.getenv("this_ip") then num=n break end
    end
    if num>1 then
      local to=ip.findUUID(si[tonumber(num-1)])
      if not to then log("Unsuccessful search: Unknown IP: ",2) 
      else modem.send(to,ports["mnp_srch"],sessionInfo) end
    else --local
      local to=ip.findUUID(si[0])
      if not to then log("Unsuccessful search: Unknown IP: ",2)
      else modem.send(to,ports["mnp_srch"],sessionInfo) end
    end
  end
end
function mnp.data(from,sessionInfo,data)
  if not from then return false end
  if not mnp.checkSession(sessionInfo) then return false end
  if not sessionInfo["f"] then return false end
  local current=0
  for key,val in pairs(sessionInfo) do
    if val==os.getenv("this_ip") then current=key break end
  end
  local t_uuid=ip.findUUID(sessionInfo[current+1])
  if not t_uuid then return false
  else modem.send(t_uuid,ports["mnp_data"],"data",ser.serialize(sessionInfo),data) end
end
function mnp.dnsLookup(from,si,data)
  
end
-------

return mnp
