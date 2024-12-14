local version="1.7"
local component=require("component")
local computer=require("computer")
local ser=require("serialization")
local thread=require("thread")
local event=require("event")
local ip=require("ipv2")
local gpu=component.gpu
local cmnp=require("cmnp")
local term=require("term")
local ssap={}
ssap.client={}
ssap.server={}
--Util-----------------------
function ssap.log(text,crit)
  cmnp.log("SSAP",text,crit)
end
function ssap.safeRequire(modname)
  if not modname then return nil end
  local success,module=pcall(function ()
    return require(modname)
  end)
  if success then return module
  else ssap.log("Couldn't require "..modname..": "..module,2) return nil end
end
function ssap.checkData(data) --{"packet_type",{options},{data}}
  if type(data)~="table" then return false end
  if type(data[1])~="string" then return false end
  if type(data[2])~="table" or type(data[3])~="table" then return false end
  return true
end
function ssap.ver() return version end
--Main------------------------
function ssap.server.connectionManager(filename) --no UAP support
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
  ssap.log("Press space to check status")
  local sessions={}
  require(filename).setup()
  while true do
    local id,data,from_ip,key=event.pullMultiple(dataEvent,"interrupted","ssap_stopCM","key_down")
    if id=="interrupted" then
      ssap.log("CM stopped",2)
      require(filename).shutdown()
      computer.pushSignal(stopEvent)
      break 
    elseif id=="ssap_stopCM" then
      ssap.log("Stopping Connection Manager")
      computer.pushSignal(stopEvent)
      break
    elseif id=="key_down" then
      if key==57 then
        ssap.log("IP: "..os.getenv("this_ip"))
        local percentage=tonumber((computer.totalMemory()-computer.freeMemory())/computer.totalMemory())*100
        ssap.log("Memory usage: "..string.format("%.0f%%",percentage))
        ssap.log("Free memory:"..computer.freeMemory().."/"..computer.totalMemory())
        ssap.log("Current sessions:")
        for s_ip,t in pairs(sessions) do
          ssap.log(s_ip.." "..t:status())
        end
      end
    else
      data=ser.unserialize(data)
      if data[1]=="init" then
        local rdata={}
        rdata[1]="init"
        rdata[2]={}
        rdata[2]["uap"]=false --UAP
        local to_ip=from_ip
        if data[2]["version"]==version then
          rdata[3]={"OK",""}
          cmnp.send(to_ip,"ssap",rdata)
          --wait for client start
          local check_data=cmnp.receive(to_ip,"ssap",10)
          if not check_data or check_data[1]~="start" then ssap.log("Client didn't start app",1)
          else
            --check if already started thread
            if sessions[to_ip] then sessions[to_ip]:kill() end
            local t=thread.create(ssap.server.application,filename,to_ip):detach()
            sessions[to_ip]=t
          end
        else
          rdata[3]={"CR","Different SSAP version! Expected: <"..version.."> Got: <"..tostring(rdata[2]["version"]..">")}
          cmnp.send(to_ip,"ssap",rdata)
        end
      end
    end
  end
end
function ssap.server.application(filepath,to_ip)
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
function ssap.server.getInput(from_ip,timeoutTime,label)--REDO THIS USING DEDICATED INPUT
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
function ssap.server.getKeyPress(from_ip,timeoutTime,only)
  if not ip.isIPv2(from_ip) then return nil end
  if not tonumber(timeoutTime) then timeoutTime=120 end
  local sdata={"keypress_request",{},{}}
  sdata[2]["timeout"]=timeoutTime
  if type(only)=="table" then
    sdata[2]["only"]=only
  end
  cmnp.send(from_ip,"ssap",sdata)
  --no local
  local rdata=cmnp.receive(from_ip,"ssap",timeoutTime)
  if rdata[1]=="keypress_response" and type(rdata[3])=="table" then
    return rdata[3]
  end
  return nil
end
function ssap.disconnect(to_ip)
  cmnp.send(to_ip,"ssap",{"exit",{},{}})
