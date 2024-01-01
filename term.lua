local version="1.0 indev"
local dolog=true
local component=require("component")
local computer=require("computer")
local ser=require("serialization")
local thread=require("thread")
local event=require("event")
local ip=require("ipv2")
local gpu=component.gpu
local mnp=require("mnp")
local ports={}
ports["term_conn"]=2000
ports["term_data"]=2001
local term={}
--Util-
function log(text,crit)
  local res="["..computer.uptime().."]"
  if dolog and crit==0 or not crit then
    print(res.."[TERM/INFO]"..text)
  elseif dolog and crit==1 then
    gpu.setForeground(0xFFFF33)
    print(res.."[TERM/WARN]"..text)
    gpu.setForeground(0xFFFFFF)
  elseif crit==2 then
    gpu.setForeground(0xFF3333)
    print(res.."[TERM/ERROR]"..text)
    gpu.setForeground(0xFFFFFF)
  elseif crit==3 then
    gpu.setForeground(0xFF3333)
    print(res.."[TERM/FATAL]"..text)
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
function term.getVersion() return version end
--Main--
function term.clientConnect(to_ip,timeoutTime)
  if not to_ip or not ip.isIPv2(to_ip) then return false end
  if not timeoutTime then timeoutTime=10 end --term connection should be fast
  local data={}
  data[1]="init"
  data[2]={version}
  data[3]={}
  mnp.send(to_ip,"term",data)
  local rdata=mnp.receive(to_ip,"term",timeoutTime)
  if not rdata then
    log("Could not connect to server",1)
    return false
  end
  if rdata[1]=="init" then
    if rdata[3]=="OK" then
      if rdata[2]["uap"]==true then
        --uap here
      end
      return true
    elseif rdata[3]=="CR" then
      log("Connection refused",1)
      return false
    end
  end
  log("Could not connect to server",1)
end
return term
--[[ TERM PROTOCOL (refer to .term_protocol)
"term"
session: [f]:true (need to find first)
data:
[[
"<mtype>",{<options>},{<data>}
m-types:
(s<-c)"init",{"version"="<TERM version>"},{}
(s->c)"init",{"uap"=true/false},{"OK/CR"}
(s->c)"text",{x:0,y:0,fgcol:0xFFFFFF,bgcol:"default"},{"<sample text>"}
(s->c)"input_request",{},{}
(s<-c)"input_response",{},{"<input>"}
]]