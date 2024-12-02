--Node (beta)
local node_ver="[beta2 build1]"
local configFile="nodeconfig"
local component=require("component")
local computer=require("computer")
local ser=require("serialization")
if not component.isAvailable("modem") then error("You gonna need a modem.") end
local modem=component.modem
local thread=require("thread")
local event=require("event")
local gpu=component.gpu
local mnp=require("mnp")
local netpacket=require("netpacket")
local ip=require("ipv2")
local dns=require("dns")
Threads={}
ThreadStatus={}
local function packetThread(thread_id)
  local run=true
  mnp.log("Worker"..thread_id,"Online")
  while run do 
    local id,from,port,mtype,np,data=event.pullMultiple("packet"..thread_id,"stop"..thread_id)
    if id=="stop"..thread_id then run=false break end
    ThreadStatus[thread_id]="busy"
    if not np then mnp.log("NODE","No packet info received") return false end
    np=ser.unserialize(np)
    if data then data=ser.unserialize(data) end
    if not netpacket.checkPacket(np) then 
      mnp.log("NODE","Incorrect packet received",1)
      return false 
    end
    if mtype=="netconnect" then
      mnp.networkConnect(from,np,data)
    elseif mtype=="netdisconnect" then
      mnp.networkDisconnect(from)
    elseif mtype=="netsearch" then
      mnp.networkSearch(from,np,data)
    elseif mtype=="search" then
      mnp.search(from,np)
    elseif mtype=="dns_lookup" then
      mnp.dnsLookup(from,np,data)
    elseif mtype=="mncp_ping" then
      mnp.mncp.nodePing(from)
    else --data
      mnp.pass(port,mtype,np,data)
    end
    ThreadStatus[thread_id]="idle"
  end
  mnp.log("Worker"..thread_id,"Offline")
end
--setup
os.sleep(0.1)
print("---------------------------")
mnp.log("NODE","Node "..node_ver.." Starting - Hello World!")
mnp.log("NODE","Reading config")
local config={}
if not require("filesystem").exists("/lib/"..configFile..".lua") then 
  mnp.log("NODE","Couldn't open config file",1)
  mnp.log("NODE","Continuing with default args: Internet 10 true true true",1)
  config.netName="Internet"
  config.searchTime=10
  config.log=true
  config.logTTL=true
  config.clearNIPS=true
  config.threads=4
else config=require(configFile)
end

mnp.log("NODE","Checking modem")
if not modem.isWireless() then mnp.log("NODE","Modem is recommended to be wireless, bro",1) end
if modem.getStrength()<400 then mnp.log("NODE","Modem strength is recommended to be default 400",1) end
mnp.log("NODE","Setting up ipv2...")
if not ip.set(ip.gnip(),true) then mnp.log("NODE","Could not set node IP",3) end
mnp.log("NODE","This node's IPv2 is "..ip.gnip())
if config.clearNIPS then ip.removeAll() end
mnp.log("NODE","Setting up DNS...")
dns.init()
mnp.log("NODE","Setting up MNP..")
mnp.logVersions()
if not mnp.openPorts() then mnp.log("NODE","Could not open ports",3) end
mnp.setNetworkName(config.netName)
mnp.log("NODE","Connecting to other nodes with "..config.netName.." name...")
mnp.log("NODE","Should take "..config.searchTime.." seconds, as described in /lib/nodeconfig.lua")
if not mnp.nodeConnect(config.searchTime) then mnp.log("NODE","Could not set connect to other nodes: check if ip is set?",3) end
mnp.log("NODE","Starting "..config.threads.." workers...")
for i=1,config.threads do
  ThreadStatus[i]="idle"
  Threads[i]=thread.create(packetThread,i):detach()
end
--main
mnp.log("NODE","Node Online!")
mnp.log("NODE","Press space for debug.")
mnp.toggleLogs(config.log,config.logTTL)

while true do
  local id,_,from,port,dist,mtype,np,data=event.pullMultiple("interrupted","modem","key_down")
  if id=="interrupted" then
    mnp.log("NODE","Stopping!")
    for i=1,config.threads do computer.pushSignal("stop"..i) end
    mnp.closeNode()
    break
  elseif id=="key_down" and port==57 then
    mnp.log("NODE","--General-Info-----------")
    mnp.log("NODE","IP: "..os.getenv("this_ip"))
    local percentage=tonumber((computer.totalMemory()-computer.freeMemory())/computer.totalMemory())*100
    mnp.log("NODE","Memory usage: "..string.format("%.0f%%",percentage))
    mnp.log("NODE","Free memory:"..computer.freeMemory().."/"..computer.totalMemory())
    mnp.log("NODE","Node registered IPs:")
    local nips=ip.getAll()
    for n_ip,_ in pairs(nips) do
      local node_ip,client_ip=ip.getParts(n_ip)
      if client_ip=="0000" then mnp.log("NODE","  Node "..n_ip)
      else mnp.log("NODE","  Client "..n_ip) end
    end
    mnp.log("NODE","--Worker-Threads---------")
    for i=1,config.threads do
      mnp.log("NODE","Worker "..i.." "..Threads[i]:status().." "..ThreadStatus[i])
    end
    mnp.log("NODE","-------------------------")
  elseif id=="modem_message" then
    local found=false
    for i=1,config.threads do
      if ThreadStatus[i]=="idle" and Threads[i]:status()=="running" then
        computer.pushSignal("packet"..i,from,port,mtype,np,data)
        found=true
        break
      end
    end
    if found==false then mnp.log("NODE","All threads are busy!",1) end
  end
end
os.sleep(1) --wait until all threads stop
mnp.log("NODE","Program exited")