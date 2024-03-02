--Mcn-net Networking Protocol for Client v2.1 EXPERIMENTAL
--Modem is required.
local dolog=false --log
local saveFileName="SavedSessionTemplates" --change if you want 
local component=require("component")
local computer=require("computer")
local ser=require("serialization")
local session=require("session")
local modem=component.modem
local thread=require("thread")
local event=require("event")
local ip=require("ipv2")
local gpu=component.gpu
local mnp_ver="2.21 EXPERIMENTAL"
local mncp_ver="2.0 EXPERIMENTAL"
local sp={} --stores patterns of sessions to some IP| "IP"=session
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
if dolog then
  print("[MNP INIT]: Starting...")
  print("[MNP INIT]: MNP version "..mnp_ver)
  print("[MNP INIT]: MNCP version "..mncp_ver)
  print("[MNP INIT]: SP version "..session.ver())
  print("[MNP INIT]: IP version "..ip.ver())
  print("[MNP INIT]: Done")
end
--MNCP-----------------------------------
function mnp.mncpCliService()
  if not modem.isOpen(ports["mncp_srvc"]) then modem.open(ports["mncp_srvc"]) end
  log("Started MNCP service")
  while true do
    local _,_,from,port,_,mtype,si=event.pull("modem")
    if port==ports["mncp_srvc"] and mtype=="mncp_check" then
      local to_ip=ser.unserialize(si)["route"][0]
      modem.send(from,ports["mncp_srvc"],"mncp_check",ser.serialize(session.newSession(os.getenv("this_ip"),to_ip,2)))
    end
  end
end
--DNS------------------------------------
function mnp.dnsService() --SERVER USAGE ONLY(DEPRECATED)
  if dnsName then
    local err=false
    repeat
      local _,_,from,port,_,mtype,si,data=event.pull("modem")
      if port==ports["dns_lookup"] and mtype=="dnslookup" then
      end
    until err
  else return false end
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
function timer(time,name)
  os.sleep(time)
  computer.pushSignal("timeout",name)
end
function mnp.crash(reason) --do not use
  modem.open(ports["mncp_err"])
  modem.broadcast(ports["mncp_err"],"crash","client",reason)
end
function mnp.openPorts(plog)
  for name,port in pairs(ports) do
    if plog then log("Opening "..name) end
    if not modem.open(port) and not modem.isOpen(port) then return false end
  end
  return true
end
function mnp.toggleLog(change)
  if change==true or change==false then 
    dolog=change
    return true
  else return false end
end
--Saving Patterns-
function mnp.setSaveFileName(newName) saveFileName=newName end
function mnp.loadSavedPatterns()
  local file=io.open(saveFileName..".sst","r")
  savedata=ser.unserialize(file:read("*a"))
  sp=savedata
  file:close()
end
function mnp.saveSavedPatterns()
  local file=io.open(saveFileName..".sst", "w")
  file:write(ser.serialize(sp))
  file:close()
end
function mnp.getPattern(to_ip)
  for ip,session in pairs(sp) do
    if ip==to_ip then return ser.unserialize(session) end 
  end
  return nil
end
function mnp.getIp(domain)
  for name,ip in pairs(sp) do
    if name==domian then return ip end
  end
  return nil
end
function mnp.savePattern(to_ip,session)
  sp[to_ip]=ser.serialize(session)
end
function mnp.saveDomain(domain,ip)
  sp[domain]=ip
end
local function checkHostname(name) --imported from dns.lua
  if not name then return false end
  local pattern = "^%w+%.%w+$"
  return string.match(name, pattern) ~= nil