end
function ssap.client.connect(to_ip,timeoutTime)
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
      ssap.log("Connection refused: "..tostring(rdata[3][2]),1)
      return false
    end
  end
  ssap.log("Could not connect to server: wrong packet!",1)
  return false
end
function ssap.client.text(options,text)
  local prev_bg_color=gpu.getBackground()
  local prev_fg_color=gpu.getForeground()
  local bg_color=tonumber(options["bg_color"])
  local fg_color=tonumber(options["fg_color"])
  local x=tonumber(options["x"])
  local y=tonumber(options["y"])
  if bg_color then gpu.setBackground(bg_color) end
  if fg_color then gpu.setForeground(fg_color) end
  if x and y then
    term.setCursor(x,y)
    term.write(text[1])
    term.setCursor(1,y+1)
  else
    for _,line in pairs(text) do print(line) end
  end
  if not options["keep_color"] then
    gpu.setBackground(prev_bg_color)
    gpu.setForeground(prev_fg_color)
  end
end
function ssap.client.input(server_ip,options)
  if not server_ip then return false end
  if not options then
    options={}
    options["timeout"]=60
  end
  if options["label"] then term.write(options["label"]) end
  local time=computer.uptime()
  local input=io.read()
  if computer.uptime()-time>tonumber(options["timeout"]) then --check if timeouted
    ssap.log("Disconnected: Client timeout",1)
    return false end --return to end XD
  local sdata={"input_response",{},{input}}
  cmnp.send(server_ip,"ssap",sdata)
  return true
end
function ssap.client.keyPress(server_ip,options) --options["only"]={57,...}
  if not server_ip then return false end
  if not options then
    options={}
    options["timeout"]=60
  end
  local time=computer.uptime()
  local a,b="",""
  if type(options["only"])=="table" then
    local checking=true
    while checking do
      local _,_,aa,bb=event.pull("key_down")
      for _,pair in pairs(options["only"]) do
        if (pair[1]==-1 or aa==pair[1]) and bb==pair[2] then
          checking=false
          a=aa; b=bb
        end
      end
    end
  else
    _,_,a,b=event.pull("key_down")
  end
  if computer.uptime()-time>tonumber(options["timeout"]) then --check if timeouted
    ssap.log("Disconnected: Client timeout",1)
    return false end --client-sided timeout
  local sdata={"keypress_response",{},{a,b}}
  cmnp.send(server_ip,"ssap",sdata)
  return true
end
function ssap.client.connection(server_ip,timeoutTime)--REDO THIS USING DEDICATED INPUT
  --0: disconnected 1: server timeout 2: client timeout
  if not tonumber(timeoutTime) then timeoutTime=30 end
  while true do
    local rdata=cmnp.receive(server_ip,"ssap",timeoutTime)
    if not rdata then--disconnect
      ssap.log("Disconnected: Server timeouted",1)
      return 1
    end
    if rdata[1]=="exit" then
      ssap.log("Disconnected: exit")
      computer.pushSignal("ssaplistenstop")
      return 0
    elseif rdata[1]=="text" then ssap.client.text(rdata[2],rdata[3])
    elseif rdata[1]=="input_request" then
      if not ssap.client.input(server_ip,rdata[2]) then computer.pushSignal("ssaplistenstop") return 2 end
    elseif rdata[1]=="keypress_request" then
      if not ssap.client.keyPress(server_ip,rdata[2]) then computer.pushSignal("ssaplistenstop") return 2 end
    elseif rdata[1]=="ftp_file_get" then
      if not ssap.client.GetFile(server_ip,rdata[3][1],rdata[3][1],rdata[3][2]) then computer.pushSignal("ssaplistenstop") return 3 end
    elseif rdata[1]=="ftp_file_put" then
      if not ssap.client.SendFile(server_ip,rdata[3][1]) then computer.pushSignal("ssaplistenstop") return 3 end
    elseif rdata[1]=="text_listen" then
      thread.create(ssap.client.textlistener,server_ip):detach()
    elseif rdata[1]=="text_stop" then
      computer.pushSignal("ssaplistenstop")
    elseif rdata[1]=="clear" then
      term.clear()
    else
      ssap.log("Unknown ssap header: "..tostring(rdata[1]),1)
    end
  end
