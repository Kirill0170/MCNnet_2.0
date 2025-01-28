--Mcn-net Networking Protocol for Client BETA
--Modem is required.
local dolog=false
local experimental=true
local networkSaveFileName="/etc/mnp/SavedNetworks.st"-- array[<ipv2]>]={<netname>,<uuid-address>,<password>}
local routeSaveFileName="/etc/mnp/SavedRoutes.st" --array[<this_ip>][<ipv2>]=<route>
local domainSaveFileName="/etc/mnp/SavedDomains.st" --array[<domain>]={<ipv2>,<route>}
local component=require("component")
local computer=require("computer")
local ser=require("serialization")
local netpacket = require("netpacket")
local modem=component.modem
local fs=require("filesystem")
local thread=require("thread")
local event=require("event")
local ip=require("ipv2")
local gpu=component.gpu
local mnp_ver="2.6.3"
local mncp_ver="2.5"
local ports={}
ports["mnp_reg"]=1000
ports["mnp_srch"]=1001
ports["mnp_data"]=1002
ports["mncp_srvc"]=1003
ports["mncp_err"]=1004
ports["mncp_ping"]=1005
local mnp={}
mnp.mncp={}
function mnp.log(mod,text,crit)
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
    if not file then return nil end
		file:write(res .. text)
		file:close()
		error("Fatal error occured in runtime,see mnp_err.log file")
	else
	end
end
--init-----------------------------------
if not fs.exists('/etc/mnp') then
  fs.makeDirectory('/etc/mnp')
end
function mnp.logVersions()
	mnp.log("MNP","MNP version " .. mnp_ver)
	mnp.log("MNP","MNCP version " .. mncp_ver)
	mnp.log("MNP","NP version " .. netpacket.ver())
	mnp.log("MNP","IP version " .. ip.ver())
end
local function timer(time,name)
  os.sleep(time)
  computer.pushSignal("timeout",name)
end
--MNCP-----------------------------------
function mnp.mncp.c2cPingService(debug)
  if not modem.isOpen(ports["mncp_srvc"]) then modem.open(ports["mncp_srvc"]) end
  mnp.log("MNP","Started MNCP c2c ping service")
  while true do
    local id,_,from,port,_,mtype,np,data=event.pullMultiple("modem","mncp_stop")
    if id=="mncp_stop" then break end
    if mtype=="mncp_c2c" and np and data then
      np=ser.unserialize(np)
      if netpacket.checkPacket(np) then
        np["r"]=true
        np["c"]=np["c"]-1
        if debug then mnp.log("MCNP","C2C ping "..np["route"][0]) end
        modem.send(from,ports["mncp_srvc"],"mncp_c2c",ser.serialize(np),data)
      end
    end
  end
  mnp.log("MNP","Stopped MNCP c2c ping service")
end
function mnp.mncp.stopService() computer.pushSignal("mncp_stop") end
function mnp.mncp.nodePing(timeoutTime)
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
    modem.send(os.getenv("node_uuid"),ports["mncp_ping"],"mncp_ping",ser.serialize(netpacket.newPacket()))
    local id,name,from,port,_,mtype,np=event.pullMultiple("timeout","modem_message","interrupted")
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
function mnp.mncp.c2cPing(to_ip,timeoutTime)
  if not mnp.isConnected() then return nil end
  if not modem.isOpen(ports["mncp_srvc"]) then modem.open(ports["mncp_srvc"]) end
  if not ip.isIPv2(to_ip) then return nil end
  if not timeoutTime then timeoutTime=10 end
  local start_time=computer.uptime()
  local end_time=0
  local timeout=false
  local test_data="c2c_ping_data; data-size:32   =)"
  thread.create(timer,timeoutTime,"c2cping"..start_time):detach()
  while not timeout do
    local snp=netpacket.newPacket(to_ip,mnp.getSavedRoute(to_ip))
    modem.send(os.getenv("node_uuid"),ports["mncp_srvc"],"mncp_c2c",ser.serialize(snp),ser.serialize({test_data}))
    local id,name,from,port,_,mtype,np,data=event.pullMultiple("timeout","modem_message","interrupted")
    if id=="interrupted" then timeout=true
    elseif id=="timeout" and name=="c2cping"..start_time then timeout=true
    elseif id=="modem_message" then
      if np and data and from==os.getenv("node_uuid") and mtype=="mncp_c2c" then
        np=ser.unserialize(np)
        if netpacket.checkPacket(np) then
          if ser.unserialize(data)[1]==test_data then
            end_time=computer.uptime()
            break
          end
        end
      end
    end
  end
  if timeout then return nil
  elseif end_time~=0 then return tonumber(end_time)-tonumber(start_time)
  else return nil end