end
--Main-
--------TO BE DELETED-------------------------------------------------
function mnp.register(a,t)--what a shame
  if not tonumber(a) or tonumber(a)<1 then a=1 end
  if not tonumber(t) then t=10 end
  local ca=0 --current attempt
  local ct=false --close port?
  local connect=false
  log("Activating registration")
  modem.setStrength(400)
  os.setenv("this_ip","0000:0000")
  local rsi=ser.serialize(session.newSession())
  if not modem.isOpen(ports["mnp_reg"]) then ct=true modem.open(ports["mnp_reg"]) end
  while not connect do
    if a>0 then ca=ca+1 end
    if ca>a and a>0 then break end
    modem.broadcast(ports["mnp_reg"],"register",rsi)
    local _,_,from,port,dist,mtype,si=event.pull(t,"modem")
    if from and si then
      si=ser.unserialize(si)
      if port==ports["mnp_reg"] and mtype=="register" and session.checkSession(si) then
        log("Connected to "..si["route"][0])
        connect=true
        ip.set(string.sub(si["route"][0],1,4))
        modem.setStrength(dist+10)
        os.setenv("node_uuid",from)--save
      end
    else
      log("Invaid packet",1)
    end
  end
  if ct then modem.close(ports["mnp_reg"]) end
  if not connect then return false end
  return true
end
----------------------------------------------------------------------
function mnp.networkSearch(searchTime) --idea: use a table to filter out used addresses
  if not searchTime then searchTime=10 end
  local res={}
  local timerName="ns"..computer.uptime()
  if not modem.isOpen(ports["mnp_reg"]) then mode.open(ports["mnp_reg"]) end
  thread.create(timer,searchTime,timerName):detach()
  while true do
    modem.broadcast(ports["mnp_reg"],"netsearch",ser.serialize(session.newSession()))
    local id,name,from,port,dist,mtype,si,data=event.pullMultiple("modem","timeout","interrupted")
    if id=="interrupted" then break
    elseif id=="timeout" and name==timerName then break
    else
      if port==ports["mnp_reg"] then
        if not session.checkSession(ser.unserialize(si)) then log("Invalid session on netsearch")
        else
          data=ser.unserialize(data)
          if data[1]~=nil then
            res[data[1]]={from,dist} --res[netname]={from,dist}
          end
        end
      end
    end
  end
  return res
end

function mnp.networkConnectByName(from,name,domain)
  if not name then return false end
  if domain and not checkHostname(domain) then log("Incorrect hostname!") return false end
  local rsi=ser.serialize(session.newSession(os.getenv("this_ip")))
  local sdata={name}
  if domain then sdata={name,domain} end
  modem.send(from,ports["mnp_reg"],"netconnect",rsi,ser.serialize(sdata))
  while true do
    local _,this,rfrom,port,_,mtype,si,data=event.pull(5,"modem")
    if not rfrom then
      log("Node timeouted")
      return false
    elseif port~=ports["mnp_reg"] or rfrom~=from then
    else
      data=ser.unserialize(data)
      if name==data[1] then
        log("Connected to "..name)
        if not ip.isIPv2(data[2]) then 
          log("incorrect IP received: aborted")
          return false
        end
        if not ip.set(data[2]) then
          log("Couldn't set IP, please debug!")
          return false
        else
          log("IP is set")
          os.setenv("node_uuid",from)
          return true
        end
      else
        log("Unexpected network name received")
        return false
      end
    end
  end
end

function mnp.disconnect()
   modem.send(os.getenv("node_uuid"),ports["mnp_reg"],"netdisconnect",ser.serialize(session.newSession()))
end

function mnp.search(to_ip,searchTime)--check si
  if not to_ip then return false end
  if not searchTime then searchTime=300 end
  local timerName="ms"..computer.uptime() --feel free to change first string
  local si=ser.serialize(session.newSession(to_ip))
  modem.send(os.getenv("node_uuid"),ports["mnp_srch"],"search",si)
  log("Stated search...")
  local start_time=computer.uptime()
  thread.create(timer,searchTime,timerName):detach()
  while true do
    local id,name,from,port,_,mtype,rsi=event.pullMultiple(1,"modem","interrupted","timeout")
    if id=="interrupted" then
      break
    elseif id=="timeout" then
      if name==timerName then break end
    else
      if port==ports["mnp_srch"] and from==os.getenv("n_uuid") and mtype=="search" then
        rsi=ser.unserialize(rsi)
        if not rsi["f"] then
          log("Search received SessionInfo with f=false/nil - Doing nothing",1)
        else
          --save session
          mnp.savePattern(rsi["t"],rsi)
          log("Search completed, took "..computer.uptime()-start_time)
          return true
        end
      end
    end
  end
  log("Search failed: timeout",1)
  return false
