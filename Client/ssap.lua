local version="1.1 indev"
local dolog=true
local component=require("component")
local computer=require("computer")
local ser=require("serialization")
local thread=require("thread")
local event=require("event")
local ip=require("ipv2")
local gpu=component.gpu
local mnp=require("mnp")
local cmnp=require("cmnp")
local ports={}
ports["ssap_conn"]=2000
ports["ssap_data"]=2001
local ssap={}
--Util-
function log(text,crit)
  local res="["..computer.uptime().."]"
  if dolog and crit==0 or not crit then
    print(res.."[SSAP/INFO]"..text)
  elseif dolog and crit==1 then
    gpu.setForeground(0xFFFF33)
    print(res.."[SSAP/WARN]"..text)
    gpu.setForeground(0xFFFFFF)
  elseif crit==2 then
    gpu.setForeground(0xFF3333)
    print(res.."[SSAP/ERROR]"..text)
    gpu.setForeground(0xFFFFFF)
  elseif crit==3 then
    gpu.setForeground(0xFF3333)
    print(res.."[SSAP/FATAL]"..text)
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
function ssap.getVersion() return version end
--Main--
function ssap.clientConnect(to_ip,timeoutTime)
  if not to_ip or not ip.isIPv2(to_ip) or not cmnp.getPattern(to_ip) then return false end
  if not timeoutTime then timeoutTime=10 end --ssap connection should be fast
  local data={}
  data[1]="init"
  data[2]={}
  data[3]={}
  data[2]["version"]=version
  cmnp.send(to_ip,"ssap",data)
  local rdata=cmnp.receive(to_ip,"ssap",timeoutTime)
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
function ssap.serverConnectionManager() --no UAP support
  log("Started SSAP Connection Manager")
  while true do
    local id,_,from,port,_,mtype,si,data=event.pullMultiple("modem","interrupted","ssap_stopCM")
    if id=="interrupted" then
      log("CM interrupted",2)
      break 
    elseif id=="ssap_stopCM" then
      log("Stopping Connection Manager")
      break
    else
      if mtype=="ssap" then
        data=ser.unserialze(data)
        if data[1]=="init" then
          rdata={}
          rdata[1]="init"
          rdata[2]={}
          rdata[2]["uap"]=false --UAP
          local to_ip=ser.unserialize(si)["route"][0]
          if data[2]["version"]==version and then
            rdata[3]={"OK"}
            cmnp.sendBack("ssap",ser.unserialize(si),ser.serialize(data))
          else
            rdata[3]={"CR"}
            cmnp.sendBack("ssap",ser.unserialize(si),ser.serialize(data))
          end
        end
      end
    end
  end
end
return ssap
--[[ ssap PROTOCOL (refer to .ssap_protocol)
"ssap"
session: [f]:true (need to find first)
data:
[[
"<mtype>",{<options>},{<data>}
m-types:
(s<-c)"init",{"version"="<ssap version>"},{}
(s->c)"init",{"uap"=true/false},{"OK/CR"}
(s->c)"text",{x:0,y:0,fgcol:0xFFFFFF,bgcol:"default"},{"<sample text>"}
(s->c)"input_request",{},{}
(s<-c)"input_response",{},{"<input>"}
]]