end
--MNP------------------------------------
--Util-
function mnp.openPorts(plog)
  for name,port in pairs(ports) do
    if plog then mnp.log("MNP","Opening "..name) end
    if not modem.open(port) and not modem.isOpen(port) then return false end
  end
  return true
end
function mnp.toggleLog(change)
  if type(change)=="boolean" then
    dolog=change
    return true
  else return false end
end
function mnp.checkHostname(name)
  if not name then return false end
  local pattern = "^%w+%.%w+$"
  return string.match(name, pattern) ~= nil
end
----------Saving Node Addresses------------
function mnp.setNetworkSaveFileName(newName) networkSaveFileName=newName end
function mnp.loadSavedNodes()
  local file=io.open(networkSaveFileName,"r")
  if not file then --initialize file
    file=io.open(networkSaveFileName,"w")
    if not file then
      error("Can't open file to write: "..networkSaveFileName)
    end
    file:write(ser.serialize({}))
    file:close()
    return {}
  end
  local savedata=ser.unserialize(file:read("*a"))
  file:close()
  local savedata2={}
  --checks
  if type(savedata)~="table" then return {} end
  for n_ip,n_data in pairs(savedata) do
    if ip.isUUID(n_data[2]) then
      savedata2[n_ip]=n_data
    end
  end
  return savedata2
end
function mnp.getSavedNode(networkName)--make for uuid?
  local table=mnp.loadSavedNodes()
  for n_ip,n_info in pairs(table) do
    if n_info[1]==networkName then return n_info[2],n_info[3],n_ip end
  end
  return nil
end
function mnp.getSavedNodeName(g_uuid)
  local table=mnp.loadSavedNodes()
  for n_ip,n_info in pairs(table) do
    if n_info[2]==g_uuid then return n_info[1],n_info[3],n_ip end
  end
  return nil
end
function mnp.saveNodes(table,force)
  if type(table)~="table" then return false end
  if not force then
    local old_nodes=mnp.loadSavedNodes()
    for n_ip,n_data in pairs(table) do
      if old_nodes[n_ip]~=nil then
        local password=n_data[3]
        if not password then password=old_nodes[n_ip][3] end
        table[n_ip][3]=password
      end
    end
  end
  local file=io.open(networkSaveFileName, "w")
  if not file then
    error("Can't open file to write: "..networkSaveFileName)
  end
  file:write(ser.serialize(table))
  file:close()
  return true
end
function mnp.addNodePassword(node_ip,password)
  local table=mnp.loadSavedNodes()
  for n_ip,n_data in pairs(table) do
    if n_ip==node_ip then
      table[n_ip][3]=password
      mnp.saveNodes(table)
      return true
    end
  end
  return false
end
-----------Saving searched routes------------
function mnp.setRouteSaveFileName(newName) routeSaveFileName=newName end
function mnp.loadRoutes()
  local file=io.open(routeSaveFileName,"r")
  if not file then --initialize file
    file=io.open(routeSaveFileName,"w")
    if not file then
      error("Can't open file to write: "..routeSaveFileName)
    end
    file:write(ser.serialize({}))
    file:close()
    return {}
  end
  local savedata=ser.unserialize(file:read("*a"))
  file:close()
  local savedata2={}
  --checks
  if type(savedata)~="table" then
    file=io.open(routeSaveFileName,"w")
    if not file then
      error("Can't open file to write: "..routeSaveFileName)
    end
    file:write(ser.serialize({}))
    file:close()
    return {}
  end
  -- for s_ip,route in pairs(savedata) do
  --   if ip.isIPv2(s_ip) and netpacket.checkRoute(route) then
  --     savedata2[s_ip]=route
  --   end
  -- end
  return savedata --dunno how to fix this.