end
--FTP------------------------------------------
function ssap.server.sendFile(to_ip,filename,clientPretty)
  if not ip.isIPv2(to_ip) then return false end
  if not filename then return false end
  if not clientPretty then clientPretty=false end
  local ftp=ssap.safeRequire("ftp")
  if not ftp then return false
  else
    ssap.send(to_ip,{"ftp_file_get",{},{filename,clientPretty}})
    if not ftp.serverConnectionAwait(to_ip,30) then
    else
      ftp.serverConnection(to_ip,filename)
    end
  end
end
function ssap.server.requestFile(to_ip,filename)
  if not ip.isIPv2(to_ip) then return false end
  if not filename then return false end
  local ftp=ssap.safeRequire("ftp")
  if not ftp then return false
  else
    ssap.send(to_ip,{"ftp_file_put",{},{filename}})
    if not ftp.serverConnectionAwait(to_ip,30) then
    else
      ftp.serverConnection(to_ip,filename)
    end
  end
end
function ssap.client.GetFile(server_ip,getfilename,writefilename,pretty)
  if not ip.isIPv2(server_ip) then return false end
  if not getfilename then return false end
  if not writefilename then writefilename=getfilename end
  local ftp=ssap.safeRequire("ftp")
  if not ftp then return false end
  if ftp.connection(server_ip) then
    local success,code=ftp.request(server_ip,getfilename,writefilename,true,pretty)
    if success then return true
    else
      ssap.log("Require fail: "..tostring(code),1)
      return false
    end
  else
    ssap.log("Couldn't establish connection!")
  end
end
function ssap.client.SendFile(server_ip,filename)
  if not ip.isIPv2(server_ip) then return false end
  if not filename then return false end
  local ftp=ssap.safeRequire("ftp")
  if not ftp then return false end
  if ftp.connection(server_ip) then
    local success,code=ftp.upload(server_ip,filename,true)
    if success then return true
    else
      ssap.log("Require fail: "..tostring(code),1)
      return false
    end
  else
    ssap.log("Couldn't establish connection!")
  end
end
function ssap.client.textlistener(server_ip,stopEvent)
  if not ip.isIPv2(server_ip) then return false end
  if not stopEvent then stopEvent="ssaplistenstop" end
  require("thread").create(cmnp.listen,server_ip,"ssap",stopEvent,"ssaplistendata"):detach()
  while true do
    local id,data,from_ip=event.pullMultiple("ssaplistendata","interrupted",stopEvent)
    if id=="interrupted" then
      computer.pushSignal(stopEvent)
      break
    elseif id==stopEvent then break
    else
      if from_ip~=server_ip then ssap.log("Wrong ip: "..from_ip,2) end
      data=ser.unserialize(data)
      if ssap.checkData(data) then
        if data[1]=="text" then
          if data[2]["listener"]==true then
            ssap.client.text(data[2],data[3])
          end
        end
      end
    end
  end
end
function ssap.server.textlisten(client_ip)
  ssap.send(client_ip,{"text_listen",{},{}})
end
function ssap.server.textstop(client_ip)
  ssap.send(client_ip,{"text_stop",{},{}})
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
(s->c)"text",{x:0,y:0,fgcol:0xFFFFFF,bgcol:"default"},{"<sample text>","<sample text line 2>"}
(s->c)"input_request",{"label"="<nil/string>","timeout"=<int>},{}
(s<-c)"input_response",{},{"<input>"}
(s->c)"keypress_request",{"timeout"=<int>,"only"={{-1,57},{32,57}}},{}
(c<-s)"keypress_response",{},{<int>,<int>}
(c<-s)"ftp_file_get",{},{<filename>}
(c<-s)"ftp_file_put",{},{<filename>}
(s->c)"exit",{},{}
(s->c)"clear",{bg_color:0x000000},{}
]]