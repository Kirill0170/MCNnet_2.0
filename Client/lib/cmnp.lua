--Mcn-net Networking Protocol for Client v2.1 EXPERIMENTAL
--Modem is required.
local dolog=false --log
local networkSaveFileName="/usr/.mnpSavedNetworks.sb"-- array[netname]=<uuid-address>
local routeSaveFileName="/usr/.mnpSavedRoutes.sb" --array[to_ip]=<route>
local component=require("component")
local computer=require("computer")
local ser=require("serialization")
local session=require("session")
local modem=component.modem
local thread=require("thread")
local event=require("event")
local ip=require("ipv2")
local gpu=component.gpu
local mnp_ver="2.37 REWORK INDEV"
local mncp_ver="2.3 REWORK INDEV"
local forbidden_vers={}
forbidden_vers["mnp"]={"2.21 EXPERIMENTAL"}
forbidden_vers["mncp"]={"2.1 EXPERIMENTAL"}
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
local function timer(time,name)
  os.sleep(time)
  computer.pushSignal("timeout",name)
end
--MNCP-----------------------------------
function mnp.mncp_CliService() --REDO
  if not modem.isOpen(ports["mncp_srvc"]) then modem.open(ports["mncp_srvc"]) end
  log("Started MNCP service")
  while true do
    local id,_,from,port,_,mtype,si=event.pullMultiple("modem","mncp_cliSrvc_stop")
    if id=="mncp_cliSrvc_stop" then break end
    if port==ports["mncp_srvc"] and mtype=="mncp_check" then
      local si=ser.unserialize(si)
      si["r"]=~si["r"]
      local to_ip=si["route"][0]
      modem.send(from,ports["mncp_srvc"],"mncp_check",ser.serialize(session.newSession()))
    end
  end
end
function mnp.mncp_nodePing(timeoutTime)
  if not modem.isOpen(ports["mncp_ping"]) then modem.open(ports["mncp_ping"]) end
  if not ip.isUUID(os.getenv("node_uuid")) or not ip.isIPv2(os.getenv("this_ip")) then
    return nil
  end
  if not timeoutTime then timeoutTime=10 end
  local start_time=computer.uptime()
  local end_time=0
  local timeout=false
  thread.create(timer,timeoutTime,"ping"..start_time):detach()
  while not timeout do
    modem.send(os.getenv("node_uuid"),ports["mncp_ping"],"mncp_ping",ser.serialize(session.newSession()))
    local id,name,from,port,_,mtype,si=event.pullMultiple("timeout","modem_message","interrupted")
    if id=="interrupted" then timeout=true
    elseif id=="timeout" and name=="ping"..start_time then timeout=true
    elseif id=="modem_message" then
      if from==os.getenv("node_uuid") and port==ports["mncp_ping"] and mtype=="mncp_ping" then
        end_time=computer.uptime()
        break
      else
        print("[debug]some other modem answered?")
      end
    end
  end
  if timeout then return nil
  elseif end_time~=0 then return tonumber(end_time)-tonumber(start_time)
  else return nil end --fail??
end
function mnp.mncp_c2cPing(to_ip)
  --write
end
--MNP------------------------------------
--Util-
function log(text,crit)
  local res="["..computer.uptime().."]"
  if dolog and crit==0 or not crit then
    print(res.."[MNP/INFO]"..text)
  elseif dolog and crit==1 then
    gpu.setForeground(0xFFCC33)
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
  --rewrite
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
----------Saving Node Addresses------------
function mnp.setNetworkSaveFileName(newName) networkSaveFileName=newName end
function mnp.loadSavedNodes()
  local file=io.open(networkSaveFileName,"r")
  if not file then --initialize file
    file=io.open(networkSaveFileName,"w")
    file:write(ser.serialize({}))
    file:close()
    return {}
  end
  savedata=ser.unserialize(file:read("*a"))
  file:close()
  savedata2={}
  --checks
  if type(savedata)~="table" then return {} end
  for netname,n_uuid in pairs(savedata) do
    if ip.isUUID(n_uuid) then
      savedata2[netname]=n_uuid
    end
  end
  return savedata2
end
function mnp.saveNodes(table)
  if type(table)~="table" then return false end
  local file=io.open(networkSaveFileName, "w")
  file:write(ser.serialize(table))
  file:close()
  return true