end
function mnp.saveRoutes(table)
  if type(table)~="table" then return false end
  local file=io.open(routeSaveFileName,"w")
  if not file then
    error("Can't open file to write: "..routeSaveFileName)
  end
  file:write(ser.serialize(table))
  file:close()
  return true
end
function mnp.getSavedRoute(to_ip)
  local check,to_ip=ip.isIPv2(to_ip)
  if not check then return nil end
  local saved=mnp.loadRoutes()
  if saved=={} then return nil end
  local this_ip="unknown"
  if mnp.isConnected() then this_ip=os.getenv("this_ip") end
  if not saved[this_ip] then saved[this_ip]={} end
  local route=saved[this_ip][to_ip]
  if not route and experimental and mnp.isConnected() then --experimental transform
    mnp.log("MNP","Searching other routes for translatable..")
    local node_ip=string.sub(this_ip,1,4)..":0000"
    for saved_this_ip,dest_ips in pairs(saved) do
      for dest_ip,dest_route in pairs(dest_ips) do
        if dest_ip==to_ip and dest_route[1]==node_ip then
          --client is connected to the same node, we can transform
          mnp.log("MNP","Translating route!")
          dest_route[0]=this_ip
          mnp.saveRoute(to_ip,dest_route)
          return dest_route
        end
      end
    end
    mnp.log("MNP","Didn't find suitable routes")
  end
  return route
end
function mnp.saveRoute(to_ip,route)
  local check,to_ip=ip.isIPv2(to_ip)
  if not netpacket.checkRoute(route) or not check then return false end
  local saved=mnp.loadRoutes()
  local this_ip="unknown"
  if mnp.isConnected() then this_ip=os.getenv("this_ip") end
  if not saved[this_ip] then saved[this_ip]={} end
  saved[this_ip][to_ip]=route
  mnp.saveRoutes(saved)
end
-----------Main-----------------
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
    modem.broadcast(ports["mnp_reg"],"netsearch",ser.serialize(netpacket.newPacket()),ser.serialize(res))
    local id,name,from,port,dist,mtype,np,data=event.pullMultiple("modem","timeout","interrupted")
    if id=="interrupted" then break
    elseif id=="timeout" and name==timerName then break
    else
      if port==ports["mnp_reg"] then
        np=ser.unserialize(np)
        if not netpacket.checkPacket(np) then mnp.log("MNP","Invalid packet on netsearch")
        else
          data=ser.unserialize(data)
          if data[1]~=nil then --netname found
            res[np["route"][0]]={data[1],from,dist,data[2]}
            if save then saveTable[np["route"][0]]={data[1],from} end
          end
        end
      end
    end
  end
  if save then mnp.saveNodes(saveTable) end
  return res --table[node ip]={name,uuid,dist,requirePassword}
end

function mnp.networkConnectByName(to_uuid,name,password,force_dynamic)
  if not name then return false end
  if not password then password="" end
  if not force_dynamic then force_dynamic=true end
  os.setenv("this_ip","0000:0000")
  os.setenv("node_uuid",nil)
  local rnp=netpacket.newPacket(os.getenv("this_ip"))--!!
  local sdata={name,password,force_dynamic}
  if force_dynamic then mnp.log("MNP","Dynamic!")  end
  modem.send(to_uuid,ports["mnp_reg"],"netconnect",ser.serialize(rnp),ser.serialize(sdata))
  while true do
    local _,this,rfrom,port,_,mtype,np,data=event.pull(5,"modem")
    if not rfrom then
      mnp.log("MNP","Node timeouted")
      return false
    elseif port~=ports["mnp_reg"] or rfrom~=to_uuid then
    else
      data=ser.unserialize(data)
      if name==data[1] and mtype=="netconnect" then
        mnp.log("MNP","Connected to "..name)
        if not ip.isIPv2(data[2]) then
          mnp.log("MNP","incorrect IP received: aborted")
          return false
        end
        if not ip.set(data[2]) then
          mnp.log("MNP","Couldn't set IP, please debug!")
          return false
        else
          mnp.log("MNP","IP is set")
          os.setenv("node_uuid",to_uuid)
          return true
        end
      elseif mtype=="netforbidden" then
        mnp.log("MNP","Password incorrect!",1)
        return false,true
      else
        mnp.log("MNP","Unexpected network name received")
        return false
      end
    end
  end
