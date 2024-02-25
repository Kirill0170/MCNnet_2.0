--Node (beta)
local netname="Internet" --change this: network name
local searchTime=10 --how much of time for connection
local component=require("component")
local computer=require("computer")
local ser=require("serialization")
if not component.isAvailable("modem") then error("You gonna need a modem.") end
local modem=component.modem
local thread=require("thread")
local event=require("event")
local gpu=component.gpu
local mnp=require("mnp")
local session=require("session")
local ip=require("ipv2")
local dns=require("dns")

local function log(text,crit)
  local res="["..computer.uptime().."]"
  if crit==0 or not crit then
    print(res.."[NODE/INFO]"..text)
  elseif crit==1 then
    gpu.setForeground(0xFFFF33)
    print(res.."[NODE/WARN]"..text)
    gpu.setForeground(0xFFFFFF)
  elseif crit==2 then
    gpu.setForeground(0xFF3333)
    print(res.."[NODE/ERROR]"..text)
    gpu.setForeground(0xFFFFFF)
  elseif crit==3 then
    gpu.setForeground(0xFF3333)
    print(res.."[NODE/FATAL]"..text)
    gpu.setForeground(0xFFFFFF)
    local file=io.open("node_err.log","w")
    file:write(res..text)
    file:close()
    error("Fatal error occured in runtime,see log file")
  else end
end

local function connection(from,port,mtype,si,data)
  if not si then return false end
  si=ser.unserialize(si)
  if data then data=ser.unserialize(data) end
  if not session.checkSession(si) then 
    log("Incorrect session field received",1)
    return false 
  end
  if mtype=="netconnect" then
    mnp.networkConnect(from,si,data)
  elseif mtype=="netdisconnect" then
    mnp.networkDisconnect(from)
  elseif mtype=="netsearch" then
    mnp.networkSearch(from,si)
  elseif mtype=="search" then
    mnp.search(from,si)
  elseif mtype=="dns_lookup" then
    mnp.dnsLookup(from,si,data)
  else --data
    mnp.pass(port,mtype,si,data)
  end
end

--setup
os.sleep(0.1)
print("---------------------------")
log("Node(beta) Starting - Hello World!")
log("Checking modem")
if not modem.isWireless() then log("Modem is recommended to be wireless, bro") end
if modem.getStrength()<400 then log("Modem strength is recommended to be default 400",1) end
log("Setting up ipv2...")
if not ip.set(ip.gnip(),true) then log("Could not set node IP",3) end
log("Setting up DNS...")
dns.init()
log("Setting up MNP..")
if not mnp.openPorts() then log("Could not open ports",3) end
mnp.setNetworkName(netname)
log("Connecting to other nodes with "..netname.." name...")
log("Should take "..searchTime.." seconds, as described in node.lua")
if not mnp.nodeConnect(searchTime) then log("Could not set connect to other nodes: check if ip is set?",3) end
log("Starting MNCP")
--thread.create(mnp.mncpService):detach() --uncomment this line when in prod!
--main
log("Node Online!")

while true do
  local id,_,from,port,dist,mtype,si,data=event.pullMultiple("interrupted","modem")
  if id=="interrupted" then
    mnp.closeNode()
    break
  else
    thread.create(connection,from,port,mtype,si,data)
  end
end
log("Program exited")