end
function mnp.getSavedNode(networkName)
  local table=mnp.loadSavedNodes()
  for netname,from in pairs(table) do
    if netname==networkName then return from end 
  end
  return nil
end
function mnp.checkHostname(name) --imported from dns.lua
  if not name then return false end
  local pattern = "^%w+%.%w+$"
  return string.match(name, pattern) ~= nil
end
-----------Saving searched routes------------
function mnp.setRouteSaveFileName(newName) routeSaveFileName=newName end
function mnp.loadRoutes()
  local file=io.open(routeSaveFileName,"r")
  if not file then --initialize file
    file=io.open(routeSaveFileName,"w")
    file:write(ser.serialize({}))
    file:close()
    return {}
  end
  savedata=ser.unserialize(file:read("*a"))
  file:close()
  savedata2={}
  --checks
  if type(savedata)~="table" then return {} end
  for s_ip,route in pairs(savedata) do
    if ip.isIPv2(s_ip) and session.checkRoute(route) then
      savedata2[s_ip]=route
    end
  end
  return savedata2
end
function mnp.getSavedRoute(to_ip)
  if not ip.isIPv2(to_ip) then return nil end
  local saved=mnp.loadRoutes()
  if saved=={} then return nil end
  return saved[to_ip]
end
function mnp.saveRoute(to_ip,route)
  if not session.checkRoute(route) or not ip.isIPv2(to_ip) then return false end
  local saved=mnp.loadRoutes()
  saved[to_ip]=route
  local file=io.open(routeSaveFileName,"w")
  file:write(ser.serialize(saved))
  file:close()
  return true
end
--Main-
function mnp.networkSearch(searchTime,save)
  if not searchTime then searchTime=10 end
  local saveTable=nil
  if save then
    saveTable=mnp.loadSavedNodes()
  end
  if not ip.isIPv2(os.getenv("this_ip")) then
    os.setenv("this_ip","0000:0000")
  end
  local res={}--res[netname]={from,dist}
  local timerName="ns"..computer.uptime()
  if not modem.isOpen(ports["mnp_reg"]) then modem.open(ports["mnp_reg"]) end
  thread.create(timer,searchTime,timerName):detach()
  while true do
    modem.broadcast(ports["mnp_reg"],"netsearch",ser.serialize(session.newSession()),ser.serialize({res}))
    local id,name,from,port,dist,mtype,si,data=event.pullMultiple("modem","timeout","interrupted")
    if id=="interrupted" then break
    elseif id=="timeout" and name==timerName then break
    else
      if port==ports["mnp_reg"] then
        if not session.checkSession(ser.unserialize(si)) then log("Invalid session on netsearch")
        else
          data=ser.unserialize(data)
          if data[1]~=nil then --netname found
            res[data[1]]={from,dist}
            if save then saveTable[data[1]]=from end
          end
        end
      end
    end
  end
  if save then mnp.saveNodes(saveTable) end
  return res --table[netname]={<uuid>,dist}
end

function mnp.networkConnectByName(from,name)
  if not name then return false end
  os.setenv("this_ip","0000:0000")
  os.setenv("node_uuid",nil)
  local rsi=ser.serialize(session.newSession(os.getenv("this_ip")))--!!
  local sdata={name}
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
   os.setenv("node_uuid",nil)
   ip.remove()
end

function mnp.isConnected(ping)
  if ip.isUUID(os.getenv("node_uuid")) and ip.isIPv2(os.getenv("this_ip")) then
    if os.getenv("this_ip")=="0000:0000" then return false end
    if ping then
      if not mnp.mncp_nodePing(1) then return false end
      return true
    end
    return true
  end
  return false
end

