local version="1.3.4 alpha"
local dolog=true
local component=require("component")
local computer=require("computer")
local ser=require("serialization")
local thread=require("thread")
local event=require("event")
local ip=require("ipv2")
local gpu=component.gpu
local cmnp=require("cmnp")
local ports={}
ports["ssap_conn"]=2000
ports["ssap_data"]=2001
local ssap={}
--Util-
function ssap.log(text,crit)
  cmnp.log("SSAP",text,crit)
end
function ssap.getVersion() return version end
--Main--
function ssap.checkData(data) --{"packet_type",{options},{data}}
  if type(data)~="table" then return false end
  if type(data[1])~="string" then return false end
  if type(data[2])~="table" or type(data[3])~="table" then return false end
  return true
end
function ssap.clientConnect(to_ip,timeoutTime)--REDO AND FIX ISSUES
  if not ip.isIPv2(to_ip) then return false end
  if not cmnp.isConnected() then return false end
  if not timeoutTime then timeoutTime=10 end --ssap connection should be fast
  local data={"init",{},{}}
  data[2]["version"]=version
  local success=cmnp.send(to_ip,"ssap",data)
  if success~=0 then
    if success==1 then
      ssap.log("Not connected",1)
    elseif success==3 then
      ssap.log("Couldn't find host",1)
    end
    return false
  end
  local rdata=cmnp.receive(to_ip,"ssap",timeoutTime)
  if not rdata then
    ssap.log("Could not connect to server: timeout",1)
    return false
  elseif not ssap.checkData(rdata) then
    ssap.log("Invalid packet received!",1)
    ssap.log("debug: "..ser.serialize(rdata),1)
    return false
  end
  if rdata[1]=="init" then
    if rdata[3][1]=="OK" then
      if rdata[2]["uap"]==true then
        --uap here
      end
      cmnp.send(to_ip,"ssap",{"start"})--start
      return true
    elseif rdata[3][1]=="CR" then
      ssap.log("Connection refused",1)
      return false
    end
  end
  ssap.log("Could not connect to server: wrong packet!",1)
  return false
end
function ssap.serverConnectionManager(filename) --no UAP support
  local fs=require("filesystem")
  if not fs.exists("/lib/"..filename..".lua") then
    ssap.log("Couldn't start SSAP CM: no such file: "..filename,2)
    return false
  end
  if not cmnp.isConnected() then ssap.log("Couldn't start SSAP CM: not connected",2) return false end
  --DEBUG
  cmnp.toggleLog(true)
  --listener
  local stopEvent="ssapListenerStop"
  local dataEvent="ssapListenerData"
  thread.create(cmnp.listen,"broadcast","ssap",stopEvent,dataEvent):detach()
  ssap.log("Started SSAP Connection Manager")
  ssap.log("Press space to check current client sessions")
  local sessions={}
  require(filename).setup()
  while true do
    local id,data,np,key=event.pullMultiple(dataEvent,"interrupted","ssap_stopCM","key_down")
    if id=="interrupted" then
      ssap.log("CM interrupted",2)
      computer.pushSignal(stopEvent)
      break 
    elseif id=="ssap_stopCM" then
      ssap.log("Stopping Connection Manager")
      computer.pushSignal(stopEvent)
      break
    elseif id=="key_down" then
      if key==57 then
        ssap.log("Current sessions:")
        for to_ip,t in pairs(sessions) do
          ssap.log(to_ip.." "..t:status())
        end
      end
    else
      data=ser.unserialize(data)
      np=ser.unserialize(np)
      if data[1]=="init" then
        local rdata={}
        rdata[1]="init"
        rdata[2]={}
        rdata[2]["uap"]=false --UAP
        local to_ip=np["route"][0]
        if data[2]["version"]==version then
          rdata[3]={"OK",""}
          cmnp.sendBack("ssap",np,rdata)
          --wait for client start
          local check_data=cmnp.receive(to_ip,"ssap",10)
          if not check_data or check_data[1]~="start" then ssap.log("Client didn't start app",1)
          else
            --check if already started thread
            if sessions[to_ip] then sessions[to_ip]:kill() end
            local t=thread.create(ssap.application,filename,to_ip):detach()
            sessions[to_ip]=t
          end
        else
          rdata[3]={"CR","Different SSAP version!"}
          cmnp.sendBack("ssap",np,rdata)
        end
      end
    end
  end
end
function ssap.application(filepath,to_ip)
  if not require("filesystem").exists("/lib/"..filepath..".lua") then
    ssap.log("Could not open application file",3)
  end
  local app=require(filepath)
  ssap.log("Starting SSAP application...")
  app.main(to_ip)
end
function ssap.send(to_ip,data)
  cmnp.send(to_ip,"ssap",data)
end
function ssap.getInput(from_ip,timeoutTime,label)--REDO THIS USING DEDICATED INPUT
  if not ip.isIPv2(from_ip) then return nil end
  if not tonumber(timeoutTime) then timeoutTime=120 end
  local sdata={"input_request",{},{}}
  if label then sdata[2]["label"]=label end
  sdata[2]["timeout"]=timeoutTime
  cmnp.send(from_ip,"ssap",sdata)
  --no local
  local rdata=cmnp.receive(from_ip,"ssap",timeoutTime)
  if rdata[1]=="input_response" and rdata[3][1]~=nil then
    return rdata[3][1]
  end
  return nil
end
function ssap.disconnect(to_ip)
  cmnp.send(to_ip,"ssap",{"exit",{},{}})
end
function ssap.clientConnection(server_ip,timeoutTime)--REDO THIS USING DEDICATED INPUT
  --0: disconnected 1: server timeout 2: client timeout
  local gpu=require("component").gpu
  local term=require("term")
  if not tonumber(timeoutTime) then timeoutTime=30 end
  while true do
    local rdata=cmnp.receive(server_ip,"ssap",timeoutTime)
    if not rdata then--disconnect
      ssap.log("Disconnected: Server timeouted",1)
      return 1
    end
    if rdata[1]=="exit" then
      ssap.log("Disconnected: exit")
      return 0
    elseif rdata[1]=="text" then
      if rdata[2]["bg_color"] then gpu.setBackground(tonumber(rdata[2]["bg_color"])) end
      if rdata[2]["fg_color"] then gpu.setForeground(tonumber(rdata[2]["fg_color"])) end
      if rdata[2]["x"] and rdata[2]["y"] then
        term.setCursor(tonumber(rdata[2]["x"]),tonumber(rdata[2]["y"]))
        term.write(rdata[3][1])
        term.setCursor(1,tonumber(rdata[2]["y"])+1)--next line(needed??)
      else
        print(rdata[3][1])
      end
    elseif rdata[1]=="input_request" then
      if rdata[2]["label"] then term.write(rdata[2]["label"]) end
      local time=computer.uptime()
      local input=io.read()
      if computer.uptime()-time>tonumber(rdata[2]["timeout"]) then --check if timeouted
        ssap.log("Disconnected: Client timeout",1)
        return 2 end --return to end XD
      local sdata={"input_response",{},{input}}
      cmnp.send(server_ip,"ssap",sdata)
    elseif rdata[1]=="clear" then
      term.clear()
    else
      ssap.log("Unknown ssap header: "..tostring(rdata[1]),1)
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
(s->c)"input_request",{"label"="<nil/string>","timeout"=<int>},{}
(s<-c)"input_response",{},{"<input>"}
(s->c)"exit",{},{}
(s->c)"clear",{bg_color:0x000000},{}
]]

--SSAP.CLIENT.TEXT  SSAP.SERVER.TEXT!!!