end
function mnp.setDomain(domain)
  if not mnp.checkHostname(domain) then return false end
  if not mnp.isConnected() then return false end
  modem.send(os.getenv("node_uuid"),ports["mnp_reg"],"setdomain",ser.serialize(netpacket.newPacket()),ser.serialize({domain}))
  os.setenv("this_domain",domain)
  return true
end
function mnp.getDomainIP(domain)
  if not mnp.isConnected() then return false end
  modem.send(os.getenv("node_uuid"),ports["mnp_srch"],"getdomain",ser.serialize(netpacket.newPacket()),ser.serialize({domain}))
  local timerName="gd"..computer.uptime()
  thread.create(timer,5,timerName):detach()
  while true do
    local id,name,from,port,_,rmtype,np,data=event.pullMultiple("modem","timeout")
    if id=="timeout" and name==timerName then
      break
    elseif id=="modem_message" then
      if not np then return nil end
      np=ser.unserialize(np)
      if netpacket.checkPacket(np) and from==os.getenv("node_uuid") and port==ports["mnp_srch"] and rmtype=="getdomain" then
        data=ser.unserialize(data)
        if ip.isIPv2(data[1]) then return data[1] end
      end
    end
  end
  return nil
end
function mnp.disconnect()
   modem.send(os.getenv("node_uuid"),ports["mnp_reg"],"netdisconnect",ser.serialize(netpacket.newPacket()))
   os.setenv("node_uuid",nil)
   ip.remove()
end

function mnp.isConnected(ping)
  if ip.isUUID(os.getenv("node_uuid")) and ip.isIPv2(os.getenv("this_ip")) then
    if os.getenv("this_ip")=="0000:0000" then return false end
    if ping then
      if not mnp.mncp.nodePing(1) then return false end
      return true
    end
    return true
  end
  return false
end
function mnp.checkAvailability(dest)
  local to_ip,check
  if mnp.checkHostname(dest) then
    dest=mnp.getDomainIP(dest) or ""
  end
  check,to_ip=ip.isIPv2(dest)
  if not check then return false end
  if not mnp.getSavedRoute(to_ip) then
    mnp.log("MNP","No route to "..to_ip.." found. searching...",1)
    if not mnp.search(to_ip) then
      mnp.log("MNP","Failed search",1)
      return false
    end
  end
  if not mnp.getSavedRoute(to_ip) then mnp.log("MNP","Couldn't get route for "..to_ip,2) return false,nil end
  return true,to_ip