function mnp.search(to_ip,searchTime)
  if not mnp.isConnected() then return false end
  if not ip.isIPv2(to_ip) then return false end
  if not searchTime then searchTime=120 end
  local timerName="ms"..computer.uptime()
  local timerName="mnpsrch"..computer.uptime()
  local si=session.newSession(to_ip)
  mnp.openPorts()
  log("Started search for "..to_ip)
  modem.send(os.getenv("node_uuid"),ports["mnp_srch"],"search",ser.serialize(si))
  local start_time=computer.uptime()
  thread.create(timer,searchTime,timerName):detach()
  while true do
    local id,name,from,port,_,mtype,rsi=event.pullMultiple(1,"modem","interrupted","timeout")
    if id=="interrupted" then break
    elseif id=="timeout" then
      if name==timerName then break end
    else
      if from==os.getenv("node_uuid") and port==ports["mnp_srch"] and mtype=="search" then
        rsi=ser.unserialize(rsi)
        if rsi["f"]==true and rsi["route"][#rsi["route"]]==to_ip then
          mnp.saveRoute(to_ip,rsi["route"])
          return true
        else --error
          if rsi["route"][#rsi["route"]]~="to_ip" then --traceback
            log("Search failed: incorrect final ip",1)
            log("Route stack:",1)
            for i in pairs(rsi["route"]) do
              log("<route:"..tostring(i)..">:"..rsi["route"][i],1)
            end
            return false
          end
        end
      end
    end
  end
  log("Search failed: timeout",1)
  return false
end
function mnp.server_connection(si,data,connectedList) --for server REWRITE, DO NOT USE
  if not mnp.isConnected() then return false end
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
function mnp.send(to_ip,mtype,data,do_search)
  if not mnp.isConnected() then return 1 end
  if not mtype then mtype="data" end
  if not data then data={} end
  if do_search==nil then do_search=true end
  local route=mnp.getSavedRoute(to_ip)
  if not route then
    if not do_search then
      log("No route to "..to_ip,1)
      return 2
    else
      if mnp.search(to_ip) then
        route=mnp.getSavedRoute(to_ip)
      else
        log("No route to "..to_ip..", search failed.",1)
        return 3
      end
    end
  end
  local si=session.newSession(to_ip,route)
  to_uuid=os.getenv("node_uuid")
  modem.send(to_uuid,ports["mnp_data"],mtype,ser.serialize(si),ser.serialize(data))
  return 0
end
function mnp.sendBack(mtype,si,data)--REVIEW
  if not mnp.isConnected() then return false end
  if not session.checkSession(si) then return false end
  si["r"]=true
  if not data then data={} end
  modem.send(os.getenv("node_uuid"),ports["mnp_data"],mtype,ser.serialize(si),ser.serialize(data))
end
function mnp.receive(from_ip,mtype,timeoutTime,rememberRoute)--REVIEW
  if not mnp.isConnected() then return nil end
  if not mtype then return nil end
  if not timeoutTime then timeoutTime=10 end
  if not rememberRoute then rememberRoute=false end
  local timerName="r"..computer.uptime()
  thread.create(timer,timeoutTime,timerName):detach()
  while true do
    local id,name,from,port,_,rmtype,si,data=event.pullMultiple("modem","timeout")
    if id=="timeout" and name==timerName then
      break
    elseif id=="modem_message" then
      if not si then return nil end
      si=ser.unserialize(si)
      if session.checkSession(si) and from==os.getenv("node_uuid") and port==ports["mnp_data"] and rmtype==mtype then
        if si["t"]==from_ip or si["route"][0]==from_ip or from_ip=="broadcast" then
          if rememberRoute then
            if si["r"]==false then --should remember
              mnp.saveRoute(si["route"][0],session.reverseRoute(si["route"]))
            end
          end
          return ser.unserialize(data)
        end
      end
    end
  end
  return nil
end
function mnp.listen(from_ip,mtype,stopEvent,dataEvent)
  if not mnp.isConnected() or type(mtype)~="string" or type(stopEvent)~="string" or type(dataEvent)~="string" then return nil end
  while true do
    local id,_,from,port,_,rmtype,si,data=event.pullMultiple("modem",stopEvent)
    if id==stopEvent then
      break
    else
      if si and data then
        si=ser.unserialize(si)
        data=ser.unserialize(data)
        if session.checkSession(si) and from==os.getenv("node_uuid") and port==ports["mnp_data"] and rmtype==mtype and data then
          if si["t"]==from_ip or si["route"][0]==from_ip or from_ip=="broadcast" then
            computer.pushSignal(dataEvent,ser.serialize(data),ser.serialize(si))
          end
        end
      end
    end
  end
end
return mnp
--require("component").modem.send(os.getenv("node_uuid"),1000,"debug_nips",require("serialization").serialize(require("session").newSession()))
--require("component").modem.send(os.getenv("node_uuid"),1002,"debug_data",require("serialization").serialize(require("session").newSession(to_ip,cmnp.getSavedRoute(to_ip))),"data",require("serialization").serialize({"data"}))