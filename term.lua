local version="1.0 indev"
local dolog=true
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
function term.clientConnect(sessionTemplate,)
    local data={}
    data[1]="init"
    data[2]={version}
    data[3]={}
    modem.send(os.getenv("node_uuid"),ports["term_conn"],"term",sessionTemplate,data)
    
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