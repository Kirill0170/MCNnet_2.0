--Node (experimental)
local component=require("component")
local computer=require("computer")
local ser=require("serialization")
if not component.isAvailable("modem") then error("You gonna need a modem.") end
local modem=component.modem
local thread=require("thread")
local event=require("event")
local gpu=component.gpu
local mnp=require("mnp")
local ip=require("ipv2")
local dns=require("dns")
local err = false
busy={} --list of busy uuids
--functions
function isBusy(g_uuid)
  for _, value in pairs(busy) do
    if value == g_uuid then return true end
  end
  return false
end
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
    local si=ser.unserialize(si)
    --if not isBusy(si["uuid"]) then
      thread.create(session,from,port,mtype,si,data):detach()
      --table.insert(busy, si["uuid"])
    --end
  end
end
function session(from,port,mtype,sessionInfo,data)
  if not sessionInfo then return false end
  si=ser.unserialize(sessionInfo)
  if not mnp.checkSession(si) then log("Unvalid SessionInfo received",1) return false end
  if port==1000 and mtype=="register" then
    mnp.register(from,si)
  elseif port==1001 and mtype=="search" then
    mnp.search(from,si)
  elseif port==1002 and mtype=="data" then
    mnp.data(from,si,data)
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
log("Starting MNCP")
mnp.mncpService()
--main
log("Node Online!")

while true do
  local _,_,from,port,_,mtype,si,data=event.pull("modem")
  thread.create(main,from,port,mtype,si,data)
end
