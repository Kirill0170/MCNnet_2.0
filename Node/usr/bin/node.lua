--Node (beta)
local node_ver="[beta3 devbuild3]"
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
local passlog=false
local function packetThread(thread_id)
  local run=true
  mnp.log("Worker"..thread_id,"Online")
  local str="/w"..thread_id
  while run do
    local id,from,port,mtype,np,data=event.pullMultiple("packet"..thread_id,"stop"..thread_id)
    if id=="stop"..thread_id then run=false break end
    ThreadStatus[thread_id]="busy"
    if not np then mnp.log("Worker"..thread_id,"No packet info received") return false end
    np=ser.unserialize(np)
    if data then data=ser.unserialize(data) end
    if not netpacket.checkPacket(np) then
      mnp.log("Worker"..thread_id,"Incorrect packet received",1)
      ThreadStatus[thread_id]="idle"
    end
    if not ip.findIP(from) and mtype~="netconnect" and mtype~="netsearch" then
      mnp.log("Worker"..thread_id,"Non-connected client! IP: "..np["route"][0].." mtype: "..mtype,1)
      ThreadStatus[thread_id]="idle"
    elseif mtype=="netconnect" then
      mnp.networkConnect(from,np,data,{config.clientPassword,config.nodePassword})
    elseif mtype=="netdisconnect" then
      mnp.networkDisconnect(from)
    elseif mtype=="netsearch" then
      mnp.networkSearch(from,np,data,config.clientPassword~="")
    elseif mtype=="search" then
      mnp.search(from,np,data)
    elseif mtype=="mncp_ping" then
      mnp.mncp.nodePing(from)
    elseif mtype=="setdomain" then
      mnp.setDomain(np,data)
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
local function checkDeadThreads()
  local c=0
  for _,t in pairs(Threads) do
    if t:status()=="dead" then c=c+1 end
  end
  return c
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
      else
        local domain=""
        if mnp.domains[n_ip] then domain=mnp.domains[n_ip] end
        mnp.log("NODE","  Client "..n_ip.." "..domain)
      end
    end
    mnp.log("NODE","--Worker-Threads---------")
    local deads=checkDeadThreads()
    if deads>0 then
      mnp.log("NODE",deads.." dead threads detected!",2)
    end
    for i=1,config.threads do
      mnp.log("NODE","Worker "..i.." "..Threads[i]:status().." "..ThreadStatus[i])
    end
    mnp.log("NODE","-------------------------")
  elseif id=="key_down" and port==38 then
    if passlog then passlog=false else passlog=true end
    mnp.log("PASS","Logging passing packets set to "..tostring(passlog))
  elseif id=="modem_message" then
    local found=false
    for i=1,config.threads do
      if ThreadStatus[i]=="idle" and Threads[i]:status()=="running" then
        computer.pushSignal("packet"..i,from,port,mtype,np,data)
        found=true
        break
      elseif Threads[i]:status()=="dead" then
        mnp.log("MNP","Restarting thread "..i,1)
        ThreadStatus[i]="idle"
        Threads[i]=thread.create(packetThread,i):detach()
      end
    end
    if found==false then
      mnp.log("NODE","All threads are busy!",1)
      if checkDeadThreads()==config.threads then
        mnp.log("NODE","All workers are dead!",2)
        mnp.log("NODE","Rebooting workers!",2)
        for i=1,config.threads do
          ThreadStatus[i]="idle"
          Threads[i]=thread.create(packetThread,i):detach()
        end
      end
    end
  end
end
os.sleep(0.5) --wait until all threads stop
mnp.log("NODE","Program exited")
--TODO: DEAD THREADS CHECK