--Node (beta)
local node_ver="[dev3 build2]"
local configFile="/etc/node.cfg"
local component=require("component")
local computer=require("computer")
local ser=require("serialization")
if not component.isAvailable("modem") then error("You gonna need a modem.") end
local modem=component.modem
local thread=require("thread")
local event=require("event")
local mnp=require("mnp")
local netpacket=require("netpacket")
local ip=require("ipv2")
Threads={}
ThreadStatus={}
local config={}
local passlog=true
local function packetThread(thread_id)
  local run=true
  mnp.log("Worker"..thread_id,"Online")
  local str="/w"..thread_id
  while run do
    local id,from,port,_,_,mtype,np,data=event.pullMultiple("modem","stop"..thread_id)
    if not np then mnp.log("Worker","No packet info received") return false end
    np=ser.unserialize(np)
    if data then data=ser.unserialize(data) end
    if not netpacket.checkPacket(np) then
      mnp.log("Worker","Incorrect packet received",1)
    end
    if mtype=="netconnect" then
      mnp.networkConnect(from,np,data,{config.clientPassword,config.nodePassword})
    elseif mtype=="netdisconnect" then
      mnp.networkDisconnect(from)
    elseif mtype=="netsearch" then
      mnp.networkSearch(from,np,data,config.clientPassword~="")
    elseif mtype=="search" then
      mnp.search(from,np)
    elseif mtype=="mncp_ping" then
      mnp.mncp.nodePing(from)
    elseif mtype=="netdata" then
      if passlog then
        mnp.log("NETPASS"..str,np["route"][0].."->"..np["t"].." "..ser.serialize(data))
      end
      local nmtype=data[1]
      local nmdata=data[3]
      if nmtype=="netdomain" then
        mnp.addDomain(nmdata)
      elseif nmtype=="deldomain" then
        mnp.removeDomain(nmdata)
      elseif nmtype=="" then

      end
      mnp.networkPass(data)
    elseif mtype=="setdomain" then
      mnp.setDomain(np,data)
    elseif mtype=="getdomain" then
      mnp.returnDomain(from,data)
    else --data
      if passlog then
        mnp.log("PASS"..str,np["route"][0].."->"..np["t"].." "..ser.serialize(data))
      end
      mnp.pass(port,mtype,np,data)
    end
    ThreadStatus[thread_id]="idle"
  end
  mnp.log("Worker"..thread_id,"Offline")
end
--setup
print("---------------------------")
mnp.log("NODE","Node "..node_ver.." Starting - Hello World!")
mnp.log("NODE","Reading config")
if not require("filesystem").exists(configFile) then
  mnp.log("NODE","Couldn't open config file",1)
  mnp.log("NODE","Continuing with default args: Internet \"\" \"\" 2 true true true 4",1)
  config.netName="Internet"
  config.clientPassword=""
  config.nodePassword=""
  config.searchTime=2
  config.log=true
  config.logTTL=true
  config.clearNIPS=true
  config.threads=4
  local file=io.open(configFile,"w")
  if not file then
    mnp.log('NODE',"Couldn't open "..configFile.." to write!",2)
  else
    file:write(ser.serialize(config,true))
    file:close()
  end
else
  local file=io.open(configFile)
  if not file then error("Couldn't open file(how)") end
  config=ser.unserialize(file:read("*a"))
  file:close()
  if not config then error("Couldn't read config") end
end
mnp.log("NODE","Checking modem")
if not modem.isWireless() then mnp.log("NODE","Modem is recommended to be wireless, bro",1)
else if modem.getStrength()<400 then mnp.log("NODE","Modem strength is recommended to be default 400",1) end end
mnp.log("NODE","Setting up ipv2...")
if not ip.set(ip.gnip(),true) then mnp.log("NODE","Could not set node IP",3) end
mnp.log("NODE","This node's IPv2 is "..ip.gnip())
if config.clearNIPS then ip.removeAll() end
mnp.log("NODE","Setting up MNP..")
mnp.logVersions()
if not mnp.openPorts() then mnp.log("NODE","Could not open ports",3) end
mnp.setNetworkName(config.netName)
mnp.log("NODE","Connecting to other nodes with "..config.netName.." name...")
mnp.log("NODE","Should take "..config.searchTime.." seconds, as described in "..configFile)
if not mnp.nodeConnect(config.searchTime,config.nodePassword) then mnp.log("NODE","Could not set connect to other nodes: check if ip is set?",3) end

mnp.log("NODE","Node Online!")
mnp.toggleLogs(config.log,config.logTTL)

packetThread(1)
--node protocol