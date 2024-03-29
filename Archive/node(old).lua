--Node (experimental)
local netname="Internet" --change this: network name
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
local err = false
--functions
function log(text,crit)
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

function main(from,port,mtype,si,data) --main listener
  if not si then
    log("Unvalid packet: no sessionInfo!",2)
  else
    thread.create(sessionThread,from,port,mtype,si,data):detach()
  end
end
function sessionThread(from,port,mtype,sessionInfo,data)
  if not sessionInfo then return false end
  si=ser.unserialize(sessionInfo)
  if not session.checkSession(si) then log("Unvalid SessionInfo received",1) return false end
  if port==1003 then return false end
  if mtype=="register" then
    mnp.register(from,si,data)
  elseif mtype=="search" then
    mnp.search(from,si)
  elseif mtype=="dnslookup" then
    mnp.dnsLookup(from,si,data)
  else --pass
    log("Passing packet")
    mnp.pass(port,mtype,si,data)
  end
end
--setup
os.sleep(0.1)
print("---------------------------")
log("Node Starting - Hello World!")
log("Checking modem")
if not modem.isWireless() then log("Modem is recommended to be wireless, bro") end
if modem.getStrength()<400 then log("Modem strength is recommended to be default 400",1) end
log("Setup ipv2...")
ip.setMode("NODE")
local this_ip=ip.gnip()
if not ip.set(this_ip) then log("Could not set node IP",3) end
log("Setup DNS...")
dns.init()
log("Registering!")
local timeout=2
local attempts=5
log("Searching for nodes... Should take "..timeout*attempts.." seconds")
if not mnp.node_register(attempts,timeout) then log("Could not set register: check if ip is set?",3) end
log("Setup MNP")
if not mnp.openPorts() then log("Could not open ports",3) end
mnp.setNetworkName(netname)
log("Starting MNCP")
thread.create(mnp.mncpService):detach()
--main
log("Node Online!")

while true do
  local _,_,from,port,_,mtype,si,data=event.pull("modem")
  thread.create(main,from,port,mtype,si,data)
end