end
function mnp.search(to_ip,searchTime,domain)
  if not mnp.isConnected() then return false end
  if ip.isIPv2(to_ip)==false and to_ip~="" and to_ip~="broadcast" then return false end
  if not searchTime then searchTime=120 end
  local timerName="mnpsrch"..computer.uptime()
  if mnp.checkHostname(domain) then
    to_ip=mnp.getDomainIP(domain)
    if not ip.isIPv2(to_ip) then
      mnp.log("MNP","Coudn't get IPv2 from domain!")
      return false
    end
  end
  local np=netpacket.newPacket(to_ip)
  mnp.openPorts()
  mnp.log("MNP","Started search for "..to_ip)
  modem.send(os.getenv("node_uuid"),ports["mnp_srch"],"search",ser.serialize(np))
  thread.create(timer,searchTime,timerName):detach()
  while true do
    local id,name,from,port,_,mtype,rnp,data=event.pullMultiple(1,"modem","interrupted","timeout")
    if id=="interrupted" then break
    elseif id=="timeout" then
      if name==timerName then break end
    else
      if from==os.getenv("node_uuid") and port==ports["mnp_srch"] and mtype=="search" then
        rnp=ser.unserialize(rnp)
        if not netpacket.checkPacket(rnp) then 
          mnp.log("MNP","Invalid packet when finishing search",2)
          return false 
        end
        if rnp["f"]==true and rnp["route"][#rnp["route"]]==to_ip then
          mnp.saveRoute(to_ip,rnp["route"])
          return true
        else --error
          if rnp["route"][#rnp["route"]]~="to_ip" then --traceback
            mnp.log("MNP","Search failed: incorrect final ip",1)
            mnp.log("MNP","Route stack:",1)
            for i in pairs(rnp["route"]) do
              mnp.log("MNP","<route:"..tostring(i)..">:"..rnp["route"][i],1)
            end
            return false
          end
        end
      end
    end
  end
  mnp.log("MNP","Search failed: timeout",1)
  return false
end
function mnp.send(to_ip,mtype,data,do_search)
  if not mnp.isConnected() then return 1 end
  if not mtype then mtype="data" end
  if not data then data={} end
  if do_search==nil then do_search=true end
  local route=mnp.getSavedRoute(to_ip)
  if not route then
    if not do_search then
      mnp.log("MNP","No route to "..to_ip,1)
      return 2
    else
      if mnp.search(to_ip) then
        route=mnp.getSavedRoute(to_ip)
      else
        mnp.log("MNP","No route to "..to_ip..", search failed.",1)
        return 3
      end
    end
  end
  local np=netpacket.newPacket(to_ip,route)
  local to_uuid=os.getenv("node_uuid")
  modem.send(to_uuid,ports["mnp_data"],mtype,ser.serialize(np),ser.serialize(data))
  return 0
end
function mnp.receive(from_ip,mtype,timeoutTime,rememberRoute)--REVIEW
  if not mnp.isConnected() then return nil end
  if not mtype then return nil end
  if not timeoutTime then timeoutTime=10 end
  if not rememberRoute then rememberRoute=false end
  local timerName="r"..computer.uptime()
  thread.create(timer,timeoutTime,timerName):detach()
  while true do
    local id,name,from,port,_,rmtype,np,data=event.pullMultiple("modem","timeout")
    if id=="timeout" and name==timerName then
      break
    elseif id=="modem_message" then
      if not np then return nil end
      np=ser.unserialize(np)
      if netpacket.checkPacket(np) and from==os.getenv("node_uuid") and port==ports["mnp_data"] and rmtype==mtype then
        if np["t"]==from_ip or np["route"][0]==from_ip or from_ip=="broadcast" then
          if rememberRoute then
            if np["r"]==false then --should remember
              mnp.saveRoute(np["route"][0],netpacket.reverseRoute(np["route"]))
            end
          end
          return ser.unserialize(data),np
        end
      end
    end
  end
  return nil
end
function mnp.listen(from_ip,mtype,stopEvent,dataEvent)
  if not mnp.isConnected() or type(mtype)~="string" or type(stopEvent)~="string" or type(dataEvent)~="string" then return nil end
  while true do
    local id,_,from,port,_,rmtype,np,data=event.pullMultiple("modem",stopEvent)
    if id==stopEvent then
      break
    else
      if np and data then
        np=ser.unserialize(np)
        data=ser.unserialize(data)
        if netpacket.checkPacket(np) and from==os.getenv("node_uuid") and port==ports["mnp_data"] and rmtype==mtype and data then
          if np["t"]==from_ip or np["route"][0]==from_ip or from_ip=="broadcast" then
            computer.pushSignal(dataEvent,ser.serialize(data),np["route"][0])
          end
        end
      end
    end
  end
end
return mnp
--require("component").modem.send(os.getenv("node_uuid"),1000,"debug_nips",require("serialization").serialize(require("netpacket").newPacket()))
--require("component").modem.send(os.getenv("node_uuid"),1002,"debug_data",require("serialization").serialize(require("netpacket").newPacket(to_ip,cmnp.getSavedRoute(to_ip))),"data",require("serialization").serialize({"data"}))