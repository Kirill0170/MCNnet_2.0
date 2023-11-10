--Mcn-net Networking Protocol for Client v2.1 EXPERIMENTAL
--With Session Protocol v1.211 EXPERIMENTAL
--Modem is required.
local dolog=true --log 
local component=require("component")
local computer=require("computer")
local ser=require("serialization")
local modem=component.modem
local event=require("event")
local ip=require("ipv2")
local gpu=component.gpu
local mnp_ver="2.1 EXPERIMENTAL"
local ses_ver="1.211 EXPERIMENTAL"
local mncp_ver="2.0 EXPERIMENTAL"
local sp={} --stores patterns of sessions to some IP| "IP"=session
local forbidden_vers={}
local ports={}
ports["mnp_reg"]=1000
ports["mnp_srch"]=1001
ports["mnp_data"]=1002
ports["mncp_srvc"]=1003
ports["mncp_err"]=1004
ports["mncp_ping"]=1005
ports["mftp_conn"]=1006
ports["mftp_data"]=1007
ports["mftp_srvc"]=1008
ports["dns_lookup"]=1009
local mnp={}
--init-----------------------------------
print("[MNP INIT]: Starting...")
print("[MNP INIT]: MNP version "..mnp_ver)
print("[MNP INIT]: MNCP version "..mncp_ver)
print("[MNP INIT]: SP version "..ses_ver)
print("[MNP INIT]: IP version "..ip.ver())
print("[MNP INIT]: Done")
--Session--------------------------------
function mnp.checkSession(sessionInfo)
  if not sessionInfo then return false end
  if not ip.isUUID(sessionInfo["uuid"]) then return false end
  if not ip.isIPv2(sessionInfo[0]) then return false end
  if not tonumber(sessionInfo["ttl"]) then return false end
  if not tonumber(sessionInfo["c"]) then return false end
  if not ip.isIPv2(sessionInfo["t"]) and sessionInfo["t"]~="broadcast" then return false end
  return true
end
function mnp.newSession(from_ip,to_ip,ttl)
  if not ip.isIPv2(from_ip) then return nil end
  if not ip.isIPv2(to_ip) or not to_ip then to_ip="broadcast" end
  if not tonumber(ttl) then ttl=16 end
  local newSession={}
  newSession["uuid"]=require("uuid").next()
  newSession["c"]=1
  newSession["t"]=os.getenv("this_ip")
  newSession[0]=from_ip
  newSession["ttl"]=tonumber(ttl)
  return newSession
end
function mnp.addIpToSession(sessionInfo,ip_a)
  if not mnp.checkSession(sessionInfo) then error("[MNP SESSION ADD]: Invalid Session") end
  if not ip.isIPv2(ip_a) then error("[MNP SESSION ADD]: Not an IP") end
  sessionInfo[sessionInfo["c"]]=ip_a
  sessionInfo["c"]=sessionInfo["c"]+1
  return sessionInfo
end

--MNCP-----------------------------------
function mnp.mncpCliService()
  if not modem.isOpen(ports["mncp_srvc"]) then modem.open(ports["mncp_srvc"]) end
  log("Started MNCP service")
  while true do
    local _,_,from,port,_,mtype,si=event.pull("modem")
    if port==ports["mncp_srvc"] and mtype=="mncp_check" then
      local to_ip=ser.unserialize(si)[0]
      modem.send(from,ports["mncp_srvc"],"mncp_check",ser.serialize(mnp.newSession(to_ip,2)))
    end
  end
end
--DNS------------------------------------
function mnp.dnsService() --SERVER USAGE ONLY
  if dnsName then
    local err=false
    repeat
      local _,_,from,_,_
    until err
  else return false end
end
--MNP------------------------------------
--Util-
function log(text,crit)
  local res="["..computer.uptime().."]"
  if dolog and crit==0 or not crit then
    print(res.."[MNP/INFO]"..text)
  elseif dolog and crit==1 then
    gpu.setForeground(0xFFFF33)
    print(res.."[MNP/WARN]"..text)
    gpu.setForeground(0xFFFFFF)
  elseif crit==2 then
    gpu.setForeground(0xFF3333)
    print(res.."[MNP/ERROR]"..text)
    gpu.setForeground(0xFFFFFF)
  elseif crit==3 then
    gpu.setForeground(0xFF3333)
    print(res.."[MNP/FATAL]"..text)
    gpu.setForeground(0xFFFFFF)
    local file=io.open("mnp_err.log","w")
    file:write(res..text)
    file:close()
    error("Fatal error occured in runtime,see log file")
  else end
end
function mnp.crash(reason)
  modem.open(ports["mncp_err"])
  modem.broadcast(ports["mncp_err"],"crash","client",reason)
end
function mnp.openPorts(plog)
  for name,port in pairs(ports) do
    if plog then log("Opening "..name) end
    if not modem.open(port) and not modem.isOpen(port) then return false end
  end
  return true
end
--Main-
function mnp.register(a,t)
  if not a then a=-1 end
  if not t then t=2 end
  local ca=0 --current attempt
  local ct=false --close port?
  local connect=false
  log("Activating registration")
  modem.setStrength(400)
  os.setenv("this_ip","0000:0000")
  local rsi=ser.serialize(mnp.newSession())
  if not modem.isOpen(ports["mnp_reg"]) then ct=true modem.open(ports["mnp_reg"]) end
  while not connect do
    if a>0 then ca=ca+1 end
    if ca>a and a>0 then break end
    modem.broadcast(ports["mnp_reg"],"register",rsi)
    local _,_,from,port,dist,mtype,si=event.pull(t,"modem")
    si=ser.unserialize(si)
    if from and port==ports["mnp_reg"] and mtype=="register" and mnp.checkSession(si) then
      log("Connected to "..si[0])
      connect=true
      ip.set(string.sub(si[0],1,4))
      modem.setStrength(dist+10)
      os.setenv("n_uuid",from)--save
    end
  end
  if ct then modem.close(ports["mnp_reg"]) end
  if not connect then return false end
  return true
end
function mnp.search(to_ip)
  local si=ser.serialize(mnp.newSession(to_ip))
  modem.send(os.getenv("n_uuid"),ports["mnp_srch"],"search",si)
  log("Stated search...")
  local start_time=computer.uptime()
  while true do
    local id,_,from,port,_,mtype,rsi=event.pullMultiple(1,"modem","interrupted")
    if id=="interrupted" then
      break
    else
      if port==ports["mnp_srch"] and from==os.getenv("n_uuid") and mtype=="search" then
        rsi=ser.unserialize(rsi)
        if not rsi["f"] then
          log("Search received SessionInfo with f=false/nil - Resuming search",1)
        else
          --save session
          sp[rsi["t"]]=rsi
        end
      end
    end
  end
end
function mnp.connect(name)
  if ip.isIPv2(name) then

  else --probably DN
    
  end
end