end
function mnp.dnslookup(hostname,searchTime) --fix: check si
  if not hostname then return false end
  if not searchTime then searchTime=300 end
  local timerName="mdl"..computer.uptime()
  local si=ser.serialize(session.newSession("broadcast"))
  data={}
  data[1]=hostname
  modem.send(os.getenv("node_uuid"),ports["dns_lookup"],"dnslookup",si,data)
  log("Stated dns_lookup...")
  local start_time=computer.uptime()
  thread.create(timer,searchTime,timerName):detach()
  while true do
    local id,name,from,port,_,mtype,rsi,data=event.pullMultiple(1,"modem","interrupted","timeout")
    if id=="interrupted" then
      break
    elseif id=="timeout" and name==timerName then
      break
    else
      if port==ports["dns_lookup"] and from==os.getenv("n_uuid") and mtype=="dnslookup" then
        rsi=ser.unserialize(rsi)
        if not rsi["f"] then
          log("DNS lookup received SessionInfo with f=false/nil - Doing nothing",1)
        else
          statusCode=data[2]
          if statusCode==1 then
            log("Lookup completed, took "..computer.uptime()-start_time)
            mnp.saveDomain(hostname,data[3])--hopefully this works
            mnp.savePattern(data[3],rsi)
          end
        end
      end
    end
  end
  log("DNS Lookup failed: timeout", 1)
  return false
end
function mnp.connect(sessionTemplate,attempts,timeout) --client (rewrite with timeout?)
  if not session.checkSession(sessionTemplate) or not sessionTemplate["f"] then return false end
  if not tonumber(attempts) then attempts=2 end
  if not tonumber(timeout) then timeout=5 end
  for att=1,attempts do
    log("Connecting.. attempt: "..att)
    modem.send(os.getenv("node_uuid"),ports["mnp_conn"],"connect",ser.serialize(sessionTemplate))
    local _,_,_,_,_,mtype,sessionInfo,data=event.pull(timeout,"modem")
    if mtype=="connection" and SessionInfo["t"]==os.getenv("this_ip") then --idk
      data=unserialize(data)
      statusCode=data[1]
      if statusCode==0 then --OK
        log("Connection established")
        os.setenv("conn_ip",sessionInfo)
        return true
      elseif statusCode==1 then --Error
        log("Connection returned error code 1",1)
        return false
      elseif statusCode==2 then --Forbidden
        log("Connection forbidden",1)
        return false
      else
        log("Connection returned unknown code",2)
        return false
      end
    else end --timeout/other stuff
  end
  log("Cannot connect",1)
  return false
end
function mnp.server_connection(si,data,connectedList) --server
  if not session.checkSession(si) or not data then return false end
  data=ser.unserialize(data)
  --banned uuids here
  for k,v in pairs(connectedList) do
    if v==si["route"][0] then return false end
  end
  table.insert(connectedList,si["route"][0])
  data={1}
  si["r"]=true
  modem.send(si["route"][#si["route"]-1],"connection",ser.serialize(si),ser.serialize(data))
end
function mnp.send(to_ip,mtype,data)
  if not mtype then mtype="data" end
  if not data then data={} end
  local si=mnp.getPattern(to_ip)
  if not si then return false end
  si["r"]=false
  to_uuid=os.getenv("node_uuid")
  modem.send(to_uuid,ports["mnp_data"],mtype,ser.serialize(si),ser.serialize(data))
end
function mnp.sendBack(mtype,si,data)
  if not session.checkSession(si) then return false end
  si["r"]=true
  if not data then data={} end
  modem.send(si["route"][#si["route"]-1],ports["mnp_data"],mtype,ser.serialize(si),ser.serialize(data))
end
function mnp.receive(from_ip,mtype,timeoutTime)
  local timerName="r"..computer.uptime()
  thread.create(timer,timeoutTime,timerName)
  while true do
    local id,name,_,port,_,rmtype,si,data=event.pullMultiple("modem","timeout")
    if id=="timeout" and name==timerName then
      break
    else
      si=ser.unserialize(si)
      if from==os.getenv("node_uuid") and port==ports["mnp_data"] and rmtype==mtype and si["t"]==from_ip then
        return ser.unserialize(data)
      end
    end
  end
  return nil
end
return mnp